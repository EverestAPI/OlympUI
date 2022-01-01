local ui = require("ui.main")
local uie = require("ui.elements.main")
local uiu = require("ui.utils")
require("ui.elements.basic")
require("ui.elements.layout")
require("ui.elements.input")

-- Basic window.
uie.add("window", {
    base = "column",
    interactive = 1,

    style = {
        bg = { 0.12, 0.12, 0.12, 1 },
        border = { 0.15, 0.15, 0.15, 1 },
        padding = 1,
        radius = 3,
        spacing = 0
    },

    init = function(self, title, inner)
        inner.style.radius = 0

        local titlebar = uie.paneled.titlebar(title)
        uie.column.init(self, {
            titlebar,
            inner
        })
        self.titlebar = titlebar
        self.inner = inner
    end,

    getTitle = function(self)
        return self.titlebar._title._text
    end,

    setTitle = function(self, value)
        self.titlebar._title.text = value
    end,

    update = function(self, dt)
        local parent = self.parent
        if not parent then
            return
        end

        local x = self.x
        local y = self.y
        local width = self.width
        local height = self.height
        local parentWidth = parent.innerWidth
        local parentHeight = parent.innerHeight

        local max
        max = x + width
        if parentWidth < max then
            x = parentWidth - width
        end
        max = y + height
        if parentHeight < max then
            y = parentHeight - height
        end

        if x < 0 then
            x = 0
        end
        if y < 0 then
            y = 0
        end

        self.x = x
        self.y = y

        self.realX = x
        self.realY = y
    end,

    onPress = function(self, x, y, button, dragging)
        local parent = self.parent
        if not parent then
            return
        end

        local children = parent.children
        if not children then
            return
        end

        for i = 1, #children do
            local c = children[i]
            if c == self then
                table.remove(children, i)
                children[#children + 1] = self
                return
            end
        end
    end
})

uie.add("titlebar", {
    base = "row",
    interactive = 1,

    style = {
        border = { 0, 0, 0, 0 },
        radius = 0,

        focusedBG = { 0.15, 0.15, 0.15, 1 },
        focusedFG = { 1, 1, 1, 1 },

        unfocusedBG = { 0.1, 0.1, 0.1, 1 },
        unfocusedFG = { 0.9, 0.9, 0.9, 0.7 },

        fadeDuration = 0.3
    },

    init = function(self, title, closeable)
        local label
        if title and title.__ui then
            label = title
        else
            label = uie.label(title)
        end

        local children = {
            label
        }
        if closeable then
            children[#children + 1] = uie.buttonClose()
        end

        uie.row.init(self, children)

        self.label = label
    end,

    revive = function(self)
        self._fadeBGStyle, self._fadeBGPrev, self._fadeBG = {}, false, false
        self._fadeFGStyle, self._fadeFGPrev, self._fadeFG = {}, false, false
    end,

    layoutLazy = function(self)
        -- Required to allow the container to shrink again.
        uie.row.layoutLazy(self)
        self.width = 0
    end,

    layoutLateLazy = function(self)
        -- Always reflow this child whenever its parent gets reflowed.
        self:layoutLate()
        self:repaint()
    end,

    layoutLate = function(self)
        local width = self.parent.innerWidth
        self.width = width
        self.innerWidth = width - self.style:getIndex("padding", 1) - self.style:getIndex("padding", 3)
        uie.row.layoutLate(self)
    end,

    update = function(self, dt)
        local style = self.style
        local label = self.label
        local labelStyle = label.style
        local bg, bgPrev, bgNext = self._fadeBGStyle, self._fadeBG, nil
        local fg, fgPrev, fgNext = self._fadeFGStyle, self._fadeFG, nil

        if (self.root and ui.root.focused) or self.parent.focused then
            bgNext = style.focusedBG
            fgNext = style.focusedFG
        else
            bgNext = style.unfocusedBG
            fgNext = style.unfocusedFG
        end

        local faded = false
        local fadeSwap = uiu.fadeSwap
        faded, style.bg, bgPrev, self._fadeBGPrev, self._fadeBG = fadeSwap(faded, bg, self._fadeBGPrev, bgPrev, bgNext)
        faded, labelStyle.color, fgPrev, self._fadeFGPrev, self._fadeFG = fadeSwap(faded, fg, self._fadeFGPrev, fgPrev, fgNext)

        local fadeTime = faded and 0 or self._fadeTime
        local fadeDuration = style.fadeDuration
        if fadeTime < fadeDuration then
            fadeTime = fadeTime + dt
            local f = 1 - fadeTime / fadeDuration
            f = f * f * f * f * f
            f = 1 - f

            faded = false
            local fade = uiu.fade
            faded = fade(faded, f, bg, bgPrev, bgNext)
            faded = fade(faded, f, fg, fgPrev, fgNext)

            if faded then
                self:repaint()
                label:repaint()
            end

            self._fadeTime = fadeTime
        end
    end,

    onPress = function(self, x, y, button, dragging)
        if button == 1 then
            self.dragging = dragging
        end
    end,

    onRelease = function(self, x, y, button, dragging)
        if button == 1 or not dragging then
            self.dragging = dragging
        end
    end,

    onDrag = function(self, x, y, dx, dy)
        local parent = self.parent
        parent.x = parent.x + dx
        parent.y = parent.y + dy
        parent:reflow()
        ui.root:recollect(false, true)
    end
})

uie.add("buttonClose", {
    base = "button",
    id = "close",

    interactive = 1,

    style = {
        padding = 16,
        normalBG = { 0.9, 0.1, 0.2, 0.3 },
        hoveredBG = { 0.85, 0.25, 0.25, 1 },
        pressedBG = { 0.6, 0.08, 0.14, 1 },
    },

    init = function(self)
       uie.button.init(self, uie.image("ui:icons/close"))
    end,

    layoutLazy = function(self)
        uie.button.layoutLazy(self)
        self.realHeight = self.height
        self.height = 0
    end,

    layoutLateLazy = function(self)
        -- Always reflow this child whenever its parent gets reflowed.
        self:layoutLate()
        self:repaint()
    end,

    layoutLate = function(self)
        local parent = self.parent
        self.realX = parent.width - self.width + 1
        self.realY = -1
        self.height = self.realHeight
    end
})

return uie
