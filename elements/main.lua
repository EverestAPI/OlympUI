local ui = require("ui.main")
local uiu = require("ui.utils")
local megacanvas = require("ui.megacanvas")

local uie = {}
ui.e = uie

-- Default element functions and values.
uie.default = {
    base = false,
    __template = false,
    __updateID = false,

    x = 0,
    y = 0,
    width = 0,
    height = 0,
    reflowing = true,
    reflowingLate = true,
    visible = true,
    onscreen = true,

    miniroot = false,

    interactive = 0,

    parent = false,
    children = false,
    id = false,

    clip = false,
    clipPadding = false,

    cacheable = true,
    cacheForce = false,
    cachedCanvas = false,
    cachePadding = 16,
    consecutiveFreshDraws = 0,
    consecutiveCachedDraws = 0,
    drawID = 0,

    reflowID = 0,
    reflowLateID = 0,
    redrawID = 0,

    __realX = false,
    __realY = false,

    getPath = function(self)
        local id = self.id
        if not id then
            id = "(" .. self.__type .. ":" .. self.__rawid .. ")"
        end

        local parent = self.parent
        if parent then
            return parent.path .. "." .. id
        end

        return id
    end,

    getIsRooted = function(self)
        local root = ui.root
        local parent = self
        repeat
            if parent == root then
                return self
            end
            parent = parent.parent
        until not parent
        return false
    end,


    is = function(self, expected)
        local types = self.__types
        for i = 1, #types do
            if types[i] == expected then
                return true
            end
        end
        return false
    end,

    getRealX = function(self)
        return self.__realX or self.x
    end,

    setRealX = function(self, value)
        self.__realX = value
    end,

    getRealY = function(self)
        return self.__realY or self.y
    end,

    setRealY = function(self, value)
        self.__realY = value
    end,

    getScreenX = function(self)
        local pos = 0
        local el = self
        while el do
            pos = pos + el.realX
            el = el.parent
        end
        return pos
    end,

    setScreenX = function(self, value)
        local pos = 0
        local el = self.parent
        while el do
            pos = pos + el.realX
            el = el.parent
        end
        value = value - pos
        self.x = value
        self.realX = value
    end,

    getScreenY = function(self)
        local pos = 0
        local el = self
        while el do
            pos = pos + el.realY
            el = el.parent
        end
        return pos
    end,

    setScreenY = function(self, value)
        local pos = 0
        local el = self.parent
        while el do
            pos = pos + el.realY
            el = el.parent
        end
        value = value - pos
        self.y = value
        self.realY = value
    end,

    getInnerWidth = function(self)
        return self.width
    end,

    getInnerHeight = function(self)
        return self.height
    end,

    contains = function(self, mx, my)
        local ex = self.screenX
        local ey = self.screenY
        local ew = self.width
        local eh = self.height

        return not (
            mx < ex or ex + ew < mx or
            my < ey or ey + eh < my
        )
    end,

    intersects = function(self, ml, mt, mr, mb)
        local el = self.screenX
        local er = el + self.width
        local et = self.screenY
        local eb = et + self.height

        return not (
            mr < el or er < ml or
            mb < et or eb < mt
        )
    end,

    getAlive = function(self)
        return ui.root.__collection == self.__collection
    end,

    getHovered = function(self)
        local hovering = ui.hovering
        while hovering do
            if hovering == self then
                return true
            end
            hovering = hovering.parent
        end
        return false
    end,

    getPressed = function(self)
        local dragging = ui.dragging
        while dragging do
            if dragging == self then
                return self.hovered
            end
            dragging = dragging.parent
        end
        return false
    end,

    getDragged = function(self)
        local dragging = ui.dragging
        while dragging do
            if dragging == self then
                return true
            end
            dragging = dragging.parent
        end
        return false
    end,

    getFocused = function(self)
        local focusing = ui.focusing
        while focusing do
            if focusing == self then
                return true
            end
            focusing = focusing.parent
        end
        return false
    end,

    init = function(self)
    end,

    as = function(self, id)
        self.id = id
        return self
    end,

    with = function(self, props, ...)
        if uiu.isCallback(props) then
            local rv = props(self, ...)
            return rv or self
        end

        for k, v in pairs(props) do
            self[k] = v
        end
        self:reflow()
        return self
    end,

    hook = function(self, ...)
        uiu.hook(self, ...)

        self:reflow()
        return self
    end,

    foreach = function(self, funcOrID, ...)
        local cb = funcOrID
        if type(funcOrID) == "string" then
            cb = self[funcOrID]
        end

        if uiu.isCallback(cb) then
            local rv = {cb(self, ...)}
            if #rv ~= 0 then
                return table.unpack(rv)
            end
        end

        local children = self.children
        if children then
            for i = 1, #children do
                local rv = {children[i]:foreach(funcOrID, ...)}
                if #rv ~= 0 then
                    return table.unpack(rv)
                end
            end
        end
    end,

    reflow = function(self)
        if ui.log.reflow then
            print("[olympui]", "reflow", self)
        end

        local el = self
        repeat
            el.reflowing = true
            el.reflowingLate = true
            el.cachedCanvas = false
            el = el.parent
        until not el or el.reflowing or el.miniroot
    end,

    reflowDown = function(self)
        local children = self.children
        if children then
            for i = 1, #children do
                local c = children[i]
                c.reflowing = true
                c.reflowingLate = true
                c.cachedCanvas = false
                c:reflowDown()
            end
        end
    end,

    reflowLate = function(self)
        if ui.log.reflow then
            print("[olympui]", "reflowLate", self)
        end

        local el = self
        while el do
            el.reflowingLate = true
            el.cachedCanvas = false
            el = el.parent
        end

        self:repaintDown()
    end,

    reflowLateDown = function(self)
        local children = self.children
        if children then
            for i = 1, #children do
                local c = children[i]
                c.reflowingLate = true
                c.cachedCanvas = false
                c:reflowDown()
            end
        end
    end,

    repaint = function(self)
        if ui.log.reflow then
            print("[olympui]", "repaint", self)
        end

        local el = self
        while el do
            el.cachedCanvas = false
            el = el.parent
        end
    end,

    repaintDown = function(self)
        local children = self.children
        if children then
            for i = 1, #children do
                local c = children[i]
                c.cachedCanvas = false
                c:repaintDown()
            end
        end
    end,

    -- awake = function(self) end,
    awake = false,
    __awakened = false,

    -- revive = function(self) end,
    revive = false,

    -- update = function(self, dt) end,
    update = false,
    -- updateHidden = function(self) end,
    updateHidden = false,
    __dtHidden = 0,

    layoutLazy = function(self)
        if self.reflowID ~= ui.globalReflowID then
            self.reflowID = ui.globalReflowID
        elseif not self.reflowing then
            return false
        end
        self.reflowing = false

        self:layout()

        return true
    end,

    layout = function(self)
        self.__layoutLastUpdateID = ui.updateID
        ui.stats.layouts = ui.stats.layouts + 1
        self:layoutChildren()
        self:recalc()
    end,

    layoutChildren = function(self)
        local children = self.children
        if children then
            for i = 1, #children do
                local c = children[i]
                c.parent = self
                c:layoutLazy()
            end
        end
    end,

    layoutLateLazy = function(self)
        if self.reflowLateID ~= ui.globalReflowID then
            self.reflowLateID = ui.globalReflowID
        elseif not self.reflowingLate then
            return false
        end
        self.reflowingLate = false

        self:layoutLate()

        return true
    end,

    layoutLate = function(self)
        ui.stats.layouts = ui.stats.layouts + 1
        self.style.__propcacheGet = {}
        self.style.__propcacheSet = {}
        self:layoutLateChildren()
    end,

    layoutLateChildren = function(self)
        local children = self.children
        if children then
            for i = 1, #children do
                local c = children[i]
                c.parent = self
                c:layoutLateLazy()
            end
        end
    end,

    recalc = function(self)
        local calcset = {}

        for k, v in pairs(self) do
            if k:sub(1, 4) == "calc" then
                if not calcset[k] then
                    calcset[k] = true
                    self[k:sub(5, 5):lower() .. k:sub(6)] = v(self)
                end
            end
        end

        local eltype = self.__type
        local eltypeBase = eltype
        while eltypeBase do
            local default = uie[eltypeBase].__default
            for k, v in pairs(default) do
                if k:sub(1, 4) == "calc" then
                    if not calcset[k] then
                        calcset[k] = true
                        self[k:sub(5, 5):lower() .. k:sub(6)] = v(self)
                    end
                end
            end
            eltypeBase = default.base
        end
    end,

    draw = function(self)
        local children = self.children
        if children then
            if not self.cacheable and not self.cacheForce then
                for i = 1, #children do
                    local c = children[i]
                    if c.onscreen and c.visible then
                        c:redraw()
                    end
                end
            else
                for i = 1, #children do
                    children[i]:redraw()
                end
            end
        end
    end,

    -- drawDebug = function(self, layout, decached) end,
    -- drawDebug = false,
    drawDebug = function(self, layout, decached)
        local delayouted = self.__layoutLastUpdateID == ui.updateID
        local forcecached = self.cacheForce

        local x = self.screenX
        local y = self.screenY
        local width = self.width
        local height = self.height

        love.graphics.setLineWidth(1)
        love.graphics.setBlendMode("alpha", "premultiplied")

        if layout then
            -- red = outter
            -- green = inner
            -- blue = padding orientation
            -- yellow = outline

            local visibleRect = self.__cached.visibleRect
            local el = visibleRect[1]
            local et = visibleRect[2]
            local er = visibleRect[3]
            local eb = visibleRect[4]
            uiu.setColor(0, 0, 0.5, 0.5)
            love.graphics.rectangle("line", el + 0.5, et + 0.5, er - el - 1, eb - et - 1)

            local padding = self.style:get("padding")
            if padding and padding ~= 0 then
                local paddingL, paddingT, paddingR, paddingB = padding, padding, padding, padding
                if type(padding) == "table" then
                    paddingL, paddingT, paddingR, paddingB = unpack(padding)
                end

                uiu.setColor(0.75, 0, 0, 0.5)
                love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1)

                uiu.setColor(0, 0, 0.25, 0.25)
                love.graphics.rectangle("line", x + 0.5, y + 0.5, paddingL - 1, paddingT - 1)

                uiu.setColor(0, 0.125, 0, 0.125)
                love.graphics.rectangle("line", x + 0.5 + paddingL, y + 0.5 + paddingT, width - paddingR * 2 - 1, height - paddingB * 2 - 1)

            else
                uiu.setColor(0.75, 0.75, 0, 0.5)
                love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1)
            end

        else
            uiu.setColor(decached and 0.75 or 0.25, forcecached and 0.75 or 0.25, delayouted and 0.75 or 0.25, 0.5)
            -- love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1)
            local canvas = self.__cached.canvas
            if canvas then
                width = canvas.width
                height = canvas.height
            end
            love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1)
        end

        love.graphics.setBlendMode("alpha", "alphamultiply")


        local text = self.id
        if not text then
            text = "(" .. self.__type .. ":" .. self.__rawid .. ")"
        end
        if ui.debug.draw == -2 then
            text = text .. " [" .. tostring(self.consecutiveFreshDraws) .. "]"
        end

        uiu.setColor(0, 0, 0, 1)
        local pos = love.math.newTransform(x, y)
        pos:translate(0, -1)
        love.graphics.print(text, ui.fontDebug, pos)
        pos:translate(0, 2)
        love.graphics.print(text, ui.fontDebug, pos)
        pos:translate(-1, -1)
        love.graphics.print(text, ui.fontDebug, pos)
        pos:translate(2, 0)
        love.graphics.print(text, ui.fontDebug, pos)
        pos:translate(-1, 0)

        if layout then
            if self.cacheForce then
                uiu.setColor(1, 0, 1, 1)
            elseif self.cacheable then
                if decached then
                    uiu.setColor(1, 0, 0, 1)
                else
                    uiu.setColor(1, 1, 0, 1)
                end
            else
                uiu.setColor(1, 1, 1, 1)
            end
        else
            if not delayouted and not forcecached and not decached then
                uiu.setColor(1, 1, 1, 1)
            else
                uiu.setColor(decached and 1 or 0, forcecached and 1 or 0, delayouted and 1 or 0, 1)
            end
        end
        love.graphics.print(text, ui.fontDebug, pos)

    end,

    __draw = function(self, skipCache)
        ui.stats.draws = ui.stats.draws + 1

        local cacheForce = self.cacheForce
        if (not self.cacheable or skipCache == 1) and not cacheForce then
            return self:draw()
        end

        local width = self.width
        local height = self.height

        if width <= 0 or height <= 0 then
            return
        end

        local padding = self.cachePadding
        local paddingL, paddingT, paddingR, paddingB
        if type(padding) == "table" then
            paddingL, paddingT, paddingR, paddingB = padding[1], padding[2], padding[3], padding[4]
        else
            paddingL, paddingT, paddingR, paddingB = padding, padding, padding, padding
        end

        width = width + paddingL + paddingR
        height = height + paddingT + paddingB

        local cacheStatus = self.cachedCanvas
        local repaint = not cacheStatus or cacheStatus == 0

        if not cacheStatus then
            self.consecutiveFreshDraws = 0
            if self.consecutiveCachedDraws > 0 then
                self.consecutiveCachedDraws = 0
            else
                self.consecutiveCachedDraws = self.consecutiveCachedDraws - 1
            end
            self.cachedCanvas = 0
        elseif self.consecutiveCachedDraws < 0 then
            self.consecutiveCachedDraws = 0
        else
            self.consecutiveCachedDraws = self.consecutiveCachedDraws + 1
        end

        local cached = self.__cached
        local canvas = cached.canvas

        if cacheForce then
            repaint = true

        elseif self.consecutiveCachedDraws < 10 then
            if canvas and self.consecutiveCachedDraws < -60 * 3 then
                if canvas.release then
                    canvas:release()
                else
                    canvas.canvas:release()
                end
                cached.canvas = nil
                if ui.log.canvas then
                    print("[olympui]", "canvas unused", self)
                end
            end

            return self:draw()
        end

        if canvas then
            if width > canvas.canvasWidth or height > canvas.canvasHeight then
                if width > megacanvas.widthMax or height > megacanvas.heightMax then
                    if canvas.release then
                        canvas:release()
                    else
                        canvas.canvas:release()
                    end
                    canvas = nil
                    cached.canvas = nil
                    if ui.log.canvas then
                        print("[olympui]", "canvas oversized", self)
                    end
                elseif canvas.init then
                    canvas:init(width, height)
                    repaint = true
                    if ui.log.canvas then
                        print("[olympui]", "canvas resized", self)
                    end
                else
                    if canvas.release then
                        canvas:release()
                    else
                        canvas.canvas:release()
                    end
                    canvas = nil
                    cached.canvas = nil
                    repaint = true
                    if ui.log.canvas then
                        print("[olympui]", "canvas to be recreated resized", self)
                    end
                end
            end
        end

        if width > megacanvas.widthMax or height > megacanvas.heightMax then
            return self:draw()
        end

        if not canvas or not canvas.index then
            repaint = true
            if not canvas then
                ui.stats.canvases = ui.stats.canvases + 1
            end
            if ui.features.megacanvas then
                canvas = megacanvas(width, height)
            else
                canvas = {
                    canvas = love.graphics.newCanvas(width, height),
                    canvasWidth = width,
                    canvasHeight = height,
                    index = -1,
                    mark = false,
                    init = false,
                    draw = false,
                    release = false
                }
            end
            cached.canvas = canvas
            if ui.log.canvas then
                print("[olympui]", "canvas created", self)
            end
        end

        canvas.width = width
        canvas.height = height

        local x = self.screenX
        local y = self.screenY

        if not repaint and skipCache ~= 2 then
            if self.consecutiveCachedDraws > 10 and canvas.mark then
                canvas:mark()
                if canvas.marked and ui.log.canvas then
                    print("[olympui]", "canvas marked", self)
                end
            end

            self:__drawCachedCanvas(canvas, x, y, width, height, paddingL, paddingT, paddingR, paddingB)
            return
        end

        self.cachedCanvas = 1

        if canvas.init then
            canvas:init()
        end

        local sX, sY, sW, sH = love.graphics.getScissor()

        local canvasPrev = love.graphics.getCanvas()
        love.graphics.setCanvas(canvas.canvas)
        love.graphics.setScissor()
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setScissor(0, 0, width, height)

        love.graphics.push()
        love.graphics.origin()
        love.graphics.translate(-x + paddingL, -y + paddingT)

        self:draw()

        love.graphics.pop()

        love.graphics.setCanvas(canvasPrev)
        love.graphics.setScissor(sX, sY, sW, sH)

        return self:__drawCachedCanvas(canvas, x, y, width, height, paddingL, paddingT, paddingR, paddingB)
    end,

    __drawCachedCanvas = function(self, canvas, x, y, width, height, paddingL, paddingT, paddingR, paddingB)
        uiu.setColor(1, 1, 1, 1)
        uiu.drawCanvas(canvas, x - paddingL, y - paddingT)
    end,

    redraw = function(self)
        if self.redrawID ~= ui.globalReflowID then
            self.redrawID = ui.globalReflowID
            self.cachedCanvas = false
        elseif ui.repaintAll then
            self.cachedCanvas = false
        end

        local drawID = ui.drawID
        if self.drawID + 1 == drawID then
            local draws = self.consecutiveFreshDraws + 1
            self.consecutiveFreshDraws = draws
            if ui.debug.draw == -2 and draws % 60 == 0 and self.cacheable then
                print("consecutiveFreshDraws", self, self.consecutiveFreshDraws)
            end
        else
            self.consecutiveFreshDraws = 0
        end

        if ui.debug.draw then
            local cb = self.drawDebug
            if ui.debug.draw == -1 then
                uie.default.draw(self)
                if cb then
                    cb(self, true)
                end
            elseif ui.debug.draw == -2 then
                self:__draw(0)
                if cb and self.cachedCanvas then
                    cb(self, true)
                end
            elseif ui.debug.draw == -3 then
                local cachedCanvas = self.cachedCanvas
                self:__draw(2)
                if cb and self.cacheable then
                    cb(self, false, ((self.cachedCanvas and 1 or 0) ~= (cachedCanvas and 1 or 0)) or self.cachedCanvas == 0)
                end
            else
                self:__draw(1)
                if cb then
                    cb(self, true)
                end
            end
        else
            self:__draw(0)
        end

        self.drawID = drawID
    end,

    addChild = function(self, child, index)
        if not child then
            return false
        end
        local children = self.children
        for i = 1, #children do
            local c = children[i]
            if c == child then
                return false
            end
        end
        if index then
            table.insert(children, index, child)
        else
            children[#children + 1] = child
        end
        child.__removing = false
        child.parent = self
        self:reflow()
        if ui.root then
            ui.root:recollect()
        end
        return true
    end,

    removeChild = function(self, child)
        if not child then
            return false
        end
        child.__removing = false
        local children = self.children
        for i = 1, #children do
            local c = children[i]
            if c == child then
                child.parent = false
                table.remove(children, i)
                self:reflow()
                if ui.root then
                    ui.root:recollect()
                end
                return true
            end
        end
        self:reflow()
        if ui.root then
            ui.root:recollect()
        end
        return false
    end,

    __removing = false,
    removeSelf = function(self)
        local parent = self.parent

        if not parent then
            -- Parent not present, remove late.
            if not self.__removing then
                self.__removing = true
                ui.runLate(function()
                    if self.__removing then
                        self.__removing = false
                        self:removeSelf()
                    end
                end)
            end

            return
        end

        return parent:removeChild(self)
    end,

    getParent = function(self, id, id2, ...)
        if not id then
            return
        end

        local parent = self.parent
        while parent do
            if parent.id == id then
                return parent, self:getParent(id2, ...)
            end
            parent = parent.parent
        end

        return nil, self:getParent(id2, ...)
    end,

    getChild = function(self, id, id2, ...)
        if not id then
            return
        end

        local children = self.children
        if children then
            for i = 1, #children do
                local c = children[i]
                local cid = c.id
                if cid and cid == id then
                    return c, self:getChild(id2, ...)
                end
            end
        end

        return nil, self:getChild(id2, ...)
    end,

    findChild = function(self, id, id2, ...)
        if not id then
            return
        end

        local children = self.children
        if children then
            for i = 1, #children do
                local c = children[i]
                local cid = c.id
                if cid and cid == id then
                    return c, self:findChild(id2, ...)
                end
            end

            for i = 1, #children do
                local c = children[i]
                c = c:findChild(id)
                if c then
                    return c, self:findChild(id2, ...)
                end
            end
        end

        return nil, self:findChild(id2, ...)
    end,

    getChildAt = function(self, mx, my)
        local interactive = self.interactive
        if interactive < 0 then
            return nil
        end

        --[[
        if not self:contains(mx, my) then
            return nil
        end
        --]]

        local ex = self.screenX
        local ey = self.screenY
        local ew = self.width
        local eh = self.height

        if
            mx < ex or ex + ew < mx or
            my < ey or ey + eh < my
        then
            return nil
        end

        local children = self.children
        if children then
            for i = #children, 1, -1 do
                local c = children[i]
                c = c:getChildAt(mx, my)
                if c then
                    return c
                end
            end
        end

        if interactive == 0 then
            return nil
        end

        return self
    end,

    -- onEnter = function(self) end,
    onEnter = false,
    -- onLeave = function(self) end,
    onLeave = false,
    -- onUnfocus = function(self, x, y, button, dragging) end,
    onUnfocus = false,
    -- onPress = function(self, x, y, button, dragging) end,
    onPress = false,
    -- onRelease = function(self, x, y, button, dragging) end,
    onRelease = false,
    -- onClick = function(self, x, y, button) end,
    onClick = false,
    -- onDrag = function(self, x, y, dx, dy) end,
    onDrag = false,
    -- onScroll = function(self, x, y, dx, dy) end,
    onScroll = false,
    -- onKeyPress = function(self, key, scancode, isrepeat) end,
    onKeyPress = false,
    -- onKeyRelease = function(self, key, scancode) end,
    onKeyRelease = false,
    -- onText = function(self, text) end,
    onText = false,
}

