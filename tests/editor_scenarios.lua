local W=ZMLMoreTeams;local M=W.model
GEnums.CharType={Default=0,Trial=1}
GameUtil={IsRuntimeClientId=function(n)return n>=9000 end}
Mock.bag.charInfos=Mock.chars
for _,ch in pairs(Mock.chars)do ch.charType=0;ch.level=1;ch.ownTime=1 end
Mock.makeChar(104,nil);Mock.chars[104].charType=0
Mock.makeChar(106,nil);Mock.chars[106].charType=0
Mock.makeChar(9001,nil);Mock.chars[9001].charType=1
Mock.makeChar(9002,nil);Mock.chars[9002].charType=0
Mock.makeChar(105,nil);Mock.chars[105].charType=1
Tables.characterTable={GetValue=function()return{rarity=6,sortOrder=0}end}
UIConst.CharListMode={MultiSelect=1,Single=2};UIConst.UIConst=UIConst
UIConst.CHAR_FORMATION_LIST_SORT_OPTION={{reverseKeys={'slotReverseIndex'}}}
Utils.genSortFunction=function(keys,ascending)return function(a,b)
 for _,k in ipairs(keys)do local x,y=a[k]or 0,b[k]or 0
  if x~=y then if ascending then return x<y else return x>y end end
 end
 return a.instId<b.instId
end end
local function copy(t)if type(t)~='table'then return t end
 local r={};for k,v in pairs(t)do r[k]=copy(v)end;return r
end
lume={sort=function(t,cmp)table.sort(t,cmp);return t end,deepCopy=copy}
Utils.isInclude=function(t,v)for _,x in pairs(t)do if x==v then return true end end;return false end
DeviceInfo={usingController=false}
UIUtils.PlayAnimationAndToggleActive=function()end
local function instance(cls,t)return setmetatable(t or {},{__index=function(_,k)
 local v=cls[k];if type(v)=='function' or type(v)=='number' then return v end
end})end
local list=instance(CharFormationList,{view={animationWrapper={}}})
list._FirstTimeInit=function()end
list._ShowMultiChars=function()end;list._ShowSingleChars=function()end
list.view.sortNode={SortCurData=function()list:_OnSortChanged({reverseKeys={'slotReverseIndex'}},false)end}
list._RefreshCharList=function(s)
 if s.m_onCharListChanged then s.m_onCharListChanged(s.m_filteredCharList)end
end
list.GetCellByIndex=function(s,i)
 local item=s.m_filteredCharList[i];if not item then return nil end
 return {info=item,charInfo=item,view={button={}},SetMultiSelect=function()end,SetSingleSelect=function()end}
end
local ctrl=instance(CharFormationCtrl,{m_args={},m_customTeamIndex=-1,m_curTeamIndex=6,
 state=2,view={charList=list},m_index2Char={}})
ctrl._RefreshCharListEmptyState=function()end;ctrl._ActiveTeamInfo=function()end
ctrl._UpdateSlotConfirmBinding=function()end
ctrl.Notify=function()end
local phase=instance(PhaseCharFormation,{arg={},m_customTeamIndex=-1,m_curTeamIndex=6,
 m_curTeam={},m_teamSkillCache={},m_charFormation={uiCtrl=ctrl}})
phase.UpdateCharList=function(s,slots)s.m_curTeam=slots end
phase._TryUpdateModels=function(s,slots)s.modelSlots=slots end
phase.UpdateCharList=PhaseCharFormation.UpdateCharList
phase._RefreshEmpty=function()end;phase._RefreshCamera=function()end
phase._Refresh3DUIVisible=function()end;phase._HideAllControllerSlotSelected=function()end
phase.RefreshSlotVisible=function()end;phase._HideSkillTip=function()end
phase._RefreshControllerSlotSelectedState=function()end;phase._PlaySingleCharVoice=function()end
ctrl.RefreshCharInformation=function(s,info)s.m_singleCharInfo=info end
ctrl.SetState=function(s,state)s.state=state end
ctrl.CloseCharList=function()end
ctrl.RefreshSingleBtns=function(s,state)s.singleState=state end
ctrl._UpdateCharConfirmBinding=function()end
list._RefreshMode=function()end
ctrl.m_phase=phase
ctrl.Notify=function(_,key,arg)
 if key==MessageConst.ON_CHAR_FORMATION_LIST_SINGLE_SELECT then phase:OnCharListSingleSelect(arg)end
end
Utils.triggerVoice=function()end
UIConst.UI_CHAR_FORMATION_SINGLE_STATE={None=0,Current=1,OtherAvailable=2,OtherInTeam=3,OtherDead=4}
phase.m_sceneObject={view={}}
for i=1,4 do phase.m_sceneObject.view['slot'..i]={slotCharDisableFx={gameObject={SetActive=function()end}}}end
local deco={textNum={},gameObject={SetActive=function()end},animationWrapper={PlayInAnimation=function()end}}
phase.m_sceneObject.view.formationDeco=deco
assert(W.phaseEnabled(phase))
local function open(i,mode)
 ctrl.m_curTeamIndex=i;phase.m_curTeamIndex=i;phase:_RefreshTeamChars()
 ctrl:OpenCharList(mode or UIConst.CharListMode.MultiSelect)
