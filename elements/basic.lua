local ui = require("ui.main")
local uie = require("ui.elements.main")
local uiu = require("ui.utils")


-- Basic panel with children elements.
uie.add("panel", {
    interactive = 1,

    style = {
        bg = { 0.065, 0.065, 0.065, 0.9 },
        border = { 0, 0, 0, 0 },
        patch = "ui:patches/%s",
        padding = 8,
        radius = 3
    },

    width = -1,
    height = -1,
    minWidth = -1,
    minHeight = -1,
    maxWidth = -1,
    maxHeight = -1,
    autoWidth = -1,
    autoHeight = -1,
    forceWidth = -1,
    forceHeight = -1,
    clip = true,
    clipPadding = true,

    init = function(self, children)
        children = children or {}
        for i = #children, 1, -1 do
            if not children[i] then
                table.remove(children, i)
            end
        end
        self.children = children
        self._patchName = false
        self._patch = false
    end,

    calcSize = function(self, width, height)
        local manualWidth = self.width
        manualWidth = manualWidth ~= -1 and manualWidth or nil
        local manualHeight = self.height
        manualHeight = manualHeight ~= -1 and manualHeight or nil

        local autoWidth = self.autoWidth
        local forceWidth
        if autoWidth == true then
            forceWidth = -1
        elseif autoWidth == false or autoWidth ~= manualWidth then
            forceWidth = manualWidth or -1
            self.forceWidth = forceWidth
        else
            forceWidth = self.forceWidth or -1
        end

        local autoHeight = self.autoHeight
        local forceHeight
        if autoHeight == true then
            forceHeight = -1
        elseif autoHeight == false or autoHeight ~= manualHeight then
            forceHeight = manualHeight or -1
            self.forceHeight = forceHeight
        else
            forceHeight = self.forceHeight or -1
        end

        width = forceWidth >= 0 and forceWidth or width or -1
        height = forceHeight >= 0 and forceHeight or height or -1

        if width < 0 and height < 0 then
            local max = math.max
            local children = self.children
            for i = 1, #children do
                local c = children[i]
                width = max(width, c.x + c.width)
                height = max(height, c.y + c.height)
            end

        elseif width < 0 then
            local max = math.max
            local children = self.children
            for i = 1, #children do
                local c = children[i]
                width = max(width, c.x + c.width)
            end

        elseif height < 0 then
            local max = math.max
            local children = self.children
            for i = 1, #children do
                local c = children[i]
                height = max(height, c.y + c.height)
            end
        end

        if self.minWidth >= 0 and width < self.minWidth then
            width = self.minWidth
        end
        if self.maxWidth >= 0 and self.maxWidth < width then
            width = self.maxWidth
        end

        if self.minHeight >= 0 and height < self.minHeight then
            height = self.minHeight
        end
        if self.maxHeight >= 0 and self.maxHeight < height then
            height = self.maxHeight
        end

        self.innerWidth = width
        self.innerHeight = height

        local style = self.style
        width = width + style:getIndex("padding", 1) + style:getIndex("padding", 3)
        height = height + style:getIndex("padding", 2) + style:getIndex("padding", 4)

        self.autoWidth = width
        self.autoHeight = height
        self.width = width
        self.height = height
    end,

    layoutChildren = function(self)
        local style = self.style
        local paddingL, paddingT = style:getIndex("padding", 1), style:getIndex("padding", 3)
        local children = self.children
        for i = 1, #children do
            local c = children[i]
            c.parent = self
            c:layoutLazy()
            c.realX = c.x + paddingL
            c.realY = c.y + paddingT
        end
    end,

    repositionChildren = function(self)
        local style = self.style
        local paddingL, paddingT = style:getIndex("padding", 1), style:getIndex("padding", 3)
        local children = self.children
        for i = 1, #children do
            local c = children[i]
            c.parent = self
            c.realX = c.x + paddingL
            c.realY = c.y + paddingT
        end
    end,

    draw = function(self)
        local x = self.screenX
        local y = self.screenY
        local w = self.width
        local h = self.height
        local style = self.style

        local radius
        local bg = style.bg
        if bg and bg[4] and bg[4] ~= 0 and uiu.setColor(bg) then
            radius = style.radius
            local patchName = style.patch
            local patch
            if patchName == self._patchName then
                patch = self._patch
            else
                if patchName then
                    patch = uiu.patch(patchName, self.__types)
                end
                self._patchName = patchName
                self._patch = patch
            end

            if patch then
                patch:draw(x, y, w, h, true)
            else
                love.graphics.rectangle("fill", x, y, w, h, radius, radius)
            end
        end

        if w >= 0 and h >= 0 then
            local sX, sY, sW, sH
            local clip = self.clip -- and not self.cachedCanvas
            if clip then
                sX, sY, sW, sH = love.graphics.getScissor()
                local padding = self.clipPadding
                if padding == true then
                    padding = style.padding
                end
                local paddingL, paddingT, paddingR, paddingB
                if type(padding) == "table" then
                    paddingL, paddingT, paddingR, paddingB = padding[1], padding[2], padding[3], padding[4]
                else
                    paddingL, paddingT, paddingR, paddingB = padding, padding, padding, padding
                end
                local scissorX, scissorY = love.graphics.transformPoint(x, y)
                love.graphics.intersectScissor(scissorX - paddingL, scissorY - paddingT, w + paddingL + paddingR, h + paddingT + paddingB)
            end

            local children = self.children
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

            if clip then
                love.graphics.setScissor(sX, sY, sW, sH)
            end
        end


        local border = style.border
        if border and border[4] and border[4] ~= 0 and border[5] ~= 0 and uiu.setColor(border) then
            if not radius then
                radius = style.radius
            end
            love.graphics.setLineWidth(border[5] or 1)
            love.graphics.rectangle("line", x, y, w, h, radius, radius)
        end
    end
})

