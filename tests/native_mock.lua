unpack=table.unpack;loadstring=load
local function descriptor()
    local d={};d.Return=function()return d end
    return setmetatable(d,{__shl=function(_,v)return v end})
end
HL={Class=function()return{}end,Field=descriptor,StaticField=descriptor,Method=descriptor,StaticMethod=descriptor,
    Override=descriptor,StaticMethod=descriptor,Commit=function()end,Opt=function()end,Forward=function()end}
local function dummy()return setmetatable({},{__index=function(t,k)local x=dummy();rawset(t,k,x);return x end,
    __call=function()return dummy()end})end
CS=dummy();CS.UnityEngine.Time={unscaledTime=0}
CS.System.UInt64.Parse=function(n)return assert(tonumber(n))end -- fixture ids kept within signed 53-bit range; core has uint64-string tests
CS.System.Text={Encoding={UTF8={}},UTF8Encoding=function()return {}end}
local files={};local pendingFiles={}
Mock={files=files,sends={},chars={},errors={},active=0,failWrite=false,root='C:/test-more-teams-state'}
local IO={File={},Path={}}
CS.System.IO=IO;IO.Path.Combine=function(a,b)return a..'/'..b end
IO.Directory={CreateDirectory=function()end}
IO.File.Exists=function(p)return files[p]~=nil end
IO.File.ReadAllText=function(p)return files[p]end
IO.File.WriteAllText=function(p,s)assert(not Mock.failWrite,'disk error');files[p]=s end
IO.File.Move=function(a,b)assert(files[a]and not files[b]);files[b]=files[a];files[a]=nil end
IO.File.Replace=function(a,b,backup)assert(files[a]and files[b]);files[backup]=files[b];files[b]=files[a];files[a]=nil end
IO.File.Delete=function(p)files[p]=nil end
IO.FileInfo=function(p)return{Length=#files[p]}end
CS.System.Guid.NewGuid=function()return{ToString=function()return 'testguid' end}end
local list={Count=0};Mock.team={memberList=list,name='',leaderIndex=0}
local bag={curTeamIndex=0,curTeamType={GetHashCode=function()return 0 end},maxCharTeamMemberCount=4,teamList={}}
for i=0,4 do bag.teamList[i]={name='原生队'..(i+1),memberList={Count=0},leaderIndex=0}end
bag.GetCurrentMainTeamByIndex=function(_,i)assert(i>=0 and i<5,'out of bounds');return bag.teamList[i]end
bag.SetTeamWithSkill=function(_,i,ids,skills)assert(i>=0 and i<5);Mock.sends[#Mock.sends+1]={type='members',index=i,ids=ids,skills=skills}end
bag.SendSetActiveTeam=function(_,i,first)assert(i>=0 and i<5);Mock.sends[#Mock.sends+1]={type='active',index=i,first=first}end
bag.SetTeamName=function(_,i,n)assert(i>=0 and i<5);bag.teamList[i].name=n;Mock.sends[#Mock.sends+1]={type='name',index=i}end
Mock.bag=bag
GameInstance={isMainScope=true,player={charBag=bag,playerInfoSystem={roleId='account-a',serverAreaType=1}}}
CSIndex=function(i)return i-1 end;LuaIndex=function(i)return i+1 end
CharInfoUtils={getPlayerCharInfoByInstId=function(n)return Mock.chars[n]end,
    IsServerDefaultChar=function(ch)return ch.charType==nil or ch.charType==0 end,
    isCharDead=function(n)return Mock.chars[n].dead end}
Tables={globalConst={totalSquadNum=5}}
UIConst={UI_CHAR_FORMATION_STATE={TeamHasSet=1,TeamWaitSet=2,SingleChar=3},INPUT_FIELD_CHARACTER_LIMIT=24}
Utils={isForbidden=function()return Mock.forbidden or false end}
ForbidType={ForbidSetSquad=1};Const={BATTLE_SQUAD_MAX_CHAR_NUM=4}
Language=setmetatable({},{__index=function(_,k)return k end})
MessageConst=setmetatable({},{__index=function(_,k)return k end})
Notify=function(k,msg)if k=='SHOW_TOAST'then Mock.errors[#Mock.errors+1]=msg end end
logger={error=function(e)Mock.errors[#Mock.errors+1]=e end}
LuaManagerInst={LoadLua=function(_,p)assert(p=='ZML/Api');return 'return {report=function()return true end}'end}
require_ex=function()return {UICtrl={},PhaseBase={}}end
PanelId={CharFormation=1};PhaseId={CharFormation=1};PhaseConst=dummy();GEnums=dummy();CameraManager=dummy();UIUtils=dummy();InputManagerInst=dummy()
Transform={};PhaseManager=dummy();AudioAdapter=dummy();I18nUtils={GetTextRealLength=function(n)return #n end}
string.isEmpty=function(s)return not s or s=='' end
Mock.makeChar=function(n,skill)Mock.chars[n]={instId=n,templateId='char_'..n,normalSkillId=skill,dead=false}end
Mock.setRoster=function(ids,skills)
    local l={Count=#ids};for j,n in ipairs(ids)do l[j-1]=n;if skills then Mock.chars[n].normalSkillId=skills[j]end end
    bag.teamList[4].memberList=l
end
Mock.makeChar(101,'a');Mock.makeChar(102,'b');Mock.makeChar(103,'c');Mock.setRoster({101,102})