end
local function selected()
 local ids={};for _,item in ipairs(ctrl:GetCurCharList())do ids[#ids+1]=item.instId end
 return ids
end
-- Proxy is full, but logical 6 is empty. No server selection may leak in.
Mock.setRoster({101,102,103,104})
open(6);assert(list.m_charNum==0 and #selected()==0,'empty logical roster must not inherit proxy members')
assert(#ctrl.m_tmpCharItems==5,'ordinary candidates follow the native utility')
assert(#Mock.sends==0)
for i=1,4 do list:OnClickItem(i,false)end
assert(list.m_charNum==4 and #selected()==4,'empty logical team permits real native selection')
list:OnClickItem(5,false);assert(list.m_charNum==4 and #selected()==4,'native capacity still applies')
list:OnClickItem(1,false);assert(list.m_charNum==3 and #selected()==3)
list:OnClickItem(5,false);assert(list.m_charNum==4 and #selected()==4)
for i=5,20 do
 assert(M.edit(i,{slots={}}));open(i)
 assert(list.m_charNum==0 and #selected()==0)
 for _,item in ipairs(ctrl.m_tmpCharItems)do
  assert(item.slotIndex==5 and not item.singleSelect and not item.isLocked and not item.isTrail)
 end
end
-- Native ShowSelectChars and RecoverMultiCharListSelection produce the actual
-- edit payload: select four, deselect, save, reopen, switch away/back.
open(20)
local items,infos=ctrl:RecoverMultiCharListSelection({104,103,102,101})
phase.m_tmpTeam=items;assert(#items==4 and list.m_charNum==4)
assert(phase:_TrySendSetSquad(),'nil normalSkillId is a legal default skill, not invalid formation data')
assert(M.get(20).slots[1].id=='104' and M.get(20).slots[1].skill=='')
phase.m_tmpTeam=nil
open(6);open(20);assert(list.m_charNum==4 and selected()[1]==104)
items=ctrl:RecoverMultiCharListSelection({104,101})
phase.m_tmpTeam=items;assert(phase:_TrySendSetSquad());phase.m_tmpTeam=nil
open(20,UIConst.CharListMode.Single);assert(#selected()==2)
open(6);assert(list.m_charNum==0)
-- Mixed absent/explicit skills: native table.insert(nil) creates a short list.
-- Save must use per-instance cache/source, not shift skill IDs by array index.
phase.m_curTeamIndex=5;phase.m_curTeam={{charInstId=104},{charInstId=101},{charInstId=102}}
phase.m_teamSkillCache={[102]='override'}
assert(phase:_TrySendSetSquad())
local saved=M.get(5).slots
assert(saved[1].skill=='' and saved[2].skill=='a' and saved[3].skill=='override')
assert(#Mock.sends==0,'all editing stays local')
-- Exercise the actual click -> single preview -> confirm -> native return path.
-- Local commits do not emit native SQUAD_CHANGE, so they must refresh both
-- slot information and scene models themselves, not wait for a server event.
for teamIndex=5,20 do
 assert(M.edit(teamIndex,{slots={{id='101',skill='a'},{id='102',skill='b'}}}))
 ctrl.state=UIConst.UI_CHAR_FORMATION_STATE.TeamWaitSet
 open(teamIndex,UIConst.CharListMode.MultiSelect)
 phase:OnEnterSingleChar(1)
 local candidate=list:_GetCharIndex(104)
 list:OnClickItem(candidate,false)
 assert(ctrl.singleState==UIConst.UI_CHAR_FORMATION_SINGLE_STATE.OtherAvailable)
 assert(phase.m_curTeam[1].charInstId==104,'native single click previews replacement')
 phase:OnConfirmSingleChar(teamIndex)
 assert(M.get(teamIndex).slots[1].id=='104','single confirmation saves replacement')
 assert(ctrl.m_index2Char[1].charInstId==104,'single return must refresh native slot, not leave old occupant')
 assert(phase.modelSlots[1].charInstId==104,'single return must retain full models, not clear scene')
 assert(phase.modelSlots[2].charInstId==102)
 -- Repeated single editing sees the saved occupant; cancel restores storage.
 phase:OnEnterSingleChar(1)
 list:OnClickItem(list:_GetCharIndex(106),false)
 phase:_BackToTeamSet()
 assert(M.get(teamIndex).slots[1].id=='104' and ctrl.m_index2Char[1].charInstId==104)
 assert(phase.modelSlots[1].charInstId==104 and #Mock.sends==0)
 -- Native membership/death states still control the confirm button.
 phase:OnEnterSingleChar(1)
 list:OnClickItem(list:_GetCharIndex(102),false)
 assert(ctrl.singleState==UIConst.UI_CHAR_FORMATION_SINGLE_STATE.OtherInTeam)
 Mock.chars[106].dead=true
 list:OnClickItem(list:_GetCharIndex(106),false)
 assert(ctrl.singleState==UIConst.UI_CHAR_FORMATION_SINGLE_STATE.OtherDead)
 Mock.chars[106].dead=false;phase:_BackToTeamSet()
 -- Removing one slot uses the same local commit -> full scene refresh.
 phase:OnEnterSingleChar(1);phase:OnUnEquipIndex()
 assert(#M.get(teamIndex).slots==1 and M.get(teamIndex).slots[1].id=='102')
 assert(ctrl.m_index2Char[1].charInstId==102 and ctrl.m_index2Char[2]==nil)
 assert(#phase.modelSlots==1 and phase.modelSlots[1].charInstId==102)
 phase:OnEnterSingleChar(1);phase:OnUnEquipIndex()
 assert(#M.get(teamIndex).slots==1,'native last-member removal guard retained')
 phase:_BackToTeamSet()
end
-- Restore the proxy-ack fixture used below.
assert(M.edit(5,{slots={{id='104',skill=''},{id='101',skill='a'},{id='102',skill='override'}}}))
-- Same two-character budget as the original 01-05 scene text: no 010/020.
for i=1,20 do
 ctrl.m_curTeamIndex=i;phase:OnCurSelectTeamChange(i)
 assert(deco.textNum.text==string.format('%02d',i) and #deco.textNum.text==2,
  'scene number must stay two digits, including every double-digit team')
end
-- Native candidates are not filtered again by character type. The proxy
-- may contain a trial/runtime member; selection still belongs to local team 6.
assert(M.edit(6,{slots={}}))
Mock.setRoster({9001,9002,105,101});open(6)
local nativeCandidates=CharInfoUtils.getCharInfoList(4,true)
assert(#ctrl.m_tmpCharItems==#nativeCandidates and #nativeCandidates==8 and list.m_charNum==0)
local expected={};for _,item in ipairs(nativeCandidates)do expected[item.instId]=true end
for _,item in ipairs(ctrl.m_tmpCharItems)do
 assert(expected[item.instId]);expected[item.instId]=nil
 assert(item.slotIndex==5 and item.slotReverseIndex==-1 and not item.singleSelect)
end
assert(next(expected)==nil,'preserve every native candidate without an extra type filter')
-- The removed restriction must not survive in the local-save path either.
local errors=#Mock.errors
phase.m_teamSkillCache={}
local items=ctrl:RecoverMultiCharListSelection({105,9001})
phase.m_tmpTeam=items
assert(#items==2 and phase:_TrySendSetSquad(),'native-provided trial/runtime candidates can be saved locally')
assert(#Mock.errors==errors and #Mock.sends==0)
assert(M.get(6).slots[1].id=='105' and M.get(6).slots[2].id=='9001')
phase.m_tmpTeam=nil;open(6)
assert(list.m_charNum==2 and selected()[1]==105 and selected()[2]==9001)
assert(W.save(phase,{9999},{})==false,'missing-character validation is retained')
assert(M.get(6).slots[1].id=='105' and #M.get(6).slots==2)
assert(M.edit(6,{slots={}}));Mock.setRoster({101,102,103,104})
-- Native first four retain original membership and native selection.
Mock.bag.teamList[0].memberList={Count=1,[0]=102};open(1)
assert(list.m_charNum==1 and selected()[1]==102)
ctrl.m_args={dungeonId='locked'};ctrl.m_curTeamIndex=6
ctrl:_RefreshCharList()
assert(#ctrl.m_tmpCharItems==0 and #Mock.sends==0,'lost eligibility must not index an invalid native team')
-- Preserve default/explicit skill alignment through the legal proxy request.
ctrl.m_args={}
assert(M.begin(5));assert(#Mock.sends==1 and Mock.sends[1].index==4)
local sent=Mock.sends[1]
assert(sent.ids[1]==104 and sent.skills[1]=='' and sent.skills[2]=='a' and sent.skills[3]=='override')
Mock.setRoster({104,101,102});M.membersAck(5)
assert(#Mock.sends==1,'explicit changed skill still requires matching server state')
Mock.chars[102].normalSkillId='override';M.tick()
assert(#Mock.sends==2 and Mock.sends[2].type=='active' and Mock.sends[2].index==4)
Mock.bag.curTeamIndex=4;M.activeAck();assert(not M.pending and M.active()==5)
print('PASS actual client editor: all local 5-20, proxy independence, empty/full/deselect/single/reopen, nil and mixed skills, native candidate policy without extra trial filter, native 1-4')
