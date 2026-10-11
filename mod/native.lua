if not rawget(_G,'ZMLMoreTeams') then
    local U,IO=CS.UnityEngine,CS.System.IO
    local W={controllers=setmetatable({},{__mode='k'}),instances=setmetatable({},{__mode='k'}),disabled={}}
    local function api()return assert(loadstring(LuaManagerInst:LoadLua('ZML/Api'),'@ZML/Api'))()end
    local function report(event,e)
        pcall(function()api().report('more-teams',event)end)
        if e then pcall(function()logger.error('ZML MoreTeams: '..event..': '..tostring(e):sub(1,300))end)end
    end
    local function toast(s) Notify(MessageConst.SHOW_TOAST,s) end
    local function hex(s)return(s:gsub('.',function(c)return string.format('%02x',c:byte())end))end
    local statePath=__ZML_STATE_DIRECTORY__
    local function path(account)return IO.Path.Combine(statePath,'teams-'..hex(account)..'.txt')end
    local P={time=function()return U.Time.unscaledTime end,error=toast}
    function P.read(account)
        local ok,text=pcall(function()
            local file=path(account);if not IO.File.Exists(file)then return nil end
            assert(IO.FileInfo(file).Length<=32768,'size')
            return IO.File.ReadAllText(file,CS.System.Text.Encoding.UTF8)
        end)
        if not ok then return nil,'无法读取本地编队' end
        return text
    end
    function P.write(account,text)
        local file=path(account);local temp=file..'.tmp.'..CS.System.Guid.NewGuid():ToString('N')
        local ok=pcall(function()
            IO.Directory.CreateDirectory(statePath)
            IO.File.WriteAllText(temp,text,CS.System.Text.UTF8Encoding(false))
            if IO.File.Exists(file)then IO.File.Replace(temp,file,file..'.bak')else IO.File.Move(temp,file)end
        end)
        if IO.File.Exists(temp)then pcall(IO.File.Delete,temp)end
        return ok,not ok and '无法保存本地编队' or nil
    end
    local function bag()return GameInstance.player.charBag end
    local function decimal(value)
        local s=tostring(value):gsub('ULL$',''):gsub('LL$','')
        assert(s:match('^[1-9]%d*$'),'Character id unavailable');return s
    end
    function P.serverRoster(i)
        local t=bag():GetCurrentMainTeamByIndex(i-1);local slots={}
        if t then for j=0,t.memberList.Count-1 do
            local n=t.memberList[j]
            if n>0 then
                local ch=assert(CharInfoUtils.getPlayerCharInfoByInstId(n),'Character missing')
                slots[#slots+1]={id=decimal(n),skill=ch.normalSkillId or ''}
            end
        end end
        return slots
    end
    function P.serverActive()return LuaIndex(bag().curTeamIndex)end
    function P.validate(slots)
        if #slots==0 then return false,Language.LUA_CAN_NOT_SET_CUR_SQUAD_NO_CHAR end
        if #slots>bag().maxCharTeamMemberCount then return false,'编队成员超过当前上限' end
        local first
        for _,v in ipairs(slots)do
            local n=CS.System.UInt64.Parse(v.id)
            local ch=CharInfoUtils.getPlayerCharInfoByInstId(n)
            if not ch then return false,'编队包含不可用干员，请重新编辑' end
            if not CharInfoUtils.isCharDead(n)and not first then first=n end
        end
        if not first then return false,Language.LUA_CAN_NOT_SET_SQUAD_ALL_DEAD end
        if Utils.isForbidden(ForbidType.ForbidSetSquad) then return false,'当前无法切换编队' end
        return true,first
    end
    function P.members(i,slots)
        assert(i==5,'Illegal mapped slot')
        local ids,skills={},{}
        for _,v in ipairs(slots)do ids[#ids+1]=CS.System.UInt64.Parse(v.id);skills[#skills+1]=v.skill end
        bag():SetTeamWithSkill(4,ids,skills)
    end
    function P.activate(i,first) assert(i==5);bag():SendSetActiveTeam(4,first)end
    local M=ZMLMTFactory(P);W.model=M
    function P.changed()
        if not M.pending then W.pendingPhase=nil end
        if W.refresh then for ctrl in pairs(W.controllers)do
            local ok,e=pcall(W.refresh,ctrl);if not ok then report('ui_refresh_failed',e)end
        end end
    end
    local function enabled(args)
        local z=api();if z.is_enabled and not z.is_enabled("more-teams") then return false end
        if type(args)~='table' or args.lockedTeamData or args.customTeamIndex or args.weekRaidArg or
            (args.dungeonId and args.dungeonId~='') or args.presetTeamId and args.presetTeamId~='' or
            args.initCharInstIdList or args.customSetTeamCallback then return false end
        if not GameInstance.isMainScope or bag().curTeamType:GetHashCode()~=0 then return false end
        if Tables.globalConst.totalSquadNum~=5 then return false end
        local info=GameInstance.player.playerInfoSystem
        local account=tostring(info.serverAreaType)..':'..tostring(info.roleId)
        if not info.roleId or info.roleId=='' or W.disabled[account]then return false end
        local ok,e=M.ensure(account)
        if not ok then W.disabled[account]=true;toast(e);report('storage_unavailable');return false end
        return true
    end
    function W.ctrlEnabled(s)return enabled(s.m_args)end
    function W.phaseEnabled(s)return enabled(s.arg)end
    function W.active()return M.active()end
    function W.phaseActive(s)return W.phaseEnabled(s)and M.active()or LuaIndex(bag().curTeamIndex)end
    function W.nativeIndex(s)return W.phaseEnabled(s)and math.min(s.m_curTeamIndex,5)or s.m_curTeamIndex end
    function W.blocked()return M.pending~=nil end
    function W.name(i)
        local n=M.get(i).name
        if i<5 then n=bag().teamList[i-1].name end
        return n~='' and n or string.format('编队 %02d',i)
    end
    function W.roster(i)
        local r={slots={},leaderIndex=1}
        for _,v in ipairs(M.get(i).slots)do
            local n=CS.System.UInt64.Parse(v.id);local ch=CharInfoUtils.getPlayerCharInfoByInstId(n)
            if ch then r.slots[#r.slots+1]={charInstId=n,charId=ch.templateId}end
        end
        return r
    end
    function W.charItems(s)
        if not W.ctrlEnabled(s)then
            if s.m_curTeamIndex>5 and s.m_customTeamIndex<=0 and not s.m_lockedTeamData then return {} end
            return nil
        end
        if s.m_curTeamIndex<5 then return nil end
        local positions={}
        for i,v in ipairs(M.get(s.m_curTeamIndex).slots)do positions[v.id]=i end
        local result,seen={},{}
        for _,item in ipairs(CharInfoUtils.getCharInfoList(4,true))do
            local id=decimal(item.instId)
            if not seen[id]then
                seen[id]=true
                local copy={};for k,v in pairs(item)do copy[k]=v end
                local position=positions[id]
                copy.slotIndex=position or Const.BATTLE_SQUAD_MAX_CHAR_NUM+1
                copy.slotReverseIndex=position and Const.BATTLE_SQUAD_MAX_CHAR_NUM-position or -1
                copy.singleSelect=position~=nil
                copy.selectIndex=nil;copy.isLocked=nil;copy.isTrail=nil;copy.isReplaceable=nil
                result[#result+1]=copy
            end
        end
        return result
    end
    function W.preview(s)
        local i=s.m_curTeamIndex
        if not W.phaseEnabled(s)then return i>5 and s.m_customTeamIndex<=0 and not s.m_lockedTeamData end
        if i<5 then return false end
        local team=W.roster(i);s.m_teamSkillCache={}
        for _,v in ipairs(M.get(i).slots)do s.m_teamSkillCache[CS.System.UInt64.Parse(v.id)]=v.skill end
        if s.m_charFormation then s.m_charFormation.uiCtrl:RefreshTeamCharInfo(team)end
        s:UpdateCharList(team.slots);return true
    end
    function W.save(s,ids,skills)
        if not W.phaseEnabled(s)then
            if s.m_curTeamIndex>5 and s.m_customTeamIndex<=0 then return false end
            return nil
        end
        if s.m_curTeamIndex<5 then return nil end
        local slots={}
        for _,n in ipairs(ids)do
            local ch=CharInfoUtils.getPlayerCharInfoByInstId(n)
            if not ch then
                toast('编队包含不可用干员，请重新编辑');return false
            end
            local skill=s.m_teamSkillCache and s.m_teamSkillCache[n] or ch.normalSkillId
            slots[#slots+1]={id=decimal(n),skill=skill or ''}
        end
        local ok,e=M.edit(s.m_curTeamIndex,{slots=slots})
        if not ok then toast(e);return false end
        P.changed();return true
    end
    function W.rename(s,name)
        if not W.ctrlEnabled(s)then return s.m_curTeamIndex>5 and s.m_customTeamIndex<=0 end
        if s.m_curTeamIndex<5 then return false end
        local ok,e=M.edit(s.m_curTeamIndex,{name=name})
        if not ok then toast(e);return true end
        s:RefreshTeamName();Notify(MessageConst.HIDE_POP_UP);P.changed();return true
    end
    function W.activate(s)
        if not W.phaseEnabled(s)then return s.m_curTeamIndex>5 and s.m_customTeamIndex<=0 end
        if s.m_curTeamIndex<5 then return false end
        if M.pending then return true end
        W.pendingPhase=s
        local ok,e=M.begin(s.m_curTeamIndex)
        if not ok then W.pendingPhase=nil;toast(e)end
        return true
    end
    function W.membersAck(s,index)
        if W.phaseEnabled(s)then
            if W.pendingPhase==s then M.membersAck(LuaIndex(index))end
            return index==4
        end
        return false
    end
    function W.activeAck(s)
        if W.ctrlEnabled(s)then M.activeAck()end
    end
    function W.tick(s)
        if not M.pending or W.pendingPhase~=s then return end
        local ok,e=pcall(function()
            if not W.phaseEnabled(s)then M.cancel();P.changed();return end
            M.tick()
        end)
        if not ok then M.finish(false,'编队切换失败');report('switch_failed',e)end
    end
    function W.closePhase(s)
        if W.pendingPhase==s then M.cancel();P.changed()end
    end
    function W.close(s)
        W.instances[s]=nil
        if W.closeUI then W.closeUI(s)end
        W.controllers[s]=nil
    end
    local z=api()
    if z.register_lifecycle then
        z.register_lifecycle('more-teams',{
            prepare=function() return not M.pending and not UIManager:IsShow(PanelId.CharFormation),'请先关闭编队编辑或等待编队切换完成' end,
            changed=function()
                local saved={};for s in pairs(W.instances)do saved[#saved+1]=s end
                for _,s in ipairs(saved)do
                    W.close(s)
                    s.m_curTeamIndex=LuaIndex(bag().curTeamIndex)
                    s:OnPhaseRefresh(s.m_args)
                end
            end
        })
    end
    _G.ZMLMoreTeams=W
end