uie.__default = uie.default

-- Shared metatable for all style helper tables.
local function styleGetParent(self, key)
    local el = rawget(self, "el")

    local defaultStyle = el.__default.style
    if defaultStyle then
        local v = defaultStyle[key]
        if v ~= nil then
            return v, defaultStyle
        end
    end

    local template = el.__template
    local templateStyle = template and template.style
    if templateStyle then
        local v, owner = styleGetParent(templateStyle, key)
        if v ~= nil then
            return v, owner
        end
    end

    local baseStyle = el.__base.style
    if baseStyle then
        local v, owner = styleGetParent(baseStyle, key)
        if v ~= nil then
            return v, owner
        end
    end
end

local function styleGet(self, key)
    local v = rawget(self, key)
    if v ~= nil then
        return v
    end

    if key == "get" then
        return rawget(self, "get")
    end

    if key == "getIndex" then
        return rawget(self, "getIndex")
    end

    local propcache = rawget(self, "__propcacheGet")
    local cached = propcache and propcache[key]
    if cached ~= nil then
        return cached[key]
    end

    v, cached = styleGetParent(self, key)
    if v ~= nil then
        if propcache then
            propcache[key] = cached
        end
        return v
    end
end

local function styleGetIndex(self, key, index)
    local v = styleGet(self, key)
    if v ~= nil then
        if type(v) == "table" then
            return v[index]
        end
        return v
    end