-- Helper to allow quick paneling of group elements (f.e. row, column).
uie.paneled = setmetatable({}, {
    __index = function(self, key)
        return function(...)
            return self(uie[key](...))
        end
    end,
    __call = function(self, el)
        el.__base = uie.panel
        el.__default = uie.panel.__default
        return el
    end
})


-- Panel which doesn't display as one by default.
uie.add("group", {
    base = "panel",

    interactive = 0,

    style = {
        bg = {},
        border = {},
        padding = 0,
        radius = 0
    },

    init = function(self, ...)
        uie.panel.init(self, ...)
        self.clip = false
    end
})


-- Basic label.
uie.add("label", {
    style = {
        color = { 1, 1, 1, 1 },
        font = false
    },

    init = function(self, text, font)
        self.style.font = font or uie.label.__default.style.font or love.graphics.getFont()
        self._textStr = false
        self._text = false
        self.dynamic = false
        self.wrap = false
        self._error = false
        self._color = {}
        self.text = text or ""
    end,

    recolor = function(self, olds)
        local color = self.style.color
        if #color == 0 then
            return olds
        end

        if type(olds) == "string" then
            return { color, olds }
        end

        local news = {}

        for i = 1, #olds do
            local old = olds[i]
            local new = old
            if #old == 3 and old[1] == 1 and old[2] == 1 and old[3] == 1 then
                new = {}
                new[1] = color[1]
                new[2] = color[2]
                new[3] = color[3]
            elseif #old == 4 and old[1] == 1 and old[2] == 1 and old[3] == 1 then
                new = {}
                new[1] = color[1]
                new[2] = color[2]
                new[3] = color[3]
                new[4] = old[4] * color[4]
            end
            news[i] = new
        end

        return news
    end,

    getText = function(self)
        return self._textStr
    end,

    setText = function(self, value)
        if value == self._textStr then
            return
        end
        self._textStr = value

        self:forceText(value)

        if not self.dynamic and (self.width ~= math.ceil(self._text:getWidth()) or self.height ~= math.ceil(self._text:getHeight())) then
            self:reflow()
        else
            self:repaint()
        end
    end,

    forceText = function(self, value)
        self._error = false

        if type(value) == "userdata" then
            self._text = value

        else
            local status, err = pcall(function()
                if not self._text then
                    self._text = love.graphics.newText(self.style.font, self:recolor(value))
                else
                    self._text:set(self:recolor(value))
                end
            end)

            if not status then
                if type(value) ~= "string" or not value:match("error while updating text") then
                    print("[olympui]", "error while updating text", err, "\n", value)
                end
                self._error = err or true
                self._text = love.graphics.newText(love.graphics.getFont(), "ERROR!")
            end
        end
    end,

    layoutLateLazy = function(self)
        uie.default.layoutLateLazy(self)

        if self.wrap then
            local prevWidth = self.width
            local prevHeight = self.height

            self:forceText(uiu.getWrap(self.style.font, self._textStr, self.parent.innerWidth))

            local width = self:calcWidth()
            self.width = width
            local height = self:calcHeight()
            self.height = height

            if width ~= prevWidth or height ~= prevHeight then
                self.parent:reflow()
            end
        end
    end,

    calcWidth = function(self)
        return math.ceil(self._text:getWidth())
    end,

    calcHeight = function(self)
        local height = math.ceil(self._text:getHeight())
        if height == 0 then
            return math.ceil(self.style.font:getHeight(" "))
        end
        return height
    end,

    draw = function(self)
        if self._error then
            uiu.setColor(1, 0, 0, 1)
            love.graphics.rectangle("fill", self.screenX - 2, self.screenY - 2, self.width + 4, self.height + 4)

            uiu.setColor(1, 1, 1, 1)
            return love.graphics.draw(self._text, self.screenX, self.screenY)
        end

        local color = self.style.color
        if #color == 0 then
            return
        end

        local colorLast = self._color
        if colorLast[1] ~= color[1] or colorLast[2] ~= color[2] or colorLast[3] ~= color[3] or colorLast[4] ~= color[4] then
            colorLast[1] = color[1]
            colorLast[2] = color[2]
            colorLast[3] = color[3]
            colorLast[4] = color[4]
            local text = self._textStr
            self._textStr = ""
            self.text = text
        end

        uiu.setColor(1, 1, 1, 1)
        return love.graphics.draw(self._text, self.screenX, self.screenY)
    end
})


