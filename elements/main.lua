local ui = require("ui.main")
local uiu = require("ui.utils")

local uie = {}
ui.e = uie

-- Default element functions and values.
uie.default = {
    x = 0,
    y = 0,
    width = 0,
    height = 0,
    reflowing = true,
    reflowingLate = true,
    visible = true,
    onscreen = true,

    interactive = 0,

    parent = false,
    id = false,

    cacheable = true,
    cacheForce = false,
    cachedCanvas = false,
    cachePadding = 16,
    consecutiveFreshDraws = 0,
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

    getScreenY = function(self)
        local pos = 0
        local el = self
        while el do
            pos = pos + el.realY
            el = el.parent
        end
        return pos
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

    reflow = function(self)
        if ui.debug.log then
            print("reflow", self)
        end

        local el = self
        while el do
            el.reflowing = true
            el.reflowingLate = true
            el.cachedCanvas = nil
            el = el.parent
        end

        self:repaintDown()
    end,

    reflowDown = function(self)
        local children = self.children
        if children then
            for i = 1, #children do
                local c = children[i]
                c.reflowing = true
                c.reflowingLate = true
                c.cachedCanvas = nil
                c:reflowDown()
            end
        end
    end,

    reflowLate = function(self)
        if ui.debug.log then
            print("reflowLate", self)
        end

        local el = self
        while el do
            el.reflowingLate = true
            el.cachedCanvas = nil
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
                c.cachedCanvas = nil
                c:reflowDown()
            end
        end
    end,

    repaint = function(self)
        if ui.debug.log then
            print("repaint", self)
        end

        local el = self
        while el do
            el.cachedCanvas = nil
            el = el.parent
        end
    end,

    repaintDown = function(self)
        local children = self.children
        if children then
            for i = 1, #children do
                local c = children[i]
                c.cachedCanvas = nil
                c:repaintDown()
            end
        end
    end,

    -- awake = function(self) end,
    awake = false,
    __awakened = false,

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
        self.style.__propcache = {}
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
            local default = uie["__" .. eltypeBase].__default
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

    -- drawDebug = function(self) end,
    -- drawDebug = false,
    drawDebug = function(self)
        local x = self.screenX
        local y = self.screenY
        local width = self.width
        local height = self.height

        love.graphics.setLineWidth(1)
        love.graphics.setBlendMode("alpha", "premultiplied")

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
            uiu.setColor(0.75, 0, 0, 0.5)
            love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1)

            uiu.setColor(0, 0, 0.25, 0.25)
            love.graphics.rectangle("line", x + 0.5, y + 0.5, padding - 1, padding - 1)

            uiu.setColor(0, 0.125, 0, 0.125)
            love.graphics.rectangle("line", x + 0.5 + padding, y + 0.5 + padding, width - padding * 2 - 1, height - padding * 2 - 1)

        else
            uiu.setColor(0.75, 0.75, 0, 0.5)
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

        if self.cacheForce then
            uiu.setColor(1, 0, 1, 1)
        elseif self.cacheable then
            uiu.setColor(1, 1, 0, 1)
        else
            uiu.setColor(1, 1, 1, 1)
        end
        love.graphics.print(text, ui.fontDebug, pos)

    end,

    __draw = function(self, skipCache)
        if (not self.cacheable or skipCache) and not self.cacheForce then
            return self:draw()
        end

        local width = self.width
        local height = self.height

        if width <= 0 or height <= 0 then
            return
        end

        local padding = self.cachePadding
        width = width + padding * 2
        height = height + padding * 2

        local cached = self.__cached

        local canvas = self.cachedCanvas
        if not canvas then
            self.consecutiveFreshDraws = 0
        end

        if self.cacheForce then
            -- This will keep the cached canvas but force a redraw onto the canvas, as if repaint() was called.
            canvas = nil
        end

        if width > cached.width or height > cached.height then
            canvas = canvas or cached.canvas
            if canvas then
                canvas:release()
                cached.canvas = nil
                canvas = nil
            end

            cached.width = width
            cached.height = height
        end

        -- TODO: Get max supported texture size?
        if width > 4096 or height > 4096 then
            return self:draw()
        end

        local x = self.screenX
        local y = self.screenY

        if canvas then
            self:__drawCachedCanvas(canvas, x, y, width, height, padding)
            return
        end

        canvas = cached.canvas

        if not canvas then
            canvas = love.graphics.newCanvas(width, height)
            cached.canvas = canvas
        end
        self.cachedCanvas = canvas

        local sX, sY, sW, sH = love.graphics.getScissor()

        local canvasPrev = love.graphics.getCanvas()
        love.graphics.setCanvas(canvas)
        if sX then
            love.graphics.setScissor()
        end
        love.graphics.clear(0, 0, 0, 0)

        love.graphics.push()
        love.graphics.origin()
        love.graphics.translate(-x + padding, -y + padding)

        local rv = { self:draw() }

        love.graphics.pop()

        love.graphics.setCanvas(canvasPrev)
        if sX then
            love.graphics.setScissor(sX, sY, sW, sH)
        end

        self:__drawCachedCanvas(canvas, x, y, width, height, padding)
        return table.unpack(rv)
    end,

    __drawCachedCanvas = function(self, canvas, x, y, width, height, padding)
        uiu.setColor(1, 1, 1, 1)
        love.graphics.setBlendMode("alpha", "premultiplied")
        love.graphics.draw(canvas, x - padding, y - padding)
        love.graphics.setBlendMode("alpha", "alphamultiply")
    end,

    redraw = function(self)
        if self.redrawID ~= ui.globalReflowID then
            self.redrawID = ui.globalReflowID
            self.cachedCanvas = nil
        elseif ui.repaintAll then
            self.cachedCanvas = nil
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
            if ui.debug.draw == -1 then
                uie.default.draw(self)
            elseif ui.debug.draw == -2 then
                self:__draw(false)
            else
                self:__draw(true)
            end
            local cb = self.drawDebug
            if cb then
                cb(self)
            end
        else
            self:__draw(false)
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
        self:reflow()
        ui.root:recollect()
        return true
    end,

    removeChild = function(self, child)
        if not child then
            return false
        end
        local children = self.children
        for i = 1, #children do
            local c = children[i]
            if c == child then
                table.remove(children, i)
                return true
            end
        end
        self:reflow()
        ui.root:recollect()
        return false
    end,

    removeSelf = function(self)
        local parent = self.parent

        if not parent then
            -- Parent not present, remove on next update.
            self:hook({
                update = function(orig, self, ...)
                    self.update = orig

                    self:removeSelf()

                    if uiu.isCallback(orig) then
                        orig(self, ...)
                    end
                end
            })

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
        if interactive == -2 then
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

        if interactive == -1 then
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