end

local mtStyle = {
    __name = "ui.element.style",

    __index = function(self, key)
        local v = rawget(self, "get")(self, key)
        if v ~= nil then
            return v
        end

        error("Unknown styling property: " .. rawget(self, "el").__type .. " [\"" .. tostring(key) .. "\"]", 2)
    end
}

-- Shared metatable for all element tables.
local mtEl
mtEl = {
    __name = "ui.element",

    __index = function(self, key, keyGet)
        local v = rawget(self, key)
        if v ~= nil then
            return v
        end

        if key == "style" then
            return rawget(self, "__style")
        end

        local propcache = rawget(self, "__propcacheGet")
        local cached = propcache[key]
        if cached then
            local ctype = cached.type

            if ctype == 1 then
                return cached.value(self)

            elseif ctype == 2 then
                v = cached.owner[key]
                if v ~= nil then
                    return v
                end

            elseif ctype == 3 then
                local id = cached.id
                local children = self.children
                local c = children[cached.i]
                if c and c.id == id then
                    return c
                end
                for i = 1, #children do
                    local c = children[i]
                    if c.id == id then
                        cached.i = i
                        return c
                    end
                end
            end
        end

        local keyType = type(key)

        if keyType == "string" and keyGet == nil then
            local prefix = key:sub(1, 1)
            keyGet = prefix ~= "_" and ("get" .. prefix:upper() .. key:sub(2))
        end

        if keyGet then
            v = rawget(self, keyGet)
            if v ~= nil then
                propcache[key] = { type = 1, value = v }
                return v(self)
            end
        end

        local default = rawget(self, "__default")
        if keyGet then
            v = default[keyGet]
            if v ~= nil then
                propcache[key] = { type = 1, value = v }
                return v(self)
            end
        end

        v = default[key]
        if v ~= nil then
            propcache[key] = { type = 2, owner = default }
            return v
        end

        local base = default.base
        if base then
            base = uie[default.base]

            if base then
                if keyGet then
                    v = mtEl.__index(base, keyGet, false)
                    if v ~= nil then
                        propcache[key] = { type = 1, value = v }
                        return v(self)
                    end
                end

                v = mtEl.__index(base, key, keyGet)
                if v ~= nil then
                    propcache[key] = { type = 2, owner = base }
                    return v
                end
            end
        end

        if key == "children" then
            return nil
        end

        if keyGet then
            v = uie.default[keyGet]
            if v ~= nil then
                propcache[key] = { type = 1, value = v }
                return v(self)
            end
        end

        v = uie.default[key]
        if v ~= nil then
            propcache[key] = { type = 2, owner = uie.default }
            return v
        end

        local children
        if keyType == "number" then
            if key < 0 then
                local p = self
                for _ = 1, -key do
                    p = p.parent
                    if p == nil then
                        return p
                    end
                end
                return p
            end

            if children == nil then
                children = self.children
            end
            if children == nil then
                return nil
            end
            local c = children[key]
            if c ~= nil then
                return c
            end
        end

        if ui.features.metachildren then
            if children == nil then
                children = self.children
            end
            if children then
                if keyType == "string" and key:sub(1, 1) == "_" then
                    local id = key:sub(2)
                    for i = 1, #children do
                        local c = children[i]
                        local cid = c.id
                        if cid and cid == id then
                            propcache[key] = { type = 3, i = i, id = id }
                            return c
                        end
                    end
                end
            end
        end
    end,

    __newindex = function(self, key, value)
        if key == "style" then
            local style = rawget(self, "__style")
            if not value then
                for k, v in pairs(style) do
                    if k ~= "el" and k ~= "get" and k ~= "getIndex" and k ~= "__propcacheGet" then
                        style[k] = nil
                    end
                end
            else
                for k, v in pairs(value) do
                    style[k] = v
                end
            end
            return self
        end

        local propcache = rawget(self, "__propcacheSet")
        local cached = propcache[key]
        if cached then
            return cached(self, value)
        end

        local keySet = nil
        if type(key) == "string" then
            local prefix = key:sub(1, 1)
            if prefix ~= "_" then
                keySet = "set" .. prefix:upper() .. key:sub(2)

                local cb = rawget(self, keySet)
                if cb ~= nil then
                    propcache[key] = cb
                    return cb(self, value)
                end

                local default = self.__default
                local cb = default[keySet]
                if cb ~= nil then
                    propcache[key] = cb
                    return cb(self, value)
                end

                local base = default.base
                if base then
                    base = uie[default.base]

                    if base then
                        cb = mtEl.__index(base, keySet, false)
                        if cb then
                            propcache[key] = cb
                            return cb(self, value)
                        end
                    end
                end

                cb = uie.default[keySet]
                if cb then
                    propcache[key] = cb
                    return cb(self, value)
                end
            end
        end

        return rawset(self, key, value)
    end,

    __call = function(self, ...)
        local __call = self.__call
        if __call then
            return __call(...)
        end
        return self:with(...)
    end,

    __gc = function(self)
        if self.__cached.canvas then
            ui.stats.canvases = ui.stats.canvases - 1
            if ui.log.canvas then
                print("[olympui]", "canvas freed", self)
            end
        end
    end,

    __tostring = function(self)
        return self.path
    end
}

