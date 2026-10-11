#pragma once
#include <string>
#include <string_view>
#include <vector>
#include <algorithm>
namespace teams {
inline constexpr auto marker="-- ZML_MORE_TEAMS_V1";
inline bool unique(std::string_view s,std::string_view a,size_t& n){n=s.find(a);return n!=s.npos && s.find(a,n+a.size())==s.npos;}
inline std::string literal(std::string_view s){
    std::string out="\"";for(unsigned char c:s){if(c=='\\'||c=='"')out+='\\';if(c<32){out+='\\';out+=char('0'+c/100);out+=char('0'+c/10%10);out+=char('0'+c%10);}else out+=char(c);}return out+'"';
}
inline bool patch(std::string_view source,bool phase,std::string_view boot,std::string& output){
    if(source.empty()||source.size()>512*1024||source.find('\0')!=source.npos||source.find(marker)!=source.npos||boot.empty()||boot.size()>96*1024)return false;
    std::string normalized(source);std::erase(normalized,'\r');source=normalized;
    struct Change {size_t at,count;std::string value;};std::vector<Change> edits;
    std::string cls=phase?"PhaseCharFormation":"CharFormationCtrl";
    auto change=[&](std::string_view method,std::string_view anchor,std::string value,bool insert=false){
        size_t a;if(!unique(source,cls+"."+std::string(method)+" = ",a))return false;
        auto end=source.find("\n"+cls+".",a+cls.size()+method.size()+4);
        if(end==source.npos)end=source.find("\nHL.Commit(",a);
        if(end==source.npos)return false;
        size_t i;if(!unique(source.substr(a,end-a),anchor,i))return false;
        edits.push_back({a+i,insert?0:anchor.size(),std::move(value)});return true;
    };
    auto prepend=[&](std::string_view method,std::string_view signature,std::string code){return change(method,signature,std::string(signature)+"\n    "+code);};
    if(!phase){
        if(!change("_Init","local totalSquadNum = Tables.globalConst.totalSquadNum","local totalSquadNum = ZMLMoreTeams.ctrlEnabled(self) and 20 or Tables.globalConst.totalSquadNum") ||
           !change("_Init","            self:_SetTeamSelect(luaIndex)","            if ZMLMoreTeams.ctrlEnabled(self) then ZMLMoreTeams.click(self,luaIndex) else self:_SetTeamSelect(luaIndex) end") ||
           !change("SetState","    self.state = state","    self.state = state\n    ZMLMoreTeams.stateChanged(self,state)") ||
           !prepend("OnHide","function(self)","ZMLMoreTeams.hidePopup(self)") ||
           !prepend("_OnChangeTeamNameClicked","function(self)","if not ZMLMoreTeams.ctrlEnabled(self) and self.m_curTeamIndex>5 and self.m_customTeamIndex<=0 then return end") ||
           !change("_Init","    self:BindInputPlayerAction(\"common_open_team_panel\"", "    ZMLMoreTeams.mount(self)\n    self:BindInputPlayerAction(\"common_open_team_panel\"") ||
           !prepend("_SetTeamSelect","function(self, index)","if not ZMLMoreTeams.ctrlEnabled(self) and index>5 and self.m_customTeamIndex<=0 then return end\n    if ZMLMoreTeams.ctrlEnabled(self) then\n        if ZMLMoreTeams.blocked() then return end\n        ZMLMoreTeams.hidePopup(self)\n    end") ||
           !change("_SetTeamSelect","    self:RefreshTeamName()","    self:RefreshTeamName()\n    if ZMLMoreTeams.ctrlEnabled(self) then ZMLMoreTeams.refresh(self) end") ||
           !change("_WrapTeamIndex","local totalSquadNum = Tables.globalConst.totalSquadNum","local totalSquadNum = ZMLMoreTeams.ctrlEnabled(self) and 20 or Tables.globalConst.totalSquadNum") ||
           !change("_RefreshCharList","self.m_tmpCharItems = CharInfoUtils.getCharInfoList(CSIndex(self.m_curTeamIndex), true)",
                "self.m_tmpCharItems = ZMLMoreTeams.charItems(self) or CharInfoUtils.getCharInfoList(CSIndex(self.m_curTeamIndex), true)") ||
           !change("_GetCurTeamIndex","return LuaIndex(GameInstance.player.charBag.curTeamIndex)","return ZMLMoreTeams.ctrlEnabled(self) and (ZMLMoreTeams.active()>0 and ZMLMoreTeams.active() or 5) or LuaIndex(GameInstance.player.charBag.curTeamIndex)") ||
           !change("UpdateTeamSet","self.m_teamSet = LuaIndex(GameInstance.player.charBag.curTeamIndex)","self.m_teamSet = ZMLMoreTeams.ctrlEnabled(self) and ZMLMoreTeams.active() or LuaIndex(GameInstance.player.charBag.curTeamIndex)") ||
           !prepend("RefreshTeamName","function(self, name)","if not ZMLMoreTeams.ctrlEnabled(self) and self.m_curTeamIndex>5 and self.m_customTeamIndex<=0 then return end\n    if ZMLMoreTeams.ctrlEnabled(self) then self.view.textName.text=ZMLMoreTeams.name(self.m_curTeamIndex); return end") ||
           !change("_OnChangeTeamNameClicked","local team = GameInstance.player.charBag.teamList[CSIndex(self.m_curTeamIndex)]\n    local name = team.name",
                "local name\n    if ZMLMoreTeams.ctrlEnabled(self) then name=ZMLMoreTeams.name(self.m_curTeamIndex)\n    else name=GameInstance.player.charBag.teamList[CSIndex(self.m_curTeamIndex)].name end") ||
           !change("_OnConfirmChangeTeamName","    GameInstance.player.charBag:SetTeamName(CSIndex(self.m_curTeamIndex), changedName)",
                "    if ZMLMoreTeams.rename(self,changedName) then return end\n    GameInstance.player.charBag:SetTeamName(CSIndex(self.m_curTeamIndex), changedName)") ||
           !prepend("_OnActiveSquadChange","function(self, args)","ZMLMoreTeams.activeAck(self)") ||
           !change("_OnActiveSquadChange","string.format(\"0%d\", LuaIndex(curTeamIndex))",
                "string.format(\"%02d\", ZMLMoreTeams.ctrlEnabled(self) and (ZMLMoreTeams.active()>0 and ZMLMoreTeams.active() or LuaIndex(curTeamIndex)) or LuaIndex(curTeamIndex))") ||
           !prepend("OnClose","function(self)","ZMLMoreTeams.close(self)") )return false;
    }else{
        if(!prepend("_RefreshTeamChars","function(self)","if ZMLMoreTeams.preview(self) then return end") ||
           !change("_BackToTeamSet","    if not setSquad then",
                "    if not setSquad or (ZMLMoreTeams.phaseEnabled(self) and self.m_curTeamIndex>=5) then") ||
           !change("OnCurSelectTeamChange","string.format(\"0%d\", teamIndex)","string.format(\"%02d\", teamIndex)") ||
           !change("_BackToTeamSet","LuaIndex(GameInstance.player.charBag.curTeamIndex)","ZMLMoreTeams.phaseActive(self)") ||
           !change("_TrySendSetSquad","LuaIndex(GameInstance.player.charBag.curTeamIndex)","ZMLMoreTeams.phaseActive(self)") ||
           !change("_TrySendSetSquad","        GameInstance.player.charBag:SetTeamWithSkill(CSIndex(self.m_curTeamIndex), charInstIds, normalSkillIds)",
                "        local localResult=ZMLMoreTeams.save(self,charInstIds,normalSkillIds)\n        if localResult~=nil then return localResult,aliveCharInstIds[1] end\n        GameInstance.player.charBag:SetTeamWithSkill(CSIndex(self.m_curTeamIndex), charInstIds, normalSkillIds)") ||
           !change("_SendChangeActiveSquad","    GameInstance.player.charBag:SendSetActiveTeam(CSIndex(self.m_curTeamIndex))",
                "    if ZMLMoreTeams.activate(self) then return end\n    GameInstance.player.charBag:SendSetActiveTeam(CSIndex(self.m_curTeamIndex))") ||
           !change("SetMemberAndActiveTeam","        GameInstance.player.charBag:SendSetActiveTeam(CSIndex(self.m_curTeamIndex), firstAliveInstId)",
                "        if not ZMLMoreTeams.activate(self) then GameInstance.player.charBag:SendSetActiveTeam(CSIndex(self.m_curTeamIndex), firstAliveInstId) end") ||
           !change("_OnSquadChange","    local teamIndex = unpack(args)","    local teamIndex = unpack(args)\n    if ZMLMoreTeams.membersAck(self,teamIndex) then return end") ||
           !prepend("_OnCharTeamNormalSkillChange","function(self, arg)",
                "if ZMLMoreTeams.phaseEnabled(self) and self.m_curTeamIndex>=5 then ZMLMoreTeams.tick(self);return end") ||
           !prepend("_OnSquadNameChange","function(self, arg)",
                "if ZMLMoreTeams.phaseEnabled(self) and self.m_curTeamIndex>=5 then return end") ||
           !change("_OnInit","        self:_TryConsumeWaitModels()","        self:_TryConsumeWaitModels()\n        ZMLMoreTeams.tick(self)") ||
           !prepend("_OnDestroy","function(self)","ZMLMoreTeams.closePhase(self)") ||
           !change("OnShowSkillTips","self.m_skillTip.uiCtrl:SetTeamIndex(self.m_curTeamIndex)",
                "self.m_skillTip.uiCtrl:SetTeamIndex(ZMLMoreTeams.nativeIndex(self))") )return false;
        // The second SetTeamIndex call lives in OnCurSelectTeamChange.
        if(!change("OnCurSelectTeamChange","self.m_skillTip.uiCtrl:SetTeamIndex(self.m_curTeamIndex)",
                "self.m_skillTip.uiCtrl:SetTeamIndex(ZMLMoreTeams.nativeIndex(self))"))return false;
    }
    size_t at;if(!unique(source,"HL.Commit("+cls+")",at))return false;
    edits.push_back({at,0,std::string(marker)+"\n"+std::string(boot)+"\n"});
    std::sort(edits.begin(),edits.end(),[](auto& a,auto& b){return a.at>b.at;});
    std::string result(source);for(auto& e:edits)result.replace(e.at,e.count,e.value);
    if(result.size()>768*1024)return false;
    output=std::move(result);return true;
}
}