-- Basic image.
uie.add("image", {
    cacheable = false,

    style = {
        color = { 1, 1, 1, 1 }
    },

    quad = false,
    scaleX = 1,
    scaleY = 1,
    drawArgs = false,
    scaleRoundAuto = "auto",

    init = function(self, image, quad)
        self._image = false
        self.image = image
        self.quad = quad or false
    end,

    calcSize = function(self)
        local width, height
        local image = self._image
        local quad = self.quad

        if quad then
            local quadX, quadY, quadWidth, quadHeight = quad:getViewport()
            width, height = quadWidth, quadHeight

        else
            width, height = image:getDimensions()
        end

        self.width = width * self.scaleX
        self.height = height * self.scaleY
        if self.scaleRoundAuto == "auto" then
            self.width = uiu.round(self.width)
            self.height = uiu.round(self.height)
        end
    end,

    getScale = function(self)
        return self.scaleX, self.scaleY
    end,

    setScale = function(self, sx, sy)
        self.scaleX = sx
        self.scaleY = sy or sx
        if self.scaleRoundAuto then
            self:scaleRound()
        end
        return self
    end,

    getImage = function(self)
        return self._image
    end,

    setImage = function(self, image)
        if type(image) == "string" then
            self.id = image
            image = uiu.image(image)
        end
        if self._image == image then
            return
        end
        self._image = image
        self:reflow()
    end,

    scaleRound = function(self, mode)
        if not mode then
            mode = self.scaleRoundAuto
        end

        self:calcSize()

        if mode == "x" or mode == "w" or mode == "width" then
            local size = uiu.round(self.width)
            if size == self.width then
                return
            end

            local scale = size / self._image:getWidth()
            self.scaleY = self.scaleY * (scale / self.scaleX)
            self.scaleX = scale
            self:calcSize()

        elseif mode == "y" or mode == "h" or mode == "height" then
            local size = uiu.round(self.height)
            if size == self.height then
                return
            end

            local scale = size / self._image:getHeight()
            self.scaleX = self.scaleX * (scale / self.scaleY)
            self.scaleY = scale
            self:calcSize()

        elseif mode == "auto" then
            -- Handled in calcSize, should probably be handled here instead?

        else
            error([[scaleRound mode must be one of the following: "x" "w" "width" "y" "h" "height"]])
        end

    end,

    draw = function(self)
        if not uiu.setColor(self.style.color) then
            return
        end

        local drawArgs = self.drawArgs
        if drawArgs then
            love.graphics.draw(self._image, table.unpack(drawArgs))

        else
            local quad = self.quad
            if quad then
                love.graphics.draw(self._image, quad, self.screenX, self.screenY, 0, self.scaleX, self.scaleY)
            else
                love.graphics.draw(self._image, self.screenX, self.screenY, 0, self.scaleX, self.scaleY)
            end
        end
    end
})


-- Basic icon - basically image with separate style.
uie.add("icon", {
    base = "image",

    style = {
        color = { 1, 1, 1, 1 }
    }
})


return uie
