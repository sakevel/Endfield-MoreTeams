local W=assert(ZMLMoreTeams);local M=W.model
local phase={arg={},m_curTeamIndex=6,m_curTeam={},m_teamSkillCache={},m_lockedTeamData=nil,m_customTeamIndex=-1}
setmetatable(phase,{__index=function(_,k)local v=PhaseCharFormation[k];if type(v)=='function'or type(v)=='number'then return v end end})
local ctrl={m_args={},m_customTeamIndex=-1,m_curTeamIndex=1,m_index2Char={},m_teamSet=1,state=2,
    view={textName={text=''},bannerMidNode={gameObject={SetActive=function()end},numTxt={}}}}
setmetatable(ctrl,{__index=function(_,k)local v=CharFormationCtrl[k];if type(v)=='function'or type(v)=='number'then return v end end});ctrl.SetState=function(s,v)s.state=v end
phase.UpdateCharList=function(s,slots)s.lastSlots=slots;s.m_curTeam=slots end
assert(W.phaseEnabled(phase)and W.ctrlEnabled(ctrl))
assert(ctrl:_GetCurTeamIndex()==1);assert(ctrl:_WrapTeamIndex(20)==20 and ctrl:_WrapTeamIndex(21)==1 and ctrl:_WrapTeamIndex(0)==20)
phase.arg={lockedTeamData={}};assert(not W.phaseEnabled(phase));phase.arg={}
ctrl.m_args={dungeonId='locked_dungeon'};assert(ctrl:_WrapTeamIndex(6)==1);ctrl.m_args={}
assert(M.edit(6,{slots={{id='103',skill='c'},{id='101',skill='a'}},name='探索',color=3,mark=2}))
phase:_RefreshTeamChars();assert(#phase.lastSlots==2 and phase.lastSlots[1].charInstId==103)
assert(#Mock.sends==0,'preview stays entirely local')
ctrl.m_curTeamIndex=6;ctrl:RefreshTeamName();assert(ctrl.view.textName.text=='探索')
ctrl:_OnConfirmChangeTeamName('新名称');assert(M.get(6).name=='新名称'and #Mock.sends==0)
ctrl.m_curTeamIndex=4;ctrl:_OnConfirmChangeTeamName('原生改名');assert(Mock.sends[1].type=='name'and Mock.sends[1].index==3)
-- Execute the actual patched original save function, not a substitute implementation.
phase.m_curTeamIndex=6;phase.m_curTeam={{charInstId=103},{charInstId=101}};phase.m_teamSkillCache={}
local ok,first=phase:_TrySendSetSquad();assert(ok and first==103 and #Mock.sends==1)
assert(M.get(6).slots[1].id=='103'and M.get(6).slots[2].id=='101')
phase:_SendChangeActiveSquad();assert(Mock.sends[2].type=='members'and Mock.sends[2].index==4)
assert(#Mock.sends==2 and M.pending.stage=='members')
Mock.setRoster({103,101});phase:_OnSquadChange({4})
assert(Mock.sends[3].type=='active'and Mock.sends[3].index==4 and Mock.sends[3].first==103)
assert(M.pending.stage=='active'and M.active()==1)
Mock.bag.curTeamIndex=4;W.activeAck(ctrl);assert(not M.pending and M.active()==6)
assert(ctrl:_GetCurTeamIndex()==6);ctrl.m_curTeamIndex=6;ctrl:UpdateTeamSet();assert(ctrl.m_teamSet==6 and ctrl.state==1)
-- Already selected same payload skips SetTeam but still uses original legal active request.
phase:_SendChangeActiveSquad();assert(#Mock.sends==4 and Mock.sends[4].type=='active');W.activeAck(ctrl)
-- Native first four preserve transport and indices.
phase.m_curTeamIndex=4;phase.m_curTeam={{charInstId=102}};phase.m_teamSkillCache={}
assert(phase:_TrySendSetSquad());assert(Mock.sends[5].type=='members'and Mock.sends[5].index==3)
phase:_SendChangeActiveSquad();assert(Mock.sends[6].type=='active'and Mock.sends[6].index==3)
-- Failed local atomic write returns false, leaves snapshot/healthy file unchanged, never sends.
phase.m_curTeamIndex=6;phase.m_curTeam={{charInstId=102}};Mock.failWrite=true
assert(not phase:_TrySendSetSquad());assert(#Mock.sends==6 and M.get(6).slots[1].id=='103');Mock.failWrite=false
-- All-dead/forbidden formation checks must survive the transformed original code.
Mock.chars[102].dead=true;assert(not phase:_TrySendSetSquad());assert(#Mock.sends==6);Mock.chars[102].dead=false
Mock.forbidden=true;phase:_SendChangeActiveSquad();assert(not M.pending and #Mock.sends==6);Mock.forbidden=false
-- Closing phase cancels a pending request and the late response cannot trigger selection.
assert(M.edit(20,{slots={{id='102',skill='b'}}}));phase.m_curTeamIndex=20;phase.m_curTeam={{charInstId=102}}
phase:_SendChangeActiveSquad();assert(#Mock.sends==7);W.closePhase({});assert(M.pending,'foreign phase cannot cancel own transaction');W.closePhase(phase);Mock.setRoster({102});phase:_OnSquadChange({4});assert(#Mock.sends==7)
-- Account change, no shared roles or local roster cross-contamination.
GameInstance.player.playerInfoSystem.roleId='account-b';assert(W.phaseEnabled(phase));assert(#M.get(20).slots==0)
GameInstance.player.playerInfoSystem.roleId='account-a';assert(W.phaseEnabled(phase));assert(M.get(20).slots[1].id=='102')
-- Eligibility lost while a logical selection is displayed must never send an out-of-range index.
phase.m_curTeamIndex=20;phase.m_curTeam={{charInstId=102}};ctrl.m_curTeamIndex=20
local sent=#Mock.sends;GameInstance.isMainScope=false
assert(not phase:_TrySendSetSquad());phase:_SendChangeActiveSquad();ctrl:_OnConfirmChangeTeamName('不可提交')
ctrl:RefreshTeamName();phase:_RefreshTeamChars();ctrl:_SetTeamSelect(19)
assert(#Mock.sends==sent and ctrl.m_curTeamIndex==20)
GameInstance.isMainScope=true
-- Immutable runtime constants: no server squad capacity writes/global index manipulation.
assert(Tables.globalConst.totalSquadNum==5 and Mock.bag.curTeamIndex==4)
print('PASS actual transformed current-client save/preview/rename/activation; native 1-4, mapped 5, ack order, failure, locked-context fallback, closing, account separation')