uie.default = uie.default

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
        return v, self
    end

    if key == "get" then
        return styleGet
    end

    local propcache = rawget(self, "__propcache")
    local cached = propcache and propcache[key]
    if cached ~= nil then
        return cached[key], cached
    end

    v, cached = styleGetParent(self, key)
    if v ~= nil then
        if propcache then
            propcache[key] = cached
        end
        return v
    end
end

local mtStyle = {
    __name = "ui.element.style",

    __index = function(self, key)
        local v = styleGet(self, key)
        if v ~= nil then
            return v
        end

        error("Unknown styling property: " .. rawget(self, "el").__type .. " [\"" .. tostring(key) .. "\"]", 2)
    end
}

-- Shared metatable for all element tables.
local mtEl = {
    __name = "ui.element",

    __index = function(self, key)
        local v = rawget(self, key)
        if v ~= nil then
            return v
        end

        if key == "style" then
            return rawget(self, "__style")
        end

        local propcache = rawget(self, "__propcache")
        local cached = propcache[key]
        if cached then
            local ctype = cached.type

            if ctype == "get" then
                return cached.value(self)

            elseif ctype == "field" then
                v = cached.owner[key]
                if v ~= nil then
                    return v
                end

            elseif ctype == "child" then
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

        local keyGet = nil
        if keyType == "string" then
            local Key = key:sub(1, 1):upper() .. key:sub(2)
            keyGet = "get" .. Key
        end

        local default = rawget(self, "__default")
        if keyGet then
            v = default[keyGet]
            if v ~= nil then
                propcache[key] = { type = "get", value = v }
                return v(self)
            end
        end

        v = default[key]
        if v ~= nil then
            propcache[key] = { type = "field", owner = default }
            return v
        end

        local base = default.base
        if base then
            base = uie["__" .. default.base]

            if base then
                if keyGet then
                    v = base[keyGet]
                    if v ~= nil then
                        propcache[key] = { type = "get", value = v }
                        return v(self)
                    end
                end

                v = base[key]
                if v ~= nil then
                    propcache[key] = { type = "field", owner = base }
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
                propcache[key] = { type = "get", value = v }
                return v(self)
            end
        end

        v = uie.default[key]
        if v ~= nil then
            propcache[key] = { type = "field", owner = uie.default }
            return v
        end

        if ui.features.metachildren then
            local children = self.children
            if children then
                if keyType == "string" and key:sub(1, 1) == "_" then
                    local id = key:sub(2)
                    for i = 1, #children do
                        local c = children[i]
                        local cid = c.id
                        if cid and cid == id then
                            propcache[key] = { type = "child", i = i, id = id }
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
            for k, v in pairs(value) do
                style[k] = v
            end
            return self
        end

        local keySet = nil
        if type(key) == "string" then
            keySet = "set" .. key:sub(1, 1):upper() .. key:sub(2)
        end

        if keySet then
            local default = self.__default
            local cb = default[keySet]
            if cb ~= nil then
                return cb(self, value)
            end

            local base = default.base
            if base then
                base = uie["__" .. default.base]

                if base then
                    cb = base[keySet]
                    if cb then
                        return cb(self, value)
                    end
                end
            end

            cb = uie.default[keySet]
            if cb then
                return cb(self, value)
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
            __base = uie["__" .. (default.base or "default")] or uie.default,
            __propcache = {},
            __cached = {
                width = 0,
                height = 0,
                canvas = nil,
                visibleRect = { 0, 0, 0, 0 }
            },
            __collection = ui.root and ui.root.__collection or 0
        }

        el.__style = setmetatable({
            el = el,
            __propcache = {}
        }, mtStyle)
        el.__rawid = tostring(el):sub(8)

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
        default = uie["__" .. (default.base or "default")] or __default
    until default == __default
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
