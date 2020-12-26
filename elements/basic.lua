local ui = require("ui.main")
local uie = require("ui.elements.main")
local uiu = require("ui.utils")


-- Basic panel with children elements.
uie.add("panel", {
    init = function(self, children)
        children = children or {}
        for i = #children, 1, -1 do
            if not children[i] then
                table.remove(children, i)
            end
        end
        self.children = children
        self.width = -1
        self.height = -1
        self.minWidth = -1
        self.minHeight = -1
        self.maxWidth = -1
        self.maxHeight = -1
        self.forceWidth = -1
        self.forceHeight = -1
        self.clip = true
        self.clipPadding = true
        self._patchName = false
        self._patch = false
    end,

    style = {
        bg = { 0.065, 0.065, 0.065, 0.9 },
        border = { 0, 0, 0, 0 },
        patch = "ui:patches/%s",
        padding = 8,
        radius = 3
    },

    calcSize = function(self, width, height)
        local manualWidth = self.width
        manualWidth = manualWidth ~= -1 and manualWidth or nil
        local manualHeight = self.height
        manualHeight = manualHeight ~= -1 and manualHeight or nil

        local forceWidth
        if self.__autoWidth ~= manualWidth then
            forceWidth = manualWidth or -1
            self.forceWidth = forceWidth
        else
            forceWidth = self.forceWidth or -1
        end

        local forceHeight
        if self.__autoHeight ~= manualHeight then
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

        width = width + self.style.padding * 2
        height = height + self.style.padding * 2

        self.__autoWidth = width
        self.__autoHeight = height
        self.width = width
        self.height = height
    end,

    layoutChildren = function(self)
        local padding = self.style.padding
        local children = self.children
        for i = 1, #children do
            local c = children[i]
            c.parent = self
            c:layoutLazy()
            c.realX = c.x + padding
            c.realY = c.y + padding
        end
    end,

    repositionChildren = function(self)
        local padding = self.style.padding
        local children = self.children
        for i = 1, #children do
            local c = children[i]
            c.parent = self
            c.realX = c.x + padding
            c.realY = c.y + padding
        end
    end,

    draw = function(self)
        local x = self.screenX
        local y = self.screenY
        local w = self.width
        local h = self.height

        local radius
        local bg = self.style.bg
        if bg and #bg ~= 0 and bg[4] ~= 0 and uiu.setColor(bg) then
            radius = self.style.radius
            local patchName = self.style.patch
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
                    padding = self.style.padding
                end
                local scissorX, scissorY = love.graphics.transformPoint(x, y)
                if self.cachedCanvas then
                    love.graphics.setScissor(scissorX - padding, scissorY - padding, w + padding * 2, h + padding * 2)
                else
                    love.graphics.intersectScissor(scissorX - padding, scissorY - padding, w + padding * 2, h + padding * 2)
                end
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


        local border = self.style.border
        if border and #border ~= 0 and border[4] ~= 0 and border[5] ~= 0 and uiu.setColor(border) then
            if not radius then
                radius = self.style.radius
            end
            love.graphics.setLineWidth(border[5] or 1)
            love.graphics.rectangle("line", x, y, w, h, radius, radius)
        end
    end
})


-- Panel which doesn't display as one by default.
uie.add("group", {
    base = "panel",

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
        self.text = text or ""
        self.dynamic = false
        self.wrap = false
        self._color = {}
    end,

    _recolor = function(self, olds)
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

        if type(value) ~= "userdata" then
            if not self._text then
                self._text = love.graphics.newText(self.style.font, self:_recolor(value))
            else
                self._text:set(self:_recolor(value))
            end
        else
            self._text = value
        end

        if not self.dynamic and (self.width ~= math.ceil(self._text:getWidth()) or self.height ~= math.ceil(self._text:getHeight())) then
            self:reflow()
        else
            self:repaint()
        end
    end,

    layoutLateLazy = function(self)
        uie.default.layoutLateLazy(self)

        if self.wrap then
            local prevWidth = self.width
            local prevHeight = self.height

            self._text:set(self:_recolor(uiu.getWrap(self.style.font, self._textStr, self.parent.innerWidth)))

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

    quad = nil,
    scaleX = 1,
    scaleY = 1,
    drawArgs = nil,
    scaleRoundAuto = "auto",

    init = function(self, image)
        self.image = image
    end,

    calcSize = function(self)
        local image = self._image
        local width, height = image:getWidth(), image:getHeight()
        self.width = width * self.scaleX
        self.height = height * self.scaleY
        if self.scaleRoundAuto == "auto" then
            self.width = math.round(self.width)
            self.height = math.round(self.height)
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
            local size = math.round(self.width)
            if size == self.width then
                return
            end

            local scale = size / self._image:getWidth()
            self.scaleY = self.scaleY * (scale / self.scaleX)
            self.scaleX = scale
            self:calcSize()

        elseif mode == "y" or mode == "h" or mode == "height" then
            local size = math.round(self.height)
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
