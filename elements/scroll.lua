local ui = require("ui.main")
local uie = require("ui.elements.main")
local uiu = require("ui.utils")
require("ui.elements.basic")
require("ui.elements.layout")

-- Basic view box.
uie.add("scrollbox", {
    base = "group",
    interactive = 1,

    style = {
        barPadding = 0,
    },

    wiggleroom = 4,

    init = function(self, inner)
        inner.style.radius = 0

        local handleX = uie.scrollhandleX()
        local handleY = uie.scrollhandleY()
        uie.group.init(self, { inner, handleX, handleY })
        self.inner = inner
        self.handleX = handleX
        self.handleY = handleY

        self.clip = true

        self.__dx = 0
        self.__dy = 0
    end,

    calcSize = function(self, width, height)

    end,

    update = function(self, dt)
        local dx = self.__dx
        local dy = self.__dy
        if dx ~= 0 or dy ~= 0 then
            dx = dx * 0.475
            dy = dy * 0.475

            self:onScroll(nil, nil, dx, dy, true)

            if math.abs(dx) < 0.001 then
                dx = 0
            end
            if math.abs(dy) < 0.001 then
                dy = 0
            end

            self.__dx = dx
            self.__dy = dy
        end

        local inner = self.inner
        local origX, origY = inner.x, inner.y
        local x, y = origX, origY

        x = math.max(x + inner.width, self.width) - inner.width
        x = math.min(0, x)

        y = math.max(y + inner.height, self.height) - inner.height
        y = math.min(0, y)

        if x ~= origX or y ~= origY then
            inner.x = x
            inner.y = y
            self:afterScroll()
        end

    end,

    afterScroll = function(self)
        self:repositionChildren()
        self.handleX:repaint()
        self.handleX:layoutLate()
        self.handleY:repaint()
        self.handleY:layoutLate()
        self:repaint()
        ui.root:recollect(false, true)
    end,

    onScroll = function(self, x, y, dx, dy, raw)
        if dx == 0 and dy == 0 then
            return
        end

        local wiggleroom = self.wiggleroom
        local inner = self.inner

        if not raw then
            dx = dx * -32
            dy = dy * -32
            self.__dx = self.__dx + dx
            self.__dy = self.__dy + dy
        end

        if self.handleX.isNeeded then
            local x = -inner.x
            local boxWidth = self.width
            local innerWidth = inner.width
            x = x + dx
            if x < 0 then
                x = 0
            elseif innerWidth < x + boxWidth + wiggleroom then
                x = innerWidth - boxWidth - wiggleroom
            end
            inner.x = uiu.round(-x)
        else
            inner.x = 0
        end

        if self.handleY.isNeeded then
            local y = -inner.y
            local boxHeight = self.height
            local innerHeight = inner.height
            y = y + dy
            if y < 0 then
                y = 0
            elseif innerHeight < y + boxHeight then
                y = innerHeight - boxHeight
            end
            inner.y = uiu.round(-y)
        else
            inner.y = 0
        end

        self:afterScroll()
    end
})