local mtTemplate = {
    __call = function(template, ...)
        local el = template.__new()
        el:init(...)
        return el
    end
}

for k, v in pairs(mtEl) do
    if mtTemplate[k] == nil then
        mtTemplate[k] = v
    end
end

-- Function to register a new UI element.
function uie.add(eltype, default)
    local template

    local function new()
        local el = {
            __new = new,
            __ui = ui,
            __type = eltype,
            __types = { eltype },
            __default = default,
            __template = template,
            __base = uie[default.base or "default"] or uie.default,
            __propcacheGet = {},
            __propcacheSet = {},
            __cached = {
                canvas = nil,
                visibleRect = { 0, 0, 0, 0 },
                screenX = nil,
                screenY = nil
            },
            __collection = ui.root and ui.root.__collection or 0
        }

        el.__style = setmetatable({
            el = el,
            __propcacheGet = {},
            get = styleGet,
            getIndex = styleGetIndex
        }, mtStyle)
        el.__rawid = tostring(el):sub(8)

        if _G.newproxy then
            local proxy = _G.newproxy(true)
            getmetatable(proxy).__gc = function()
                mtEl.__gc(el)
            end
            el.__proxy = proxy
        end

        uie.flatten(el)

        return setmetatable(el, mtEl)
    end

    template = setmetatable(new(), mtTemplate)
    uie[eltype] = template
    uie["__" .. eltype] = template

    return new
end

function uie.flatten(el)
    local __default = uie.default
    local types = el.__types
    local default = el.__default

    repeat
        types[#types + 1] = default.__type
        for k, v in pairs(default) do
            if k:sub(1, 1) ~= "_" and k ~= "style" and el[k] == nil then
                el[k] = v
            end
        end
        default = uie[default.base or "default"]
    until default == __default

    types[#types + 1] = default.__type
    for k, v in pairs(default) do
        if k ~= "style" and el[k] == nil then
            el[k] = v
        end
    end
end

uie.add("new", {
    init = function(self, props, ...)
        local initOrig = self.init

        self:with(props, ...)

        local init = self.init
        if init ~= initOrig then
            self.init = initOrig
            init(self)
        end
    end
})

return uie
