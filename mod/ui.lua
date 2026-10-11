do
    local W=_G.ZMLMoreTeams
    if not W.uiReady then
        W.uiReady=true
        local U=CS.UnityEngine
        local palette={{'默认'},{'灼热','Fire','FF623D'},{'灼热','Fire','FF623D'},
            {'电磁','Pulse','FFC000'},{'寒冷','Cryst','21C6D0'},{'寒冷','Cryst','21C6D0'},
            {'自然','Natural','9EDC23'},{'物理','Physical','888888'}}
        local colorChoices={1,8,2,4,5,7}
        local marks={'无','近卫','重装','辅助','术师','先锋','突击','协议空间','能量淤积点',
            '影拓丰碑','危境再现','危境碎片','蚀像寻遗','战争回响','演武平台','协议空间·探索等级'}
        local function elementColor(p)
            if not p[2]then return U.Color(1,1,1,0)end
            local hex=p[3]
            local ok,t=Tables.charTypeTable:TryGetValue(p[2])
            if ok then hex=t.color end
            return UIUtils.getColorByString(hex)
        end
        local function live(x)return x~=nil and not x:Equals(nil)end
        local function rect(parent,name,x,y,w,h)
            local go=U.GameObject(name);go.layer=parent.gameObject.layer
            local r=go:AddComponent(typeof(U.RectTransform));r:SetParent(parent,false)
            r.anchorMin=U.Vector2(0,1);r.anchorMax=U.Vector2(0,1);r.pivot=U.Vector2(0,1)
            r.anchoredPosition=U.Vector2(x,-y);r.sizeDelta=U.Vector2(w,h);r.localScale=U.Vector3.one;return r
        end
        function W.pillCoverage(x,y,w,h,radius)
            local inset=1
            local r=math.max(0,radius-inset)
            local qx=math.abs(x-w*.5)-(w*.5-inset-r)
            local qy=math.abs(y-h*.5)-(h*.5-inset-r)
            local d=math.sqrt(math.max(qx,0)^2+math.max(qy,0)^2)+math.min(math.max(qx,qy),0)-r
            return math.max(0,math.min(1,.5-d))
        end
        function W.fillAlpha(x,y,w,h,radius)
            local t=math.max(0,math.min(1,(x/w-.55*.35)/(.55*.65)))
            return .5*(1-t*t*(3-2*t))*W.pillCoverage(x,y,w,h,radius)
        end
        local function geometry(shape)
            local sz=shape.rectTransform.rect
            local border=shape.sprite and shape.sprite.border
            local radius=sz.height*.5
            if border then
                local edge=math.max(border.x,border.y,border.z,border.w)
                if edge>0 then radius=math.min(radius,edge/math.max(.01,shape.pixelsPerUnit*shape.pixelsPerUnitMultiplier))end
            end
            return sz.width,sz.height,radius
        end
        local function stableShape(cell)
            local selected=cell.view.imageTabSelect
            local parent=selected.rectTransform.parent
            for i=0,parent.childCount-1 do
                local child=parent:GetChild(i)
                if child~=selected.rectTransform then
                    local image=child.gameObject:GetComponent(typeof(U.UI.Image))
                    if image and image.sprite==selected.sprite and image.type==selected.type
                        and math.abs(child.rect.height-selected.rectTransform.rect.height)<.01
                        and child.rect.width>=child.rect.height then return image end
                end
            end
            error('Stable native team background unavailable')
        end
        local function gradient(w,h,r,clip)
            local tw,th=math.ceil(w*2),math.ceil(h*2)
            local tex=U.Texture2D(tw,th,U.TextureFormat.RGBA32,false)
            tex.name=clip and 'ZMLTeamMarkClip'or 'ZMLTeamColorGradient'
            tex.wrapMode=U.TextureWrapMode.Clamp;tex.filterMode=U.FilterMode.Bilinear
            for y=0,th-1 do for x=0,tw-1 do
                local px,py=(x+.5)*w/tw,(y+.5)*h/th
                local a=clip and W.pillCoverage(px,py,w,h,r)or W.fillAlpha(px,py,w,h,r)
                tex:SetPixel(x,y,U.Color(1,1,1,a))
            end end
            tex:Apply(false,true);return tex
        end
        local function markClip(w,h,r)
            local tex=gradient(w,h,r,true)
            local ok,sprite=pcall(U.Sprite.Create,tex,U.Rect(0,0,tex.width,tex.height),
                U.Vector2(.5,.5),100,0,U.SpriteMeshType.FullRect)
            if not ok then U.Object.Destroy(tex);error(sprite)end
            return {texture=tex,sprite=sprite}
        end
        local function snapshot(r)
            return {rect=r,parent=r.parent,sibling=r:GetSiblingIndex(),anchorMin=r.anchorMin,anchorMax=r.anchorMax,
                pivot=r.pivot,position=r.anchoredPosition,size=r.sizeDelta,scale=r.localScale,rotation=r.localRotation}
        end
        local function restore(v,host)
            local r=v.rect;if not live(r)then return end
            local parent=live(v.parent)and v.parent or host
            if not live(parent)then return end
            r:SetParent(parent,false);r.anchorMin=v.anchorMin;r.anchorMax=v.anchorMax;r.pivot=v.pivot
            r.anchoredPosition=v.position;r.sizeDelta=v.size;r.localScale=v.scale;r.localRotation=v.rotation
            r:SetSiblingIndex(v.sibling)
        end
        local function teamLayout(s,host)
            local info=s.view.infoNoe.transform
            local line=assert(info:Find('RightLine/Line'),'Native team separator unavailable')
                :GetComponent(typeof(U.RectTransform))
            local function branch(r)
                while r.parent~=info do
                    r=assert(r.parent,'Native team information branch unavailable')
                    assert(r~=host,'Native team information outside its container')
                end
                return r
            end
            local edit=s.view.btnRename.gameObject:GetComponent(typeof(U.RectTransform))
            local label=s.view.textName.rectTransform
            local rename,name=branch(edit),branch(label)
            local parts={snapshot(rename)};parts[1].contents={edit}
            if name~=rename then
                parts[2]=snapshot(name);parts[2].contents={label}
            else parts[1].contents[2]=label end
            local top=host:InverseTransformPoint(line:TransformPoint(U.Vector3(0,line.rect.yMax,0))).y
            local bottom=host:InverseTransformPoint(line:TransformPoint(U.Vector3(0,line.rect.yMin,0))).y
            return parts,top,bottom
        end
        local function moveInfo(parts,host,lineBottom,gap)
            local height=0
            for _,v in ipairs(parts)do
                local low,high=math.huge,-math.huge
                for _,r in ipairs(v.contents)do
                    for _,x in ipairs({r.rect.xMin,r.rect.xMax})do
                        for _,y in ipairs({r.rect.yMin,r.rect.yMax})do
                            local p=host:InverseTransformPoint(r:TransformPoint(U.Vector3(x,y,0)))
                            low=math.min(low,p.y);high=math.max(high,p.y)
                        end
                    end
                end
                v.contentCenter=(low+high)*.5;height=math.max(height,high-low)
            end
            local center=lineBottom-gap-height*.5
            for _,v in ipairs(parts)do
                local r=v.rect
                local delta=(center-v.contentCenter)*host.lossyScale.y/r.parent.lossyScale.y
                r.anchoredPosition=U.Vector2(v.position.x,v.position.y+delta)
            end
        end
        function W.decorate(s,cell,index)
            local st=W.controllers[s];if not st then return end
            local r=st.badges[cell]
            local shape=st.shapes[cell]
            local cr=shape.rectTransform
            local parent=st.root
            if not r then
                r=rect(parent,'ZMLTeamBadge',0,0,cr.rect.width,cr.rect.height);st.badges[cell]=r
                local bg=rect(r,'ColorGradient',0,0,cr.rect.width,cr.rect.height)
                local raw=bg.gameObject:AddComponent(typeof(U.UI.RawImage))
                raw.texture=st.gradient;raw.raycastTarget=false
                local mr=rect(r,'MarkClip',0,0,cr.rect.width,cr.rect.height)
                local maskImage=mr.gameObject:AddComponent(typeof(U.UI.Image));maskImage.raycastTarget=false
                local mask=mr.gameObject:AddComponent(typeof(U.UI.Mask));mask.showMaskGraphic=false
                local ir=rect(mr,'TeamMark',0,0,1,1)
                local icon=ir.gameObject:AddComponent(typeof(U.UI.Image));icon.raycastTarget=false;icon.maskable=true
            end
            r:SetAsLastSibling()
            local w,h,radius=geometry(shape)
            local key=w..':'..h..':'..radius
            if not st.fills[key]then st.fills[key]=gradient(w,h,radius)end
            if not st.clips[key]then st.clips[key]=markClip(w,h,radius)end
            local sz=cr.rect;local pt=parent:InverseTransformPoint(cr:TransformPoint(U.Vector3(sz.xMin,sz.yMax,0)))
            r.anchorMin=parent.pivot;r.anchorMax=parent.pivot;r.anchoredPosition=U.Vector2(pt.x,pt.y)
            r.localScale=U.Vector3(cr.lossyScale.x/parent.lossyScale.x,cr.lossyScale.y/parent.lossyScale.y,1)
            r.localRotation=U.Quaternion.Inverse(parent.rotation)*cr.rotation
            r.sizeDelta=U.Vector2(sz.width,sz.height)
            local t=W.model.get(index);local p=palette[t.color]
            local raw=r:GetChild(0).gameObject:GetComponent(typeof(U.UI.RawImage))
            raw.rectTransform.sizeDelta=U.Vector2(sz.width,sz.height)
            raw.texture=st.fills[key];raw.color=elementColor(p)
            raw.gameObject:SetActive(true);raw.enabled=true
            raw.canvasRenderer:SetAlpha(1);raw:SetAllDirty()
            local maskImage=r:GetChild(1).gameObject:GetComponent(typeof(U.UI.Image))
            local mr=maskImage.rectTransform;mr.sizeDelta=U.Vector2(sz.width,sz.height)
            local sprite=st.sprites[t.mark]
            maskImage.sprite=st.clips[key].sprite;maskImage.color=U.Color(1,1,1,1)
            maskImage.enabled=true;maskImage.canvasRenderer:SetAlpha(1)
            mr.gameObject:SetActive(sprite~=nil);mr.gameObject:GetComponent(typeof(U.UI.Mask)).enabled=true
            local icon=mr:GetChild(0).gameObject:GetComponent(typeof(U.UI.Image));local ir=icon.rectTransform
            local size=sz.height*1.8
            ir.sizeDelta=U.Vector2(size,size);ir.anchoredPosition=U.Vector2(sz.width*.2-size*.5,-(sz.height-size)*.5)
            icon.sprite=sprite;icon.preserveAspect=true;icon.gameObject:SetActive(sprite~=nil)
            local shade=index==s.m_curTeamIndex and 49/255 or .92
            icon.color=U.Color(shade,shade,shade,index==s.m_curTeamIndex and .32 or .4)
            icon.enabled=true;icon.canvasRenderer:SetAlpha(1);icon:SetAllDirty()
        end
        function W.paint(s)
            local st=W.controllers[s];if not st or not live(st.root)then return end
            for i=1,20 do
                local cell=s.m_teamCells:GetItem(i)
                if cell then W.decorate(s,cell,i)end
            end
            if st.popup and st.popup.repaint then st.popup.repaint()end
        end
        function W.queuePaint(s)
            local st=W.controllers[s];if not st or st.paintQueued then return end
            st.paintQueued=true
            s:_StartCoroutine(function()
                coroutine.step();st.paintQueued=false
                if W.controllers[s]~=st or not live(st.root)or not st.root.gameObject.activeSelf then return end
                local ok,e=pcall(W.paint,s)
                if not ok then logger.error('ZML MoreTeams paint: '..tostring(e))end
            end)
        end
        local function disposePopup(pop)
            if pop.disposed then return end
            pop.disposed=true
            if pop.autoClose and pop.autoClose.tmpSafeArea==pop.safeArea then
                pop.autoClose.tmpSafeArea=pop.previousSafeArea
            end
            if pop.inputRoot and live(pop.inputRoot)then
                pop.inputRoot.gameObject:SetActive(false);U.Object.Destroy(pop.inputRoot.gameObject)
            end
            if pop.root and live(pop.root)then
                pop.root.gameObject:SetActive(false);U.Object.Destroy(pop.root.gameObject)
            end
            for _,v in ipairs(pop.originals or {})do
                if live(v.layout)then v.layout.preferredHeight=v.height end
                for _,child in ipairs(v.children)do
                    if live(child.rect)then child.rect.gameObject:SetActive(child.active)end
                end
            end
        end
        function W.hidePopup(s)
            local st=W.controllers[s]
            if not st then return end
            st.popupEpoch=(st.popupEpoch or 0)+1
            local pop=st.popup;if not pop then return end
            st.popup=nil;disposePopup(pop)
            if pop.menu and pop.menu.m_args==pop.args then Notify(MessageConst.HIDE_NAVI_TARGET_ACTION_MENU)end
        end
        local function popupValid(s,st,index)
            return W.controllers[s]==st and live(st.root)and W.ctrlEnabled(s)and not W.blocked()
                and s.m_curTeamIndex==index and
                (s.state==UIConst.UI_CHAR_FORMATION_STATE.TeamWaitSet or s.state==UIConst.UI_CHAR_FORMATION_STATE.TeamHasSet)
        end
        local function nativeClone(source,parent,name,x,y,w,h,kind)
            local go=U.Object.Instantiate(source.gameObject,parent,false)
            go.name=name;go.layer=parent.gameObject.layer;go:SetActive(true)
            local r=go:GetComponent(typeof(U.RectTransform))
            r.anchorMin=U.Vector2(0,1);r.anchorMax=U.Vector2(0,1);r.pivot=U.Vector2(0,1)
            r.anchoredPosition=U.Vector2(x,-y);r.sizeDelta=U.Vector2(w,h)
            r.localScale=U.Vector3.one;r.localRotation=U.Quaternion.identity
            local graphic=assert(go:GetComponent(typeof(kind)),'Native picker graphic unavailable')
            graphic.enabled=true;graphic.raycastTarget=false;return graphic
        end
        function W.popup(s,index)
            local st=W.controllers[s];if not st or not popupValid(s,st,index)then return end
            if st.popup then W.hidePopup(s);return end
            st.popupEpoch=(st.popupEpoch or 0)+1
            local pop={index=index,epoch=st.popupEpoch,originals={},choices={}};st.popup=pop
            local args={transform=st.cells[index].rect,actions={{text=string.format('编队 %02d',index)},{text=''}},
                cellHeight=36,useSmallContent=false,noMask=true,
                checkActionValid=function()return st.popupEpoch==pop.epoch and popupValid(s,st,index)end,
                onClose=function()
                    disposePopup(pop)
                    if st.popup==pop then st.popup=nil end
                end}
            pop.args=args
            local ok,e=pcall(function()
                Notify(MessageConst.SHOW_NAVI_TARGET_ACTION_MENU,args)
                local menu=UIManager:AutoOpen(PanelId.NaviTargetActionMenu);pop.menu=menu
                assert(menu.m_args==args,'Native cosmetics popup unavailable')
                pop.autoClose=assert(menu.view.contentAutoCloseArea,'Native auto-close unavailable')
                pop.previousSafeArea=pop.autoClose.tmpSafeArea;pop.safeArea=st.root
                pop.autoClose.tmpSafeArea=pop.safeArea
                local canvas=menu.view.rectTransform
                pop.inputRoot=rect(canvas,'ZMLTeamPopupInput',0,0,canvas.rect.width,canvas.rect.height)
                pop.inputRoot:SetSiblingIndex(0)
                pop.selectors={}
                for i=1,20 do
                    local target=st.cells[i].rect
                    local tl=pop.inputRoot:InverseTransformPoint(target:TransformPoint(U.Vector3(target.rect.xMin,target.rect.yMax,0)))
                    local br=pop.inputRoot:InverseTransformPoint(target:TransformPoint(U.Vector3(target.rect.xMax,target.rect.yMin,0)))
                    local hit=rect(pop.inputRoot,'TeamClick'..i,tl.x,-tl.y,br.x-tl.x,tl.y-br.y)
                    local image=hit.gameObject:AddComponent(typeof(U.UI.Image))
                    image.color=U.Color(1,1,1,0);image.raycastTarget=true
                    local button=hit.gameObject:AddComponent(typeof(U.UI.Button))
                    button.targetGraphic=image;button.transition=U.UI.Selectable.Transition.None
                    local navigation=button.navigation;navigation.mode=U.UI.Navigation.Mode.None;button.navigation=navigation
                    button.onClick:AddListener(function()
                        if pop.disposed or st.popup~=pop or st.popupEpoch~=pop.epoch
                            or menu.m_args~=args or not popupValid(s,st,index)then return end
                        W.click(s,i)
                    end)
                    pop.selectors[i]={rect=hit,graphic=image,button=button}
                end
                local cell=assert(menu.m_cells:GetItem(2),'Native cosmetics cell unavailable')
                local parent=cell.titleNode.gameObject:GetComponent(typeof(U.RectTransform))
                local layout=assert(parent.gameObject:GetComponent(typeof(U.UI.LayoutElement)),
                    'Native title layout unavailable')
                local original={layout=layout,height=layout.preferredHeight,children={}}
                pop.originals[1]=original
                for i=0,parent.childCount-1 do
                    local child=parent:GetChild(i)
                    original.children[#original.children+1]={rect=child,active=child.gameObject.activeSelf}
                    child.gameObject:SetActive(false)
                end
                layout.preferredHeight=216
                local root=rect(parent,'ZMLTeamCosmetics',16,4,425,208);pop.root=root
                local colorLabel=nativeClone(cell.titleText,root,'ColorLabel',0,0,414,22,CS.TMPro.TextMeshProUGUI)
                local markLabel=nativeClone(cell.titleText,root,'MarkLabel',0,74,414,22,CS.TMPro.TextMeshProUGUI)
                if not live(st.emptySprite)then
                    st.emptySprite=assert(s.loader:LoadSprite('assets/beyond/arts/ui/sprites/common/state/icon_empty.png'),
                        'Native empty-set icon unavailable')
                end
                local shape=st.shapes[s.m_teamCells:GetItem(index)]
                local function background(parent,name,x,y,w,h,color)
                    local im=nativeClone(shape,parent,name,x,y,w,h,U.UI.Image)
                    im.color=color;return im
                end
                local function choose(kind,id)
                    if pop.disposed or st.popup~=pop or st.popupEpoch~=pop.epoch
                        or menu.m_args~=args or not popupValid(s,st,index)then return end
                    local success,err=pcall(function()
                        local saved,reason=W.model.edit(index,{[kind]=id});if not saved then error(reason)end
                        W.refresh(s)
                    end)
                    if not success then
                        Notify(MessageConst.SHOW_TOAST,'编队设置失败');logger.error('ZML MoreTeams UI: '..tostring(err))
                    end
                end
                local function tile(kind,id,x,y,w,h)
                    local rt=rect(root,kind..id,x,y,w,h)
                    local border=background(rt,'Background',0,0,w,h,U.Color(.19,.19,.19,1))
                    border.raycastTarget=true
                    local fill=background(rt,'Fill',4,4,w-8,h-8,
                        kind=='color'and id~=1 and elementColor(palette[id])or U.Color(1,1,1,0))
                    local button=rt.gameObject:AddComponent(typeof(U.UI.Button))
                    button.targetGraphic=border;button.transition=U.UI.Selectable.Transition.ColorTint
                    local colors=button.colors
                    colors.normalColor=U.Color(1,1,1,1);colors.highlightedColor=U.Color(1.15,1.15,1.15,1)
                    colors.pressedColor=U.Color(.75,.75,.75,1);colors.selectedColor=colors.normalColor
                    colors.fadeDuration=.1;button.colors=colors
                    button.onClick:AddListener(function()choose(kind,id)end)
                    local sprite=id==1 and st.emptySprite or kind=='mark'and st.sprites[id]
                    local icon
                    if sprite then
                        local size=id==1 and 24 or 32
                        local ir=rect(rt,'Icon',(w-size)*.5,(h-size)*.5,size,size)
                        icon=ir.gameObject:AddComponent(typeof(U.UI.Image))
                        icon.sprite=sprite;icon.preserveAspect=true;icon.raycastTarget=false
                    end
                    pop.choices[#pop.choices+1]={kind=kind,id=id,border=border,button=button,fill=fill,icon=icon}
                end
                for j,id in ipairs(colorChoices)do tile('color',id,(j-1)*70,26,64,38)end
                for id=1,16 do tile('mark',id,(id-1)%8*52,100+math.floor((id-1)/8)*52,46,46)end
                pop.repaint=function()
                    if pop.disposed or menu.m_args~=args then return end
                    local team=W.model.get(index)
                    colorLabel.text='颜色 · '..palette[team.color][1];markLabel.text='标记 · '..marks[team.mark]
                    for _,v in ipairs(pop.choices)do
                        local selected=v.kind=='mark'and v.id==team.mark or v.kind=='color'and
                            (v.id==team.color or(v.id~=1 and palette[v.id][2]==palette[team.color][2]))
                        v.selected=selected
                        v.border.color=selected and U.Color(.92,.92,.92,1)or U.Color(.19,.19,.19,1)
                        if v.icon then
                            v.icon.color=selected and U.Color(49/255,49/255,49/255,1)or U.Color(.92,.92,.92,1)
                        end
                    end
                end
                pop.repaint()
                LayoutRebuilder.ForceRebuildLayoutImmediate(menu.view.content)
                local notch=CS.Beyond.DeviceInfoManager.NotchPaddingInCanvas(menu.view.transform).x
                UIUtils.updateTipsPosition(menu.view.content,args.transform,menu.view.rectTransform,menu.uiCamera,
                    UIConst.UI_TIPS_POS_TYPE.RightTop,{bottom=100,left=notch,right=notch})
            end)
            if not ok then W.hidePopup(s);error(e)end
            W.queuePaint(s)
        end
        function W.click(s,index)
            if W.blocked()then return end
            if W.ctrlEnabled(s)and index==s.m_curTeamIndex and
                (s.state==UIConst.UI_CHAR_FORMATION_STATE.TeamWaitSet or s.state==UIConst.UI_CHAR_FORMATION_STATE.TeamHasSet)then
                W.popup(s,index)
            else W.hidePopup(s);s:_SetTeamSelect(index)end
            W.paint(s);W.queuePaint(s)
        end
        function W.stateChanged(s,state)
            local st=W.controllers[s];if not st then return end
            local visible=state==UIConst.UI_CHAR_FORMATION_STATE.TeamWaitSet or state==UIConst.UI_CHAR_FORMATION_STATE.TeamHasSet
            st.root.gameObject:SetActive(visible)
            if not visible then W.hidePopup(s)else W.queuePaint(s)end
        end
        function W.refresh(s)
            local st=W.controllers[s];if not st or not live(st.root)then return end
            if W.blocked()then W.hidePopup(s)end
            local active=W.active();s.m_teamSet=active
            local i=s.m_curTeamIndex
            if i>=1 and i<=20 then
                s.view.textName.text=W.name(i)
                if s.state==UIConst.UI_CHAR_FORMATION_STATE.TeamWaitSet or s.state==UIConst.UI_CHAR_FORMATION_STATE.TeamHasSet then
                    s:SetState(i==active and UIConst.UI_CHAR_FORMATION_STATE.TeamHasSet or UIConst.UI_CHAR_FORMATION_STATE.TeamWaitSet)
                end
            end
            for j=1,20 do
                local cell=s.m_teamCells:GetItem(j)
                if cell then cell:SetSelect(j==i)end
            end
            W.paint(s);W.queuePaint(s)
        end
        function W.mount(s)
            if not W.ctrlEnabled(s)then W.close(s);return end
            local st=W.controllers[s]
            if st and live(st.root)then W.refresh(s);return end
            local first=assert(s.m_teamCells:GetItem(1),'Native team selector unavailable')
            local r=first.gameObject:GetComponent(typeof(U.RectTransform));local host=s.view.transform
            local nativeCells={}
            for i=1,20 do nativeCells[i]=assert(s.m_teamCells:GetItem(i),'Native grid cell missing')end
            local shapes={}
            for _,cell in ipairs(nativeCells)do shapes[cell]=stableShape(cell)end
            local info=s.view.infoNoe.gameObject:GetComponent(typeof(U.RectTransform))
            U.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(info)
            for i=6,20 do nativeCells[i].gameObject:SetActive(false)end
            U.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(r.parent)
            local size=r.rect;local w,h=math.max(size.width,42),math.max(size.height,42);local gap=6
            local world=r:TransformPoint(U.Vector3(size.xMin,size.yMax,0));local point=host:InverseTransformPoint(world)
            local scale=U.Vector3(r.lossyScale.x/host.lossyScale.x,r.lossyScale.y/host.lossyScale.y,1)
            local infoParts,lineTop,lineBottom=teamLayout(s,host)
            local fw,fh,fr=geometry(shapes[first])
            local markTexture,sprites=W.createMarks()
            local success,fill=pcall(gradient,fw,fh,fr)
            if not success then
                for _,sprite in pairs(sprites)do U.Object.Destroy(sprite)end
                U.Object.Destroy(markTexture);error(fill)
            end
            local root=rect(host,'ZMLTeamGrid',0,0,w*5+gap*4,h*4+gap*3)
            local clearance=8*scale.y
            local top=math.min(math.max(point.y+3*(h+gap)*scale.y,
                lineTop+clearance+root.sizeDelta.y*scale.y),host.rect.yMax-8)
            root.anchorMin=host.pivot;root.anchorMax=host.pivot;root.anchoredPosition=U.Vector2(point.x,top)
            root.localScale=scale;root.localRotation=U.Quaternion.Inverse(host.rotation)*r.rotation
            st={root=root,host=host,scale=scale,cells={},badges={},shapes=shapes,layout={},infoParts=infoParts,gradient=fill,
                fills={[fw..':'..fh..':'..fr]=fill},clips={},markTexture=markTexture,sprites=sprites};W.controllers[s]=st
            for _,node in ipairs({r.parent,info})do
                for _,kind in ipairs({U.UI.LayoutGroup,U.UI.ContentSizeFitter})do
                    local component=node.gameObject:GetComponent(typeof(kind))
                    if component and component.enabled then st.layout[#st.layout+1]=component;component.enabled=false end
                end
            end
            for i=1,20 do st.cells[i]=snapshot(nativeCells[i].gameObject:GetComponent(typeof(U.RectTransform)))end
            for i=1,20 do
                local cell=nativeCells[i];cell.gameObject:SetActive(true)
                local cr=st.cells[i].rect
                cr:SetParent(root,false);cr.anchorMin=U.Vector2(0,1);cr.anchorMax=U.Vector2(0,1);cr.pivot=U.Vector2(0,1)
                cr.anchoredPosition=U.Vector2((i-1)%5*(w+gap),-math.floor((i-1)/5)*(h+gap))
                cr.sizeDelta=U.Vector2(w,h);cr.localScale=U.Vector3.one;cr.localRotation=U.Quaternion.identity
                cell:InitTeamCell({index=i},function()W.click(s,i)end)
            end
            moveInfo(infoParts,host,lineBottom,clearance)
            W.refresh(s);W.stateChanged(s,s.state)
        end
        function W.closeUI(s)
            local st=W.controllers[s];if not st then return end
            W.hidePopup(s)
            for _,r in pairs(st.badges)do if live(r)then U.Object.Destroy(r.gameObject)end end
            for _,tex in pairs(st.fills)do if live(tex)then U.Object.Destroy(tex)end end
            for _,clip in pairs(st.clips)do
                if live(clip.sprite)then U.Object.Destroy(clip.sprite)end
                if live(clip.texture)then U.Object.Destroy(clip.texture)end
            end
            for _,sprite in pairs(st.sprites)do if live(sprite)then U.Object.Destroy(sprite)end end
            if live(st.markTexture)then U.Object.Destroy(st.markTexture)end
            for _,v in ipairs(st.cells)do restore(v,st.host)end
            for _,v in ipairs(st.infoParts)do restore(v,st.host)end
            for _,component in ipairs(st.layout)do if live(component)and not component.enabled then component.enabled=true end end
            if live(st.root)then U.Object.Destroy(st.root.gameObject)end
        end
    end
end