-- Shared scroll bar handle code.
uie.add("scrollhandle", {
    interactive = 1,

    style = {
        color = {},
        border = {},

        thickness = 6,
        radius = 3,

        normalColor = { 0.5, 0.5, 0.5, 0.6 },
        normalBorder = { 0.5, 0.5, 0.5, 1, 1 },

        hoveredColor = { 0.6, 0.6, 0.6, 1 },
        hoveredBorder = { 0.6, 0.6, 0.6, 0.7, 1 },

        pressedColor = { 0.55, 0.55, 0.55, 1 },
        pressedBorder = { 0.55, 0.55, 0.55, 0.7, 1 },

        fadeDuration = 0.2
    },

    init = function(self)
        self.enabled = true
        self._enabled = true
    end,

    revive = function(self)
        self._fadeColorStyle, self._fadeColorPrev, self._fadeColor = {}, false, false
        self._fadeBorderStyle, self._fadeBorderPrev, self._fadeBorder = {}, false, false
    end,

    layoutLateLazy = function(self)
        -- Always reflow this child whenever its parent gets reflowed.
        self:layoutLate()
        self:repaint()
    end,

    update = function(self, dt)
        local enabled = self.enabled
        if enabled == true then
            enabled = self.isNeeded
        end
        self._enabled = enabled

        if not enabled then
            return
        end

        local style = self.style
        local color, colorPrev, colorNext = self._fadeColorStyle, self._fadeColor, nil
        local border, borderPrev, borderNext = self._fadeBorderStyle, self._fadeBorder, nil

        if self.dragged then
            colorNext = style.pressedColor
            borderNext = style.pressedBorder
        elseif self.hovered then
            colorNext = style.hoveredColor
            borderNext = style.hoveredBorder
        else
            colorNext = style.normalColor
            borderNext = style.normalBorder
        end

        local faded = false
        local fadeSwap = uiu.fadeSwap
        faded, style.color, colorPrev, self._fadeColorPrev, self._fadeColor = fadeSwap(faded, color, self._fadeColorPrev, colorPrev, colorNext)
        faded, style.border, borderPrev, self._fadeBorderPrev, self._fadeBorder = fadeSwap(faded, border, self._fadeBorderPrev, borderPrev, borderNext)

        local fadeTime = faded and 0 or self._fadeTime
        local fadeDuration = style.fadeDuration
        if fadeTime < fadeDuration then
            fadeTime = fadeTime + dt
            local f = 1 - fadeTime / fadeDuration
            f = f * f * f * f * f
            f = 1 - f

            faded = false
            local fade = uiu.fade
            faded = fade(faded, f, color, colorPrev, colorNext)
            faded = fade(faded, f, border, borderPrev, borderNext)

            if faded then
                self:repaint()
            end

            self._fadeTime = fadeTime
        end
    end,

    draw = function(self)
        if not self._enabled then
            return
        end

        local radius = self.style.radius
        if uiu.setColor(self.style.color) then
            love.graphics.rectangle("fill", self.screenX, self.screenY, self.width, self.height, radius, radius)
        end
        if uiu.setColor(self.style.border) then
            love.graphics.setLineWidth(self.style.border[5] or 1)
            love.graphics.rectangle("line", self.screenX, self.screenY, self.width, self.height, radius, radius)
        end
    end

})


-- Separate X and Y scrollers.
uie.add("scrollhandleX", {
    base = "scrollhandle",

    recalc = function(self)
        -- Needed to not grow the parent by accident.
        self.realX = 0
        self.realY = 0
        self.width = 0
        self.height = self.style.thickness
    end,

    layoutLate = function(self)
        local thickness = self.style.thickness
        local box = self.parent
        local padding = box.style.barPadding
        local inner = box.inner

        local boxSize = box.width
        local innerSize = inner.width
        local pos = -inner.x

        pos = boxSize * pos / innerSize
        local size = boxSize * boxSize / innerSize
        local tail = pos + size

        if pos < 1 then
            pos = 1
        elseif tail > boxSize - 1 then
            tail = boxSize - 1
            if pos > tail then
                pos = tail - 1
            end
        end

        size = math.max(1, tail - pos - padding * 2)

        if size + 1 + padding * 2 + box.wiggleroom < innerSize then
            self.isNeeded = true
            self.realX = uiu.round(pos) + padding
            self.realY = box.height - thickness - 1 - padding
            self.width = uiu.round(size)
        else
            self.isNeeded = false
            self.realX = 0
            self.realY = 0
            self.width = 0
        end
    end,

    onDrag = function(self, x, y, dx, dy)
        local box = self.parent
        local inner = box.inner
        self.parent:onScroll(x, y, dx * inner.width / box.width, 0, true)
    end
})

uie.add("scrollhandleY", {
    base = "scrollhandle",

    recalc = function(self)
        -- Needed to not grow the parent by accident.
        self.realX = 0
        self.realY = 0
        self.width = self.style.thickness
        self.height = 0
    end,

    layoutLate = function(self)
        local thickness = self.style.thickness
        local box = self.parent
        local padding = box.style.barPadding
        local inner = box.inner

        local boxSize = box.height
        local innerSize = inner.height
        local pos = -inner.y

        pos = boxSize * pos / innerSize
        local size = boxSize * boxSize / innerSize
        local tail = pos + size

        if pos < 1 then
            pos = 1
        elseif tail > boxSize - 1 then
            tail = boxSize - 1
            if pos > tail then
                pos = tail - 1
            end
        end

        size = math.max(1, tail - pos - padding * 2)

        if size + 1 + padding * 2 + box.wiggleroom < innerSize then
            self.isNeeded = true
            self.realX = box.width - thickness - 1 - padding
            self.realY = uiu.round(pos) + padding
            self.height = uiu.round(size)
        else
            self.isNeeded = false
            self.realX = 0
            self.realY = 0
            self.height = 0
        end
    end,

    onDrag = function(self, x, y, dx, dy)
        local box = self.parent
        local inner = box.inner
        self.parent:onScroll(x, y, 0, dy * inner.height / box.height, true)
    end
})

return uie
