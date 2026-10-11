local U=CS.UnityEngine
local function event()
    return {list={},AddListener=function(s,f)s.list[#s.list+1]=f end,RemoveAllListeners=function(s)s.list={}end,
        Invoke=function(s)for _,f in ipairs(s.list)do f()end end}
end
U.Color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end
U.Vector2=setmetatable({zero={x=0,y=0},one={x=1,y=1}},{__call=function(_,x,y)return{x=x,y=y}end})
U.Vector3=setmetatable({one={x=1,y=1,z=1}},{__call=function(_,x,y,z)return{x=x,y=y,z=z}end})
local function q()return setmetatable({},{__mul=function()return q()end})end
U.Quaternion={Euler=q,Inverse=q,identity=q()}
U.RectTransform={};U.UI={Mask={},RawImage={},Image={Type={Sliced=1}},Button={},LayoutElement={},Selectable={Transition={None=0,ColorTint=1}},LayoutGroup={},ContentSizeFitter={}}
CS.TMPro={TextMeshProUGUI={},TextAlignmentOptions={Center=1,Left=2},TextOverflowModes={Ellipsis=1}}
typeof=function(x)return x end
local function go(name)
    local obj={name=name,layer=5,components={},activeSelf=true}
    function obj:SetActive(v)self.activeSelf=v end
    function obj:Equals(v)return v==nil and self.destroyed==true end
    function obj:AddComponent(kind)
        local c={gameObject=self,Equals=function(s)return s.gameObject.destroyed==true end}
        if kind==U.RectTransform then
            c.sizeDelta={x=50,y=50};c.pivot={x=.5,y=.5};c.anchoredPosition={x=0,y=0};c.localScale=U.Vector3.one
            c.localRotation=U.Quaternion.identity;c.sibling=1;c.children={}
            setmetatable(c,{__index=function(s,k)
                if k=='rect'then return{width=s.sizeDelta.x,height=s.sizeDelta.y,xMin=-s.sizeDelta.x*s.pivot.x,
                    xMax=s.sizeDelta.x*(1-s.pivot.x),yMin=-s.sizeDelta.y*s.pivot.y,yMax=s.sizeDelta.y*(1-s.pivot.y)}end
                if k=='rotation'then return U.Quaternion.identity end
                if k=='childCount'then return #s.children end
                if k=='lossyScale'then local p=s.parent and s.parent.lossyScale or U.Vector3.one
                    return U.Vector3(p.x*s.localScale.x,p.y*s.localScale.y,1)end
            end})
            function c:SetParent(p)
                if self.parent then for i,r in ipairs(self.parent.children)do if r==self then table.remove(self.parent.children,i);break end end end
                self.parent=p;if p then p.children[#p.children+1]=self end
            end
            function c:TransformPoint(v)
                local p=U.Vector3(self.anchoredPosition.x+v.x*self.localScale.x,self.anchoredPosition.y+v.y*self.localScale.y,0)
                return self.parent and self.parent:TransformPoint(p)or p
            end
            function c:InverseTransformPoint(v)
                local p=self.parent and self.parent:InverseTransformPoint(v)or v
                return U.Vector3((p.x-self.anchoredPosition.x)/self.localScale.x,(p.y-self.anchoredPosition.y)/self.localScale.y,0)
            end
            function c:GetChild(i)return assert(self.children[i+1])end
            function c:GetSiblingIndex()
                if self.parent then for i,r in ipairs(self.parent.children)do if r==self then return i-1 end end end
                return self.sibling
            end
            function c:SetSiblingIndex(index)
                self.sibling=index
                if self.parent then local list=self.parent.children
                    for i,r in ipairs(list)do if r==self then table.remove(list,i);break end end
                    table.insert(list,math.max(1,math.min(index+1,#list+1)),self)
                end
            end
            function c:SetAsLastSibling()self:SetSiblingIndex(#self.parent.children-1)end
        elseif kind==U.UI.Button then c.onClick=event();c.colors={};c.navigation={}
        elseif kind==U.UI.Image or kind==U.UI.RawImage then
            c.rectTransform=self.components[U.RectTransform];c.enabled=true
            c.canvasRenderer={alpha=1,SetAlpha=function(s,a)s.alpha=a end}
            function c:SetAllDirty()self.dirtyCount=(self.dirtyCount or 0)+1 end
        elseif kind==CS.TMPro.TextMeshProUGUI then c.rectTransform=self.components[U.RectTransform]
        elseif kind==U.UI.LayoutGroup or kind==U.UI.ContentSizeFitter then c.enabled=true end
        self.components[kind]=c;return c
    end
    function obj:GetComponent(kind)return self.components[kind]end
    return obj
end
U.GameObject=go
local function destroy(obj)
    obj.destroyed=true
    local r=obj.components and obj.components[U.RectTransform]
    if r then local children={table.unpack(r.children)};for _,child in ipairs(children)do destroy(child.gameObject)end end
end
U.Object={Destroy=destroy,Instantiate=function(source,parent,world)
    assert(world==false and source.components,'clone only native presentation leaf')
    local copy=go(source.name..'Clone');copy.layer=source.layer
    local rt=copy:AddComponent(U.RectTransform);rt:SetParent(parent)
    for kind,component in pairs(source.components)do if kind~=U.RectTransform then
        local c=copy:AddComponent(kind)
        for k,v in pairs(component)do if k~='gameObject' and k~='rectTransform' and k~='canvasRenderer' then c[k]=v end end
        c.rectTransform=rt;c.clonedFrom=component
    end end
    copy.clonedFrom=source;return copy
end}
U.UI.Navigation={Mode={None=0}}
U.Time.frameCount=0
U.TextureFormat={RGBA32=1};U.TextureWrapMode={Clamp=1};U.FilterMode={Bilinear=1}
local textureCount=0
U.Texture2D=function(w,h,fmt,mip)
    assert(w>0 and h>0 and fmt==1 and mip==false);textureCount=textureCount+1
    local tex={pixels={},width=w,height=h,Equals=function(s)return s.destroyed==true end}
    function tex:SetPixel(x,y,c)assert(x<w and y<h);self.pixels[y*w+x+1]=c end
    function tex:Apply(mips,unreadable)assert(mips==false and unreadable==true);self.applied=true end
    return tex
end
local decodeCount,spriteCount=0,0
CS.System.Convert={FromBase64String=function(value)assert(value:sub(1,8)=='iVBORw0K');return value end}
U.ImageConversion={LoadImage=function(tex,data,unreadable)
    assert(#data>1000 and unreadable==true);tex.width=256;tex.height=256;decodeCount=decodeCount+1;return true
end}
U.Rect=function(x,y,w,h)return{x=x,y=y,width=w,height=h}end
U.SpriteMeshType={FullRect=0}
U.Sprite={Create=function(tex,r,pivot,ppu,extrude,mesh)
    assert(ppu==100 and mesh==0)
    if tex.name=='ZMLTeamMarkClip'then
        assert(r.width==tex.width and r.height==tex.height and r.x==0 and r.y==0)
    else spriteCount=spriteCount+1;assert(tex.width==256 and r.width==64 and r.height==64)end
    return {texture=tex,rect=r,Equals=function(s)return s.destroyed==true end}
end}
UIConst.UI_SPRITE_CHAR_PROFESSION='CharProfessionIcon'
UIConst.UI_SPRITE_MAP_MARK_ICON='Map/MarkIcon'
local elementHex={Physical='888888',Fire='FF623D',Pulse='FFC000',Cryst='21C6D0',Natural='9EDC23'}
Tables.charTypeTable={TryGetValue=function(_,key)return elementHex[key]~=nil,{color=elementHex[key]}end}
UIUtils.getColorByString=function(hex)
    assert(hex:match('^%x%x%x%x%x%x$'))
    return U.Color(tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255,1)
end
local iconIds={icon_profession_0=true,icon_profession_2=true,icon_profession_4=true,
    icon_profession_5=true,icon_profession_7=true,icon_profession_8=true}
local combatIcons={icon_map_dungeon=true,icon_map_enemyspawner=true,icon_map_high_difficulty=true,
    icon_map_boss=true,icon_map_mini_boss=true,icon_map_weekraid=true,icon_map_seasontower=true,
    icon_map_simulation_training=true,icon_map_dungeon_worldlevel=true}
local spriteLoads=0
local W=ZMLMoreTeams;local M=W.model
local host=go('NativePanel'):AddComponent(U.RectTransform);host.sizeDelta=U.Vector2(1200,800)
local row=go('OriginalRow'):AddComponent(U.RectTransform);row:SetParent(host);row.sizeDelta=U.Vector2(300,50)
local layout=row.gameObject:AddComponent(U.UI.LayoutGroup);local fitter=row.gameObject:AddComponent(U.UI.ContentSizeFitter)
local source={font={},fontSharedMaterial={},rectTransform=go('OriginalName'):AddComponent(U.RectTransform)}
local info=go('InfoNoe'):AddComponent(U.RectTransform);info:SetParent(host);info.transform=info
local infoLayout=info.gameObject:AddComponent(U.UI.LayoutGroup)
local infoFitter=info.gameObject:AddComponent(U.UI.ContentSizeFitter)
local line=go('NativeSeparator'):AddComponent(U.RectTransform);line:SetParent(info)
line.sizeDelta=U.Vector2(1000,1);line.anchoredPosition=U.Vector2(0,-10.5)
line.GetComponent=function(s,kind)return s.gameObject:GetComponent(kind)end
info.Find=function(_,path)assert(path=='RightLine/Line');return line end
local renameNode=go('ReNameNode'):AddComponent(U.RectTransform);renameNode:SetParent(info)
renameNode.sizeDelta=U.Vector2(125,60);renameNode.anchoredPosition=U.Vector2(0,5)
local rename=go('BtnRename'):AddComponent(U.RectTransform);rename:SetParent(renameNode)
-- Native child extends beyond its branch: top anchor plus -13.5 offset.
rename.sizeDelta=U.Vector2(125,60);rename.anchoredPosition=U.Vector2(0,16.5)
local nameNode=go('NativeNameNode'):AddComponent(U.RectTransform);nameNode:SetParent(info)
nameNode.sizeDelta=U.Vector2(200,40);nameNode.anchoredPosition=U.Vector2(150,5)
source.rectTransform:SetParent(nameNode)
source.rectTransform.sizeDelta=U.Vector2(200,40)
local infoOriginal={rename=renameNode.anchoredPosition,name=nameNode.anchoredPosition}
local function separated(st)
    local lineTop=host:InverseTransformPoint(line:TransformPoint(U.Vector3(0,line.rect.yMax,0))).y
    local lineBottom=host:InverseTransformPoint(line:TransformPoint(U.Vector3(0,line.rect.yMin,0))).y
    assert(st.root.anchoredPosition.y-st.root.sizeDelta.y*st.scale.y>=lineTop+8*st.scale.y-.001,
        'all twenty selectors above separator including scaled clearance')
    for _,r in ipairs({rename,source.rectTransform})do
        local top=host:InverseTransformPoint(r:TransformPoint(U.Vector3(0,r.rect.yMax,0))).y
        assert(top<=lineBottom-8*st.scale.y+.001,'actual edit hit area/name below separator, including child offset')
    end
end

local skin={sprite={nativeSprite=true},type=1,rectTransform={rect={width=180,height=48}}}
local originalButton={gameObject={GetComponentsInChildren=function()return{Length=1,[0]=skin}end}}
local cells,originals={},{}
for i=1,20 do
    local obj=go('OriginalTeam'..i);local rt=obj:AddComponent(U.RectTransform);rt:SetParent(row)
    rt.anchoredPosition=U.Vector2(25+(i-1)*56,-25);rt:SetSiblingIndex(i-1)
    local textParent=go('NativeNumberParent'..i):AddComponent(U.RectTransform);textParent:SetParent(rt)
    local label=go('NativeNumber'..i):AddComponent(U.RectTransform);label:SetParent(textParent)
    local pill=go('ImageTabSelect'..i):AddComponent(U.RectTransform);pill:SetParent(textParent)
    local shape=pill.gameObject:AddComponent(U.UI.Image);shape.sprite={nativeRoundedPill=true};shape.type=1
    shape.pixelsPerUnitMultiplier=1;shape.pixelsPerUnit=1;shape.enabled=false
    shape.sprite.border={x=25,y=25,z=25,w=25}
    -- Native TeamCell has a static sliced base beside the animated selected pill.
    local baseRect=go('ImageTab'..i):AddComponent(U.RectTransform);baseRect:SetParent(textParent)
    local base=baseRect.gameObject:AddComponent(U.UI.Image)
    base.sprite=shape.sprite;base.type=shape.type;base.pixelsPerUnitMultiplier=1;base.pixelsPerUnit=1
    local cell={gameObject=obj,view={textNum={rectTransform=label},imageTabSelect=shape},staticShape=base}
    function cell:LoadSprite(path,name)
        assert(path=='CharProfessionIcon' and iconIds[name]or path=='Map/MarkIcon'and combatIcons[name]);spriteLoads=spriteLoads+1
        if Mock.missingSprite==name then return nil end
        return {native=true,name=name}
    end
    function cell:InitTeamCell(data,fn)
        self.index=data.index;self.click=function()
            U.Time.frameCount=U.Time.frameCount+2
            local state=Mock.ctrl and W.controllers[Mock.ctrl]
            local pop=state and state.popup
            if pop then
                -- A safe area prevents auto-close, but does NOT lift native top-panel input gating.
                -- Dispatch via the popup canvas raycast proxy, never call the buried HGButton.
                local proxy=pop.selectors and pop.selectors[self.index]
                if proxy then proxy.button.onClick:Invoke()end
                return
            end
            fn()
        end;self.initCount=(self.initCount or 0)+1
    end
    function cell:SetSelect(v)self.selected=v;shape.enabled=v;shape.gameObject:SetActive(v)end
    -- An opaque selected branch OUTSIDE the label parent defeats local sibling raising.
    local late=go('LateNativeSelected'..i):AddComponent(U.RectTransform);late:SetParent(rt)
    local nativeSelect=cell.SetSelect
    function cell:SetSelect(v)
        nativeSelect(self,v);late.gameObject:SetActive(v);late:SetAsLastSibling()
    end
    cells[i]=cell;originals[i]={position=rt.anchoredPosition,scale=rt.localScale,pivot=rt.pivot}
end
U.UI.LayoutRebuilder={ForceRebuildLayoutImmediate=function(parent)
    if parent==info then return end
    local count=0;for _,r in ipairs(parent.children)do if r.gameObject.activeSelf then count=count+1 end end
    assert(count==5,'baseline measurement must use native five cells')
end}
local emptySprite={nativeEmptySet=true,Equals=function()return false end}
local emptyLoads=0
local loader={LoadSprite=function(_,path)
    assert(path=='assets/beyond/arts/ui/sprites/common/state/icon_empty.png');emptyLoads=emptyLoads+1;return emptySprite
end}
local ctrl={loader=loader,m_args={},m_customTeamIndex=-1,m_curTeamIndex=1,state=2,view={transform=host,textName=source,btnConfirm=originalButton,infoNoe=info,btnRename={gameObject=rename.gameObject}},
    m_teamCells={GetItem=function(_,i)return cells[i]end}}
Mock.ctrl=ctrl
setmetatable(ctrl,{__index=function(_,k)local v=CharFormationCtrl[k];if type(v)=='function'or type(v)=='number'then return v end end})
ctrl.SetState=function(s,v)s.state=v;W.stateChanged(s,v)end
ctrl.Notify=function(_,k,i)if k=='ON_CHAR_FORMATION_SELECT_TEAM_CHANGE'then Mock.selected=i end end
local paintQueue={}
ctrl._StartCoroutine=function(_,fn)paintQueue[#paintQueue+1]=coroutine.create(fn)end
coroutine.step=function()coroutine.yield()end
local function paintFrame()
    local current=paintQueue;paintQueue={}
    for _,thread in ipairs(current)do
        local ok,e=coroutine.resume(thread);assert(ok,e)
        if coroutine.status(thread)~='dead'then paintQueue[#paintQueue+1]=thread end
    end
end
local function settlePaint()paintFrame();paintFrame();assert(#paintQueue==0)end
-- Exercise the real current-client NaviTargetActionMenuCtrl, not a substitute popup.
local function nativeNode()return {gameObject=go('NativeMenuNode')}end
local menu={nativeCells={},uiCamera={}}
local menuContent=go('NativePopupContent'):AddComponent(U.RectTransform);menuContent:SetParent(host)
menuContent.sizeDelta=U.Vector2(457,252)
local originalSafeArea=go('PreviousNativeSafeArea'):AddComponent(U.RectTransform)
local autoClose={tmpSafeArea=originalSafeArea,onTriggerAutoClose=event()}
menu.view={contentAutoCloseArea=autoClose,closeMaskBtn={onClick=event()},closeMask={},content=menuContent,rectTransform=host,transform=host,
    config={CELL_HEIGHT=60},contentStateController={SetState=function(_,v)menu.widthState=v end},
    titleLeftNode=nativeNode(),titleRightNode=nativeNode()}
local function nativeCell()
    local cellGo=go('NativeBtnCell');cellGo:AddComponent(U.RectTransform):SetParent(menuContent)
    local c={gameObject=cellGo,layoutElement={},actionNode=nativeNode(),titleNode=nativeNode(),
        leftText=nativeNode(),rightText=nativeNode(),redDot=nativeNode()}
    c.titleNode.gameObject:AddComponent(U.RectTransform):SetParent(cellGo:GetComponent(U.RectTransform))
    c.titleLayout=c.titleNode.gameObject:AddComponent(U.UI.LayoutElement);c.titleLayout.preferredHeight=30
    local text=go('NativeTitleText'):AddComponent(U.RectTransform)
    text:SetParent(c.titleNode.gameObject:GetComponent(U.RectTransform))
    c.titleText=text.gameObject:AddComponent(CS.TMPro.TextMeshProUGUI)
    c.titleText.font={nativeMenuFont=true};c.titleText.fontSharedMaterial={nativeMenuMaterial=true}
    c.titleText.fontSize=18;c.titleText.alignment=2;c.titleText.color=U.Color(.7686,.7686,.7686,.502)
    c.titleText.characterSpacing=2;c.titleText.fontStyle=0
    local deco=go('NativeTitleDeco'):AddComponent(U.RectTransform)
    deco:SetParent(c.titleNode.gameObject:GetComponent(U.RectTransform));c.deco=deco
    c.actionNode.onClick=event();c.actionNode.onHoverChange=event()
    c.redDot.gameObject.SetActiveIfNecessary=c.redDot.gameObject.SetActive
    return c
end
menu.m_cells={GetItem=function(_,i)return menu.nativeCells[i]end,Refresh=function(_,n,fn)
    for i=1,n do menu.nativeCells[i]=menu.nativeCells[i]or nativeCell();fn(menu.nativeCells[i],i)end
end}
setmetatable(menu,{__index=function(_,k)local v=NaviTargetActionMenuCtrl[k];if type(v)=='function'then return v end end})
menu.SetNaviTarget=function(_,v)Mock.naviTarget=v end
menu.IsPlayingAnimationOut=function()return false end
menu.Hide=function(s)s:OnHide()end
menu.PlayAnimationOutAndHide=function(s)s:Hide()end
menu.PlayAnimationOutWithCallback=function(_,f)Mock.animation=f end
Mock.finishAnimation=function()local f=assert(Mock.animation);Mock.animation=nil;f()end
U.UI.LayoutRebuilder.ForceRebuildLayoutImmediate=function(parent)
    if parent==host or parent==info then return end
    if parent==menuContent then
        -- Actual prefab: BtnCell VerticalLayoutGroup derives its height from
        -- active TitleNode, NOT the inactive ActionNode view.layoutElement.
        for _,cell in ipairs(menu.nativeCells)do
            local title=cell.titleNode.gameObject:GetComponent(U.RectTransform)
            title.sizeDelta=U.Vector2(457,cell.titleLayout.preferredHeight)
            for _,child in ipairs(title.parent.children)do
                if child~=title and child.gameObject.activeSelf and not child.gameObject.destroyed then
                    child.sizeDelta=U.Vector2(457,0) -- catches incorrectly mounting a root under BtnCell
                end
            end
        end
        return
    end
    local count=0;for _,r in ipairs(parent.children)do if r.gameObject.activeSelf then count=count+1 end end
    assert(count==5,'baseline measurement must use native five cells')
end
LayoutRebuilder=U.UI.LayoutRebuilder
CS.Beyond.DeviceInfoManager.NotchPaddingInCanvas=function()return {x=0}end
UIConst.UI_TIPS_POS_TYPE={RightTop=1}
UIUtils.updateTipsPosition=function(content,target,rt,camera,pos,padding)
    assert(content==menuContent and target and rt==menu.view.rectTransform and pos==1 and padding.bottom==100);Mock.positioned=true
end
UIManager={AutoOpen=function(_,id)assert(id==2);return menu end,SetTopOrder=function(_,id)assert(id==2)end}
UIUtils.genCellCache=function()return menu.m_cells end
menu:OnCreate(nil) -- bind the actual native auto-close listeners
local previousNotify=Notify
Notify=function(k,args)
    if k==MessageConst.SHOW_NAVI_TARGET_ACTION_MENU then NaviTargetActionMenuCtrl.ShowNaviTargetActionMenu(args)
    elseif k==MessageConst.HIDE_NAVI_TARGET_ACTION_MENU then menu:HideNaviTargetActionMenu()
    else previousNotify(k,args)end
end
assert(W.ctrlEnabled(ctrl));W.mount(ctrl)
local st=W.controllers[ctrl];assert(st and #st.cells==20 and not st.pages and not st.meta and not st.popup)
-- Unity rebuilds the parent HorizontalLayoutGroup after mounting/showing and
-- on name changes. A one-off anchoredPosition write cannot beat that driver.
local function nativeInfoLayoutPass()
    if infoLayout.enabled then
        renameNode.anchoredPosition=U.Vector2(0,100)
        nameNode.anchoredPosition=U.Vector2(150,100)
    end
end
nativeInfoLayoutPass()
assert(not infoLayout.enabled and not infoFitter.enabled,'native InfoNoe layout must be frozen too')
separated(st)
local positions={}
for i,v in ipairs(st.cells)do
    assert(v.rect.parent==st.root and cells[i].index==i)
    local pos=v.rect.anchoredPosition;assert(pos.x==(i-1)%5*56 and pos.y==-math.floor((i-1)/5)*56)
    local key=pos.x..':'..pos.y;assert(not positions[key]);positions[key]=true
end
assert(st.root.sizeDelta.x==274 and st.root.sizeDelta.y==218 and not layout.enabled and not fitter.enabled)
separated(st);assert(st.root.anchoredPosition.y==216,'grid moves above actual native line')
local movedName=nameNode.anchoredPosition;local movedRename=renameNode.anchoredPosition
local tex=st.gradient;assert(textureCount==3 and tex.applied and #tex.pixels==10000)
assert(decodeCount==1 and spriteCount==15)
assert(W.fillAlpha(0,25,50,50,25)==0 and W.fillAlpha(0,0,50,50,25)==0)
assert(W.fillAlpha(10,25,132,38,19)==.5 and W.fillAlpha(74,19,132,38,19)==0)
for x=2,70 do assert(W.fillAlpha(x,19,132,38,19)<=W.fillAlpha(x-1,19,132,38,19)or x<=20)end
local badge=st.badges[cells[20]];local bg=badge:GetChild(0)
local raw=bg.gameObject:GetComponent(U.UI.RawImage)
assert(bg.sizeDelta.x==50 and bg.sizeDelta.y==50 and raw.texture==tex and raw.raycastTarget==false)
assert(not badge.gameObject:GetComponent(U.UI.Mask)and not badge.gameObject:GetComponent(U.UI.Image),'no binary stencil fringe')
local nr=cells[20].view.textNum.rectTransform
local shape=cells[20].view.imageTabSelect
assert(badge.parent==st.root and badge:GetSiblingIndex()>st.cells[20].rect:GetSiblingIndex(),'badge outside native subtree, above all branches')
for _,v in ipairs(st.cells)do assert(badge:GetSiblingIndex()>v.rect:GetSiblingIndex())end
assert(nr:GetSiblingIndex()==0,'native label order untouched')
assert(raw.color.a==0,'default has no fill')
local colorIds={8,2,4,5,7};local types={'Physical','Fire','Pulse','Cryst','Natural'}
for j,id in ipairs(colorIds)do
    assert(M.edit(20,{color=id}));W.refresh(ctrl);local expected=UIUtils.getColorByString(elementHex[types[j]])
    assert(raw.color.r==expected.r and raw.color.g==expected.g and raw.color.b==expected.b,'exact native element RGB')
end
elementHex.Fire='112233';assert(M.edit(20,{color=2}));W.refresh(ctrl)
assert(raw.color.r==17/255 and raw.color.g==34/255,'read native table rather than a guessed palette');elementHex.Fire='FF623D'
local clipRect=badge:GetChild(1)
local clipImage=clipRect.gameObject:GetComponent(U.UI.Image)
local clipMask=clipRect.gameObject:GetComponent(U.UI.Mask)
local icon=clipRect:GetChild(0).gameObject:GetComponent(U.UI.Image)
assert(clipMask.showMaskGraphic==false and clipMask.enabled and not clipImage.raycastTarget,
    'invisible non-interactive rounded stencil, independent of native UIImage')
assert(clipImage.sprite.texture.name=='ZMLTeamMarkClip')
local clipTex=clipImage.sprite.texture
assert(clipTex.pixels[1].a==0 and clipTex.pixels[50*100+50].a==1,
    'clip is rounded with opaque interior, not the color fade or a rectangle')
assert(not icon.gameObject.activeSelf,'none has no placeholder drawn symbol')
assert(not clipRect.gameObject.activeSelf and icon.maskable,'none disables the whole stencil branch')
for mark=2,16 do
    assert(M.edit(20,{mark=mark}));W.refresh(ctrl)
    assert(icon.sprite==st.sprites[mark] and icon.sprite.texture==st.markTexture and icon.gameObject.activeSelf and icon.preserveAspect and icon.raycastTarget==false)
    assert(clipRect.gameObject.activeSelf and clipMask.enabled and icon.maskable)
    local ir=icon.rectTransform
    assert(ir.anchoredPosition.x+ir.sizeDelta.x/2==10 and ir.anchoredPosition.y-ir.sizeDelta.y/2==-25,'oversized watermark centered on the left side')
end
assert(spriteLoads==0);W.refresh(ctrl);assert(textureCount==3 and decodeCount==1 and spriteCount==15 and st.badges[cells[20]]==badge,'no game sprite loads, refresh allocations or duplicate atlas loads')
assert(M.edit(20,{mark=1}));W.refresh(ctrl);assert(not icon.gameObject.activeSelf)
-- Map from a non-default native cell subtree pivot and scale without moving the label.
local nr=cells[20].view.textNum.rectTransform;local np=nr.parent
np.pivot=U.Vector2(.25,.75);np.anchoredPosition=U.Vector2(9,-3);np.localScale=U.Vector3(.8,.9,1)
W.refresh(ctrl)
local cr=cells[20].staticShape.rectTransform
cr.sizeDelta=U.Vector2(132,38);cr.anchoredPosition=U.Vector2(-.5,0)
cells[20].view.imageTabSelect.rectTransform.sizeDelta=cr.sizeDelta
cells[20].view.imageTabSelect.rectTransform.anchoredPosition=cr.anchoredPosition
W.refresh(ctrl)
local expected=cr:TransformPoint(U.Vector3(cr.rect.xMin,cr.rect.yMax,0))
local actualBadge=badge:TransformPoint(U.Vector3(0,0,0))
assert(math.abs(expected.x-actualBadge.x)<.001 and math.abs(expected.y-actualBadge.y)<.001,'actual native pill independent of click rect and label parent pivot')
assert(badge.sizeDelta.x==132 and badge.sizeDelta.y==38 and raw.rectTransform.sizeDelta.y==38)
assert(raw.rectTransform.sizeDelta.x==132 and raw.texture.width==264 and raw.texture.height==76,'full native geometry with transparent antialiased edge')
assert(icon.color.r==.92 and icon.color.a==.4,'unselected watermark has light translucent contrast')
assert(clipRect.sizeDelta.x==132 and clipRect.sizeDelta.y==38,
    'clip follows the static pill, not the 130x60 click area')
local ir=icon.rectTransform
assert(ir.sizeDelta.x==68.4 and ir.sizeDelta.y==68.4 and ir.anchoredPosition.y>0
    and ir.anchoredPosition.y-ir.sizeDelta.y < -38,
    'mark exceeds the pill at both top and bottom and must be clipped')
assert(ir.anchoredPosition.x+ir.sizeDelta.x < 132*.5,
    'watermark stays clear of the native centered number')
assert(clipImage.sprite.texture.width==264 and clipImage.sprite.texture.height==76)
for _,clip in pairs(st.clips)do
    local ct=clip.texture
    assert(ct.pixels[1].a==0 and ct.pixels[ct.width].a==0
        and ct.pixels[(ct.height-1)*ct.width+1].a==0 and ct.pixels[ct.width*ct.height].a==0,
        'all four corners clip the enlarged mark')
end

assert(M.edit(20,{mark=8}));W.refresh(ctrl)
assert(cells[20].initCount==1,'cosmetic refresh must not reinitialize native selectors/reset selection/listeners')
cells[20].click();assert(icon.color.r==49/255 and icon.color.a==.32,'selected watermark uses translucent #313131 on the white native button');
assert(icon.gameObject.activeSelf and icon.sprite==st.sprites[8],'selected icon must actually render, not only store a color on a hidden object')
assert(raw.color.a==1 and raw.gameObject.activeSelf and badge.parent==st.root,'selection cannot hide/recolor cosmetics with a native branch');
for _,v in ipairs(st.cells)do assert(badge:GetSiblingIndex()>v.rect:GetSiblingIndex())end
for j,id in ipairs(colorIds)do
    assert(M.edit(20,{color=id}));W.refresh(ctrl)
    local c=UIUtils.getColorByString(elementHex[types[j]])
    assert(raw.color.r==c.r and raw.color.g==c.g and raw.color.b==c.b and raw.color.a==1,'every selected element retains exact tint')
end
for mark=2,16 do
    assert(M.edit(20,{mark=mark}));W.refresh(ctrl)
    assert(icon.gameObject.activeSelf and icon.sprite==st.sprites[mark]and icon.color.r==49/255 and icon.color.a==.32)
end
-- Native changes after refresh still cannot cover the detached cosmetic branch.
cells[20]:SetSelect(true)
assert(badge:GetSiblingIndex()>st.cells[20].rect:GetSiblingIndex()and icon.color.r==49/255)
cells[19].click();assert(icon.color.r==.92 and raw.color.a==1,'deselection restores light icon without removing element color')
cells[20].click();assert(icon.color.r==49/255 and raw.color.a==1)
-- Actual extracted teamtabselect in/out clips animate SizeDelta.x 132 <-> 8.3446.
-- Select another team, finish out, then return while in starts at its thin width.
-- One-frame repaint still happens before the .4167s expansion finishes.
cells[19].click();settlePaint()
local selectedRect=cells[20].view.imageTabSelect.rectTransform
selectedRect.sizeDelta=U.Vector2(8.3446,38)
cells[20].click();settlePaint()
assert(badge.sizeDelta.x==132 and raw.rectTransform.sizeDelta.x==132,
    'return selection must not freeze the native animation start width into cosmetics')
assert(math.abs(icon.rectTransform.sizeDelta.x-68.4)<.001,'oversized mark must use stable pill height, not animated width')
local stableTexture=raw.texture;local stableCount=textureCount
for _,width in ipairs({8.3446,17,65,110,132,8.3446})do
    selectedRect.sizeDelta=U.Vector2(width,38);W.paint(ctrl)
    assert(badge.sizeDelta.x==132 and raw.texture==stableTexture and textureCount==stableCount,
        'native animation frames must neither resize cosmetics nor allocate gradient textures')
end
selectedRect.sizeDelta=U.Vector2(132,38)
local allocated=textureCount;W.refresh(ctrl);W.refresh(ctrl);assert(textureCount==allocated,'mixed geometry textures cached, no thrashing');assert(ctrl.m_curTeamIndex==20 and Mock.selected==20 and cells[20].selected and not st.popup,'first click selects without popup')
cells[20].click();local pop=st.popup;assert(pop and pop.index==20 and not pop.section)
settlePaint()
assert(raw.color.a==1 and raw.enabled and raw.gameObject.activeSelf and raw.canvasRenderer.alpha==1)
-- Stress the post-click rendering path independently of logical color storage.
-- Emulate a renderer fade/hidden cosmetic after native pointer handlers; the
-- existing mocks only checked Graphic.color, which cannot prove a visible mesh.
for pass=1,3 do for i=1,20 do
    assert(M.edit(i,{color=colorIds[(i-1)%#colorIds+1],mark=8}))
    W.refresh(ctrl)
    if ctrl.m_curTeamIndex~=i then cells[i].click()end
    settlePaint()
    local b=st.badges[cells[i]]
    local fill=b:GetChild(0).gameObject:GetComponent(U.UI.RawImage)
    local mark=b:GetChild(1):GetChild(0).gameObject:GetComponent(U.UI.Image)
    local texture=fill.texture;local dirty=fill.dirtyCount
    cells[i].click();assert(st.popup and st.popup.index==i,'popup input must allow selecting another team, then opening its picker')
    fill.canvasRenderer.alpha=0;fill.enabled=false;fill.gameObject:SetActive(false)
    mark.canvasRenderer.alpha=0;mark.enabled=false
    local maskNode=b:GetChild(1);maskNode.gameObject:SetActive(false)
    maskNode.gameObject:GetComponent(U.UI.Mask).enabled=false
    settlePaint()
    assert(fill.color.a==1 and fill.enabled and fill.gameObject.activeSelf and fill.canvasRenderer.alpha==1)
    assert(fill.texture==texture and fill.dirtyCount>dirty,'same cached texture/tint must rebuild visible mesh on repeat click')
    assert(mark.enabled and mark.gameObject.activeSelf and mark.canvasRenderer.alpha==1 and mark.color.r==49/255)
    assert(maskNode.gameObject.activeSelf and maskNode.gameObject:GetComponent(U.UI.Mask).enabled)
    assert(cells[i].initCount==1,'repeated clicks must not replace native bindings')
    cells[i].click();assert(not st.popup,'lower-panel blocked team click must toggle popup via top-panel proxy');settlePaint()
end end
cells[20].click();assert(st.popup and st.popup.index==20)
local pop=st.popup
assert(menu.m_args.transform==st.cells[20].rect and #menu.m_args.actions==2 and menu.widthState=='ContentWidth457')
assert(not menu.view.closeMask.enabled and Mock.positioned,'native auto-close retained, team clicks not intercepted by full-screen mask')
assert(autoClose.tmpSafeArea==st.root,'team grid must be a native auto-close safe area')
assert(pop.inputRoot.parent==menu.view.rectTransform and #pop.selectors==20)
assert(pop.inputRoot:GetSiblingIndex()<menuContent:GetSiblingIndex(),'menu content wins overlapping raycasts')
for i,v in ipairs(pop.selectors)do
    assert(v.graphic.color.a==0 and v.graphic.raycastTarget and v.button.transition==0 and v.button.navigation.mode==0,
        'invisible pointer-only proxy, no new visual or keyboard target')
    local actual=v.rect:TransformPoint(U.Vector3(v.rect.rect.xMin,v.rect.rect.yMax,0))
    local target=st.cells[i].rect
    local expected=target:TransformPoint(U.Vector3(target.rect.xMin,target.rect.yMax,0))
    assert(math.abs(actual.x-expected.x)<.001 and math.abs(actual.y-expected.y)<.001,'match actual native click rect on popup canvas')
    assert(v.rect.rect.width==target.rect.width and v.rect.rect.height==target.rect.height)
end
local staleSelector=pop.selectors[1].button.onClick
local function choice(pop,kind,id)
    for _,v in ipairs(pop.choices)do if v.kind==kind and v.id==id then return v end end
    error('missing direct choice '..kind..id)
end
assert(#st.popup.choices==22 and st.popup.root.sizeDelta.y==208,'six colors and all sixteen marks in one compact panel')
assert(menu.nativeCells[2].titleLayout.preferredHeight==216 and menu.nativeCells[2].titleNode.gameObject.activeSelf)
assert(pop.root.parent==menu.nativeCells[2].titleNode.gameObject:GetComponent(U.RectTransform)
    and not menu.nativeCells[2].deco.gameObject.activeSelf,'title subtree is a stable container, native decorations hidden')
local originalFont=menu.nativeCells[2].titleText.font;local originalMaterial=menu.nativeCells[2].titleText.fontSharedMaterial
assert(pop.root:GetChild(0).gameObject:GetComponent(CS.TMPro.TextMeshProUGUI).font==originalFont
    and pop.root:GetChild(0).gameObject:GetComponent(CS.TMPro.TextMeshProUGUI).fontSharedMaterial==originalMaterial)
for _,v in ipairs(pop.choices)do
    local rt=v.button.gameObject:GetComponent(U.RectTransform)
    assert(rt.anchoredPosition.x>=0 and rt.anchoredPosition.x+rt.sizeDelta.x<=425)
    assert(-rt.anchoredPosition.y+rt.sizeDelta.y<=208,'every tile fits without scroll or submenu')
    assert(v.border.raycastTarget and not v.fill.raycastTarget and v.button.transition==1)
    assert(v.button.colors.fadeDuration==.1 and v.button.colors.highlightedColor.r>1,'native-like hover/press feedback')
    assert(v.border.clonedFrom==cells[20].staticShape and v.fill.clonedFrom==cells[20].staticShape,
        'native UIImage leaves cloned with original sliced sprite/type/atlas state')
    assert(v.border.type==cells[20].staticShape.type and v.border.sprite==cells[20].staticShape.sprite)
    if v.kind=='mark' and v.id>1 then
        local icon=v.icon
        assert(icon.sprite==st.sprites[v.id] and not icon.raycastTarget and icon.rectTransform.sizeDelta.x==32)
    end
end
local heading=pop.root:GetChild(0).gameObject:GetComponent(CS.TMPro.TextMeshProUGUI)
assert(heading.clonedFrom==menu.nativeCells[2].titleText and heading.alignment==2
    and heading.color.a==.502 and heading.fontSize==18 and heading.characterSpacing==2,
    'native popup title typography/color/alignment retained, not team-name centered white labels')
for _,kind in ipairs({'color','mark'})do
    local v=choice(pop,kind,1)
    assert(v.icon.sprite==emptySprite and v.icon.rectTransform.sizeDelta.x==24
        and not v.icon.raycastTarget,'native empty-set icon, not text or checker placeholder')
end
local popupRoot=pop.root
for _,id in ipairs({1,8,2,4,5,7})do
    choice(pop,'color',id).button.onClick:Invoke()
    assert(M.get(20).color==id and st.popup==pop and menu.m_args==pop.args and not Mock.animation,
        'color click applies in place without closing or animation/submenu')
    assert(choice(pop,'color',id).selected and choice(pop,'color',id).border.color.r==.92)
end
for id=1,16 do
    choice(pop,'mark',id).button.onClick:Invoke()
    assert(M.get(20).mark==id and st.popup==pop and menu.m_args==pop.args)
    for _,v in ipairs(pop.choices)do if v.kind=='mark'then
        assert(v.border.color.r==(v.id==id and .92 or .19),'exactly one mark uses white selected native background')
        assert(v.selected==(v.id==id) and v.icon.color.r==(v.id==id and 49/255 or .92),'selected icon stays legible')
    end end
end
assert(M.edit(20,{color=3}));W.refresh(ctrl)
assert(choice(pop,'color',2).selected,'old fire alias highlights current native color')
local old=M.get(20).color;Mock.failWrite=true;choice(pop,'color',7).button.onClick:Invoke()
assert(M.get(20).color==old and st.popup==pop,'failed write preserves stored value and open picker');Mock.failWrite=false
assert(#Mock.sends==0,'cosmetics and selection stay local')
local pickerTextureCount=textureCount
local staleChoice=choice(pop,'color',4).button.onClick
cells[20].click();assert(not st.popup and not menu.m_args and popupRoot.gameObject.destroyed)
assert(menu.nativeCells[2].titleLayout.preferredHeight==30 and menu.nativeCells[2].deco.gameObject.activeSelf,
    'restore native title height and decorations before cache reuse')
cells[20].click();assert(emptyLoads==1,'reuse controller-loader-owned empty sprite');assert(textureCount==pickerTextureCount,'reuse rounded picker sprites on reopen, no per-click resources')
cells[9].click();assert(ctrl.m_curTeamIndex==9 and not st.popup and not menu.m_args)
cells[9].click();assert(st.popup.index==9);local outsideRoot=st.popup.root
menu:HideNaviTargetActionMenu();assert(not st.popup and outsideRoot.gameObject.destroyed,'native outside dismiss cleans owned widgets')
cells[9].click();ctrl:_SetTeamSelect(9);assert(not st.popup,'programmatic initialization cannot open a popup')
-- Native auto-close runs on pointer-down, click on release can be MANY frames later.
-- Only the team grid is exempt: outside dismiss remains the real native listener.
for _,heldFrames in ipairs({0,2,30,180})do
    cells[9].click();local closing=assert(st.popup)
    assert(autoClose.tmpSafeArea==st.root)
    -- Model native ShouldClose's fixed content + tmpSafeArea containment decision.
    if autoClose.tmpSafeArea~=st.root then autoClose.onTriggerAutoClose:Invoke()end
    U.Time.frameCount=U.Time.frameCount+heldFrames
    cells[9].click()
    assert(not st.popup and not menu.m_args,'same team release must close, not reopen after arbitrary hold')
    assert(closing.root.gameObject.destroyed and autoClose.tmpSafeArea==originalSafeArea,
        'close destroys owned content and restores the previous native safe area')
    assert(closing.inputRoot.gameObject.destroyed,'all owned selector proxies destroyed on toggle')
end
cells[9].click();local outside=assert(st.popup)
autoClose.onTriggerAutoClose:Invoke()
assert(not st.popup and outside.disposed and autoClose.tmpSafeArea==originalSafeArea,'outside listener still closes')
cells[9].click();assert(st.popup,'next intentional click opens without frame-based suppression')
cells[1].click();assert(ctrl.m_curTeamIndex==1 and not st.popup and autoClose.tmpSafeArea==originalSafeArea,
    'other team selects and closes normally')
cells[9].click()

-- Different popup canvas pivot/translation/scale must not shift selector hit targets.
local separateCanvas=go('SeparatePopupCanvas'):AddComponent(U.RectTransform)
separateCanvas:SetParent(host);separateCanvas.pivot=U.Vector2(.25,.75)
separateCanvas.sizeDelta=U.Vector2(1600,1000);separateCanvas.anchoredPosition=U.Vector2(37,-22)
separateCanvas.localScale=U.Vector3(.8,1.2,1)
menu.view.rectTransform=separateCanvas;menu.view.transform=separateCanvas;menuContent:SetParent(separateCanvas)
for i=1,20 do
    cells[i].click();if not st.popup then cells[i].click()end
    local open=assert(st.popup)
    for j,proxy in ipairs(open.selectors)do
        local target=st.cells[j].rect
        for _,corner in ipairs({{'xMin','yMax'},{'xMax','yMin'}})do
            local expected=target:TransformPoint(U.Vector3(target.rect[corner[1]],target.rect[corner[2]],0))
            local actual=proxy.rect:TransformPoint(U.Vector3(proxy.rect.rect[corner[1]],proxy.rect.rect[corner[2]],0))
            assert(math.abs(expected.x-actual.x)<.001 and math.abs(expected.y-actual.y)<.001,'scaled canvas exact click corners')
        end
    end
    cells[i].click();assert(not st.popup and open.inputRoot.gameObject.destroyed,'every team proxy toggles closed')
end
menu.view.rectTransform=host;menu.view.transform=host;menuContent:SetParent(host)
cells[9].click()

-- Old tile listeners must not write after close/reopen/selection changes, even if selected again.
cells[20].click();cells[20].click();local before=M.get(20).color
local selectedBeforeStale=ctrl.m_curTeamIndex;staleSelector:Invoke();assert(ctrl.m_curTeamIndex==selectedBeforeStale,'old selector cannot switch current team')
staleChoice:Invoke();assert(M.get(20).color==before and st.popup,'stale tile cannot edit a reopened popup')
cells[9].click();assert(not st.popup)
cells[9].click();local replaced=st.popup;local oldValue=M.get(9).color
local otherArgs={actions={{text='无关菜单'},{text='其他项目'}},cellHeight=60,useSmallContent=true}
Notify(MessageConst.SHOW_NAVI_TARGET_ACTION_MENU,otherArgs)
choice(replaced,'color',7).button.onClick:Invoke();assert(M.get(9).color==oldValue)
local beforeOtherOwner=ctrl.m_curTeamIndex;replaced.selectors[1].button.onClick:Invoke();assert(ctrl.m_curTeamIndex==beforeOtherOwner,'replaced owner proxy cannot select')
W.hidePopup(ctrl);assert(autoClose.tmpSafeArea==originalSafeArea,'restore owned safe area after popup replacement');assert(menu.m_args==otherArgs and replaced.root.gameObject.destroyed,'do not close another owner popup')
assert(menu.nativeCells[2].layoutElement.preferredHeight==60 and menu.nativeCells[2].titleLayout.preferredHeight==30
    and menu.nativeCells[2].titleNode.gameObject.activeSelf,
    'cleanup cannot change a reused native cell belonging to another popup')
menu:HideNaviTargetActionMenu()
-- Do not overwrite a newer owner's safe-area assignment.
cells[9].click();assert(st.popup);local newerSafeArea=go('OtherOwnerSafeArea'):AddComponent(U.RectTransform)
autoClose.tmpSafeArea=newerSafeArea;W.hidePopup(ctrl)
assert(autoClose.tmpSafeArea==newerSafeArea,'cleanup preserves newer owner safe area')
autoClose.tmpSafeArea=originalSafeArea
ctrl:_SetTeamSelect(ctrl:_WrapTeamIndex(21));assert(ctrl.m_curTeamIndex==1 and cells[1].selected)
W.mount(ctrl);assert(st==W.controllers[ctrl]and #st.cells==20,'no duplicate mount')
assert(nameNode.anchoredPosition==movedName and renameNode.anchoredPosition==movedRename,'no repeated downward drift');separated(st)
cells[1].click();assert(st.popup.index==1);choice(st.popup,'color',2).button.onClick:Invoke();assert(M.get(1).color==2 and #Mock.sends==0,'first four cosmetics are local too')
ctrl:SetState(UIConst.UI_CHAR_FORMATION_STATE.SingleChar);assert(not st.root.gameObject.activeSelf and not st.popup,'hide during character editing')
ctrl:SetState(UIConst.UI_CHAR_FORMATION_STATE.TeamWaitSet);assert(st.root.gameObject.activeSelf)
assert(M.edit(9,{slots={{id='103',skill='c'}}}));cells[9].click();cells[9].click();assert(st.popup)
assert(M.begin(9));assert(not st.popup);local selected=ctrl.m_curTeamIndex
cells[1].click();cells[9].click();assert(ctrl.m_curTeamIndex==selected and not st.popup,'busy guard')
M.cancel();W.close(ctrl);assert(st.root.gameObject.destroyed and st.gradient.destroyed and not W.controllers[ctrl])
settlePaint() -- queued callbacks must not touch destroyed textures/nodes after close
for i,cell in ipairs(cells)do
    local r=cell.gameObject:GetComponent(U.RectTransform)
    assert(not cell.gameObject.destroyed and r.parent==row and r:GetSiblingIndex()==i-1,'cached originals returned before grid destruction')
    assert(r.anchoredPosition==originals[i].position and r.localScale==originals[i].scale and r.pivot==originals[i].pivot)
end
assert(layout.enabled and fitter.enabled,'native row layout restored')
assert(infoLayout.enabled and infoFitter.enabled,'native information layout restored')
assert(nameNode.anchoredPosition==infoOriginal.name and renameNode.anchoredPosition==infoOriginal.rename,'native information position restored exactly')
assert(not nameNode.gameObject.destroyed and not renameNode.gameObject.destroyed and rename.parent==renameNode,'native edit controls retained')
for _,cell in ipairs(cells)do assert(cell.view.textNum.rectTransform:GetSiblingIndex()==0,'original native label ordering restored')end
for _,t in pairs(st.fills)do assert(t.destroyed)end
for _,sprite in pairs(st.sprites)do assert(sprite.destroyed)end
for _,clip in pairs(st.clips)do assert(clip.sprite.destroyed and clip.texture.destroyed)end
assert(st.markTexture.destroyed,'own atlas and all sprites disposed')
-- Scaled canvas and selector transforms preserve line-based separation.
host.localScale=U.Vector3(1.4,1.4,1);row.localScale=U.Vector3(.9,.9,1)
for _,cell in ipairs(cells)do cell.gameObject:GetComponent(U.RectTransform).localScale=U.Vector3(.8,.8,1)end
local first=cells[1].gameObject:GetComponent(U.RectTransform)
local corner=first:TransformPoint(U.Vector3(first.rect.xMin,first.rect.yMax,0))
W.mount(ctrl);st=W.controllers[ctrl];local actual=st.root:TransformPoint(U.Vector3(0,0,0))
nativeInfoLayoutPass()
assert(math.abs(actual.x-corner.x)<.001,'native horizontal alignment preserved');separated(st)
assert(math.abs(st.scale.x-.72)<.001)
cells[9].click();assert(st.popup and menu.m_args.transform==st.cells[9].rect)
W.close(ctrl)
assert(infoLayout.enabled and infoFitter.enabled,'scaled close restores information layout')
assert(nameNode.anchoredPosition==infoOriginal.name and renameNode.anchoredPosition==infoOriginal.rename)
-- Closing disposes the compact picker and invalidates captured tile callbacks.
W.mount(ctrl);st=W.controllers[ctrl];cells[9].click();local closed=st.popup
local pendingChoice=choice(closed,'color',2).button.onClick;local before=M.get(9).color
W.close(ctrl);pendingChoice:Invoke()
assert(not st.popup and not W.controllers[ctrl] and closed.root.gameObject.destroyed and M.get(9).color==before)
assert(not emptySprite.destroyed,'native empty-set sprite belongs to controller loader, not our texture disposal')
-- Reopening and restricted-mode fallback must preserve the five-cell cache and remove the grid.
W.mount(ctrl);ctrl.m_args={lockedTeamData={}};W.mount(ctrl);assert(not W.controllers[ctrl])
assert(nameNode.anchoredPosition==infoOriginal.name and renameNode.anchoredPosition==infoOriginal.rename,'restricted fallback restores native information')
for _,cell in ipairs(cells)do assert(not cell.gameObject.destroyed)end
print('PASS detached foreground beyond native selected branches; all selected element tints; oversized translucent left watermarks and own rounded stencils; image-generated shared atlas; geometry caching/disposal; upward native 4x5 grid; native friend popup shell/mask/position; compact native title/pill clones and loader-owned empty-set icons; toggle and auto-close dispatch guard; in-place highlights and local writes; stale callback/cache cleanup guards; complete native restoration')
