return function(P)
    local M={data=nil,pending=nil,account=nil}
    local function copy(v)
        if type(v)~='table' then return v end
        local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r
    end
    local function integer(x,a,b) return type(x)=='number' and x%1==0 and x>=a and x<=b end
    local function hex(s) return (s:gsub('.',function(c)return string.format('%02x',c:byte())end)) end
    local function unhex(s)
        if #s%2~=0 or s:find('[^0-9a-f]') then return nil end
        return (s:gsub('..',function(c)return string.char(tonumber(c,16))end))
    end
    local function text(s,max)
        return type(s)=='string' and #s<=max and not s:find('[%z\1-\31\127]') and not s:find('[<>]')
    end
    local function id(s)
        return type(s)=='string' and s:match('^[1-9]%d*$') and #s<=20 and (#s<20 or s<='18446744073709551615')
    end
    local function validTeam(t)
        if type(t)~='table' or not text(t.name,96) or not integer(t.color,1,8) or not integer(t.mark,1,16) or type(t.slots)~='table' or #t.slots>4 then return false end
        local seen={}
        for _,v in ipairs(t.slots)do
            if type(v)~='table' or not id(v.id) or seen[v.id] or not text(v.skill,128) then return false end
            seen[v.id]=true
        end
        return true
    end
    function M.encode(d)
        assert(integer(d.active,0,20) and #d.teams==20,'Invalid team data')
        local lines={'ZMLTEAMS1','A|'..d.active}
        for i,t in ipairs(d.teams)do
            assert(validTeam(t) and (i>=5 or #t.slots==0),'Invalid team')
            local roster={};for _,v in ipairs(t.slots)do roster[#roster+1]=v.id..'/'..hex(v.skill)end
            lines[#lines+1]=table.concat({'T',i,hex(t.name),t.color,t.mark,table.concat(roster,',')},'|')
        end
        return table.concat(lines,'\n')..'\n'
    end
    function M.decode(s)
        if type(s)~='string' or #s>32768 or s:find('\r') or s:find('%z') then return nil end
        local lines={};for line in s:gmatch('([^\n]+)')do lines[#lines+1]=line end
        if #lines~=22 or lines[1]~='ZMLTEAMS1' then return nil end
        local active=lines[2]:match('^A|(%d+)$');active=active and tonumber(active)
        if not integer(active,0,20) then return nil end
        local d={active=active,teams={}}
        for i=1,20 do
            local n,name,col,mark,slots=lines[i+2]:match('^T|(%d+)|([0-9a-f]*)|(%d+)|(%d+)|(.*)$')
            if tonumber(n)~=i or not slots or slots:find(',,',1,true) or slots:sub(1,1)==',' or slots:sub(-1)==',' then return nil end
            local t={name=unhex(name),color=tonumber(col),mark=tonumber(mark),slots={}}
            for slot in slots:gmatch('[^,]+')do
                local uid,skill=slot:match('^(%d+)/([0-9a-f]*)$')
                if not uid then return nil end
                t.slots[#t.slots+1]={id=uid,skill=unhex(skill)}
            end
            if not validTeam(t) or (i<5 and #t.slots>0) then return nil end
            d.teams[i]=t
        end
        return d
    end
    function M.ensure(account)
        assert(type(account)=='string' and #account>0 and #account<=256,'Account identity unavailable')
        if M.account==account and M.data then return true end
        M.pending=nil;M.data=nil;M.account=account
        local content,err=P.read(account)
        if err then return false,err end
        if content then M.data=M.decode(content);if not M.data then return false,'编队存档损坏，已保留原文件' end
        else
            local d={active=0,teams={}}
            for i=1,20 do d.teams[i]={name='',color=1,mark=1,slots={}}end
            d.teams[5].slots=copy(P.serverRoster(5))
            local ok,e=P.write(account,M.encode(d));if not ok then return false,e end
            M.data=d
        end
        return true
    end
    function M.commit(d)
        local ok,e=P.write(M.account,M.encode(d));if not ok then return false,e end
        M.data=d;return true
    end
    function M.get(i) assert(integer(i,1,20));return copy(M.data.teams[i]) end
    function M.edit(i,changes)
        if M.pending then return false,'编队切换中' end
        local d=copy(M.data);local t=d.teams[i]
        if not t then return false,'编队不存在' end
        for k,v in pairs(changes)do
            if k~='name' and k~='color' and k~='mark' and k~='slots' then return false,'无效字段' end
            t[k]=copy(v)
        end
        if not validTeam(t) or (i<5 and #t.slots>0) then return false,'无效编队数据' end
        return M.commit(d)
    end
    function M.rosterSame(a,b,skills)
        if #a~=#b then return false end
        for i,v in ipairs(a)do if v.id~=b[i].id or (skills and v.skill~=b[i].skill)then return false end end
        return true
    end
    function M.active()
        local native=P.serverActive()
        if native<5 then return native end
        local roster=P.serverRoster(5)
        local saved=M.data.active
        if saved>=5 and M.rosterSame(roster,M.data.teams[saved].slots,true) then return saved end
        for i=5,20 do if #roster>0 and M.rosterSame(roster,M.data.teams[i].slots,true) then return i end end
        return 0
    end
    function M.finish(ok,message)
        local p=M.pending;if not p then return end
        M.pending=nil
        if ok then
            local d=copy(M.data);d.active=p.index
            local saved,e=M.commit(d)
            if not saved then P.error(e) end
        elseif message then P.error(message) end
        P.changed()
    end
    function M.cancel() M.pending=nil end
    function M.activateStage()
        local p=assert(M.pending)
        p.stage='active';p.deadline=P.time()+12
        P.activate(5,p.firstAlive)
    end
    function M.begin(i)
        if M.pending then return false,'编队切换中' end
        local slots=M.get(i).slots
        if i<5 then return false,'原生编队无需映射' end
        local ok,firstAlive=P.validate(slots);if not ok then return false,firstAlive end
        local server=P.serverRoster(5)
        M.pending={index=i,slots=slots,firstAlive=firstAlive,stage='members',deadline=P.time()+12,
            membersAck=M.rosterSame(server,slots,false)}
        P.changed()
        local sent,e=pcall(function()
            if M.rosterSame(server,slots,true) then M.activateStage()
            else P.members(5,slots) end
        end)
        if not sent then M.finish(false,'编队切换失败');return false,tostring(e) end
        return true
    end
    function M.membersAck(index)
        local p=M.pending
        if not p or p.stage~='members' or index~=5 then return end
        if M.rosterSame(P.serverRoster(5),p.slots,false) then p.membersAck=true end
        M.tick()
    end
    function M.activeAck()
        local p=M.pending
        if p and p.stage=='active' and P.serverActive()==5 and M.rosterSame(P.serverRoster(5),p.slots,true)then M.finish(true)end
    end
    function M.tick()
        local p=M.pending;if not p then return end
        if P.time()>p.deadline then M.finish(false,'编队切换超时，请稍后重试');return end
        if p.stage=='members' and p.membersAck and M.rosterSame(P.serverRoster(5),p.slots,true)then
            local ok=pcall(M.activateStage);if not ok then M.finish(false,'编队切换失败')end
        end
    end
    return M
end
