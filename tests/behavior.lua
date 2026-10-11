local server={{id='18446744073709551615',skill='skill_a'}},active,now
active=1;now=0
local files,writes,calls,errors={},{},{},{}
local failWrite,failRead,deny=false,false,false
local P={time=function()return now end,serverActive=function()return active end,
    serverRoster=function()return server end,read=function(a)return files[a],failRead and 'read error'or nil end,
    write=function(a,s)if failWrite then return false,'write error'end;files[a]=s;writes[#writes+1]=s;return true end,
    changed=function()end,error=function(e)errors[#errors+1]=e end,
    validate=function(slots)if deny or #slots==0 then return false,'not available'end;return true,slots[1].id end,
    members=function(i,s)assert(i==5);calls[#calls+1]={'members',i,s}end,
    activate=function(i)assert(i==5);calls[#calls+1]={'activate',i}end}
local M=Factory(P)
assert(M.ensure('account-a'));assert(#M.data.teams==20 and M.get(5).slots[1].id=='18446744073709551615')
assert(#M.get(6).slots==0 and M.active()==1)
local snap=M.encode(M.data);assert(M.encode(assert(M.decode(snap)))==snap)
assert(not M.decode(snap:gsub('18446744073709551615','18446744073709551616')))
assert(not M.decode(snap:gsub('T|2|','T|3|',1)))
assert(not M.decode(snap..'unexpected\n'));assert(not M.decode('bad'))
for _,s in ipairs({'0','-1','1e9','1.2','00001','18446744073709551616'})do assert(not M.edit(6,{slots={{id=s,skill='x'}}}))end
assert(not M.edit(6,{name='<b>foo</b>'}));assert(not M.edit(6,{name='x\0'}));assert(not M.edit(6,{mark=17}))
for mark=1,16 do
    assert(M.edit(6,{mark=mark}));local saved=M.encode(M.data)
    assert(M.decode(saved).teams[6].mark==mark,'all profession/combat marks roundtrip')
end
assert(not M.edit(6,{mark=0}));assert(not M.edit(6,{mark=8.5}))
assert(not M.edit(1,{slots={{id='2',skill='x'}}}));assert(not M.edit(6,{slots={{id='2',skill='x'},{id='2',skill='y'}}}))
local roster={{id='12345678901234567890',skill='alt'},{id='8',skill='b'}}
assert(M.edit(20,{slots=roster,name='治疗 / 探索',color=4,mark=6}));assert(#calls==0,'local save does not send')
local g=M.get(20);g.slots[1].id='99';assert(M.get(20).slots[1].id==roster[1].id,'defensive copy')
failWrite=true;assert(not M.edit(20,{name='oops'}));assert(M.get(20).name=='治疗 / 探索');failWrite=false
assert(M.begin(20));assert(#calls==1 and calls[1][1]=='members' and M.pending)
assert(not M.begin(6));assert(not M.edit(20,{color=2}));M.membersAck(4);assert(#calls==1)
now=1;M.tick();assert(#calls==1,'no activation before server ack')
server={{id=roster[1].id,skill='wrong'},{id='8',skill='b'}};M.membersAck(5);assert(#calls==1,'skills must also match')
server=roster;M.tick();assert(#calls==2 and calls[2][1]=='activate');assert(M.active()==1,'no optimistic active')
active=5;M.activeAck();assert(not M.pending and M.active()==20 and M.data.active==20)
assert(M.begin(20));assert(#calls==3 and calls[3][1]=='activate','already verified roster needs no extra member request')
M.activeAck();assert(not M.pending)
assert(M.edit(6,{slots={{id='7',skill='c'}}}));assert(M.begin(6));now=20;M.tick();assert(not M.pending and #errors>0 and M.active()==20)
local count=#calls;server={{id='7',skill='c'}};M.membersAck(5);M.activeAck();assert(#calls==count,'late replies cannot activate abandoned transaction')
assert(M.begin(20));M.cancel();server=roster;M.membersAck(5);assert(#calls==count+1)
deny=true;assert(not M.begin(20)and not M.pending);deny=false
assert(not M.begin(7),'empty team cannot be activated')
server=roster;assert(M.ensure('account-b'));assert(M.get(20).name==''and #M.get(5).slots==2)
assert(M.ensure('account-a'));assert(M.get(20).name=='治疗 / 探索','account-separated persistence')
files['corrupt']='broken';local before=files.corrupt;assert(not M.ensure('corrupt'));assert(files.corrupt==before,'bad data preserved')
failRead=true;assert(not M.ensure('unreadable'));failRead=false
assert(M.ensure('account-a'));server={{id='99',skill='q'}};assert(M.active()==0,'external native edit not misrepresented')
-- Transport throws: unlock and do not mark active.
P.members=function()error('transport')end;assert(not M.begin(20));assert(not M.pending)
print('PASS 20 teams, 64-bit ids, metadata, local-only editing, account isolation, atomic storage, ordered server acknowledgements, timeout/cancel/failure')
