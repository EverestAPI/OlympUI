local ui = require("ui.main")
local uie = require("ui.elements.main")
local uiu = require("ui.utils")
require("ui.elements.basic")
require("ui.elements.layout")

-- Basic button, behaving like a row with a label.
uie.add("button", {
    base = "row",

    style = {
        padding = 8,
        spacing = 4,

        normalBG = { 0.08, 0.08, 0.08, 0.6 },
        normalFG = { 1, 1, 1, 1 },
        normalBorder = { 0, 0, 0, 0 },

        disabledBG = { 0.05, 0.05, 0.05, 0.7 },
        disabledFG = { 0.7, 0.7, 0.7, 0.7 },
        disabledBorder = { 0, 0, 0, 0 },

        hoveredBG = { 0.36, 0.36, 0.36, 0.7 },
        hoveredFG = { 1, 1, 1, 1 },
        hoveredBorder = { 0, 0, 0, 0 },

        pressedBG = { 0.17, 0.17, 0.17, 0.7 },
        pressedFG = { 1, 1, 1, 1 },
        pressedBorder = { 0, 0, 0, 0 },

        fadeDuration = 0.2
    },

    init = function(self, label, cb)
        if not label or not label.__ui then
            label = uie.label(label)
        end
        uie.__row.init(self, { label:as("label") })
        self.cb = cb
        self.enabled = true
        self.style.bg = {}
        self._label.style.color = {}
        self.style.border = {}
    end,

    getEnabled = function(self)
        return self.__enabled
    end,

    setEnabled = function(self, value)
        self.__enabled = value
        self.interactive = value and 1 or -1
    end,

    getText = function(self)
        return self._label.text
    end,

    setText = function(self, value)
        self._label.text = value
    end,

    update = function(self)
        local style = self.style
        local label = self._label
        local labelStyle = label.style
        local bgPrev = style.bg
        local fgPrev = labelStyle.color
        local borderPrev = style.border
        local bg = bgPrev
        local fg = fgPrev
        local border = borderPrev

        if not self.enabled then
            bg = style.disabledBG
            fg = style.disabledFG
            border = style.disabledBorder
        elseif self.pressed then
            bg = style.pressedBG
            fg = style.pressedFG
            border = style.pressedBorder
        elseif self.hovered then
            bg = style.hoveredBG
            fg = style.hoveredFG
            border = style.hoveredBorder
        else
            bg = style.normalBG
            fg = style.normalFG
            border = style.normalBorder
        end

        local fadeTime

        if self.__bg ~= bg or self.__fg ~= fg or self.__border ~= border then
            self.__bg = bg
            self.__fg = fg
            self.__border = border
            fadeTime = 0
        else
            fadeTime = self.__fadeTime
        end

        local fadeDuration = style.fadeDuration
        if fadeTime < fadeDuration then
            fadeTime = math.min(fadeDuration, fadeTime + ui.delta)
            local f = fadeTime / fadeDuration

            if #bgPrev == 0 then
                f = 1
            end

            if f < 1 then
                bgPrev[1] = bgPrev[1] + (bg[1] - bgPrev[1]) * f
                bgPrev[2] = bgPrev[2] + (bg[2] - bgPrev[2]) * f
                bgPrev[3] = bgPrev[3] + (bg[3] - bgPrev[3]) * f
                bgPrev[4] = bgPrev[4] + (bg[4] - bgPrev[4]) * f

                fgPrev[1] = fgPrev[1] + (fg[1] - fgPrev[1]) * f
                fgPrev[2] = fgPrev[2] + (fg[2] - fgPrev[2]) * f
                fgPrev[3] = fgPrev[3] + (fg[3] - fgPrev[3]) * f
                fgPrev[4] = fgPrev[4] + (fg[4] - fgPrev[4]) * f

                borderPrev[1] = borderPrev[1] + (border[1] - borderPrev[1]) * f
                borderPrev[2] = borderPrev[2] + (border[2] - borderPrev[2]) * f
                borderPrev[3] = borderPrev[3] + (border[3] - borderPrev[3]) * f
                borderPrev[4] = borderPrev[4] + (border[4] - borderPrev[4]) * f

            else
                bgPrev[1] = bg[1]
                bgPrev[2] = bg[2]
                bgPrev[3] = bg[3]
                bgPrev[4] = bg[4]

                fgPrev[1] = fg[1]
                fgPrev[2] = fg[2]
                fgPrev[3] = fg[3]
                fgPrev[4] = fg[4]

                borderPrev[1] = border[1]
                borderPrev[2] = border[2]
                borderPrev[3] = border[3]
                borderPrev[4] = border[4]
            end

            self:repaint()
        end

        self.__fadeTime = fadeTime
    end,

    onClick = function(self, x, y, button)
        local cb = self.cb
        if cb and button == 1 then
            cb(self, x, y, button)
        end
    end
})


-- Basic text input, behaving like a row with a label.
uie.add("field", {
    base = "row",

    style = {
        padding = 8,
        spacing = 4,

        normalBG = { 0.9, 0.9, 0.9, 0.8 },
        normalFG = { 0, 0, 0, 0.8 },
        normalBorder = { 0.08, 0.08, 0.08, 0.6 },

        disabledBG = { 0.5, 0.5, 0.5, 0.7 },
        disabledFG = { 0, 0, 0, 0.7 },
        disabledBorder = { 0, 0, 0, 0.7 },

        focusedBG = { 1, 1, 1, 0.9 },
        focusedFG = { 0, 0, 0, 0.9 },
        focusedBorder = { 0, 0, 0, 0.9 },

        fadeDuration = 0.2
    },

    init = function(self, label, cb)
        if not label or not label.__ui then
            label = uie.label(label)
        end
        uie.__row.init(self, { label:as("label") })
        self.cb = cb
        self.enabled = true
        self.style.bg = {}
        self._label.style.color = {}
        self.style.border = {}
    end,

    getEnabled = function(self)
        return self.__enabled
    end,

    setEnabled = function(self, value)
        self.__enabled = value
        self.interactive = value and 1 or -1
    end,

    getText = function(self)
        return self._label.text
    end,

    setText = function(self, value)
        self._label.text = value
    end,

    update = function(self)
        local style = self.style
        local label = self._label
        local labelStyle = label.style
        local bgPrev = style.bg
        local fgPrev = labelStyle.color
        local borderPrev = style.border
        local bg = bgPrev
        local fg = fgPrev
        local border = borderPrev

        if not self.enabled then
            bg = style.disabledBG
            fg = style.disabledFG
            border = style.disabledBorder
        elseif self.focused then
            bg = style.focusedBG
            fg = style.focusedFG
            border = style.focusedBorder
        else
            bg = style.normalBG
            fg = style.normalFG
            border = style.normalBorder
        end

        local fadeTime

        if self.__bg ~= bg or self.__fg ~= fg or self.__border ~= border then
            self.__bg = bg
            self.__fg = fg
            self.__border = border
            fadeTime = 0
        else
            fadeTime = self.__fadeTime
        end

        local fadeDuration = style.fadeDuration
        if fadeTime < fadeDuration then
            fadeTime = math.min(fadeDuration, fadeTime + ui.delta)
            local f = fadeTime / fadeDuration

            if #bgPrev == 0 then
                f = 1
            end

            if f < 1 then
                bgPrev[1] = bgPrev[1] + (bg[1] - bgPrev[1]) * f
                bgPrev[2] = bgPrev[2] + (bg[2] - bgPrev[2]) * f
                bgPrev[3] = bgPrev[3] + (bg[3] - bgPrev[3]) * f
                bgPrev[4] = bgPrev[4] + (bg[4] - bgPrev[4]) * f

                fgPrev[1] = fgPrev[1] + (fg[1] - fgPrev[1]) * f
                fgPrev[2] = fgPrev[2] + (fg[2] - fgPrev[2]) * f
                fgPrev[3] = fgPrev[3] + (fg[3] - fgPrev[3]) * f
                fgPrev[4] = fgPrev[4] + (fg[4] - fgPrev[4]) * f

                borderPrev[1] = borderPrev[1] + (border[1] - borderPrev[1]) * f
                borderPrev[2] = borderPrev[2] + (border[2] - borderPrev[2]) * f
                borderPrev[3] = borderPrev[3] + (border[3] - borderPrev[3]) * f
                borderPrev[4] = borderPrev[4] + (border[4] - borderPrev[4]) * f

            else
                bgPrev[1] = bg[1]
                bgPrev[2] = bg[2]
                bgPrev[3] = bg[3]
                bgPrev[4] = bg[4]

                fgPrev[1] = fg[1]
                fgPrev[2] = fg[2]
                fgPrev[3] = fg[3]
                fgPrev[4] = fg[4]

                borderPrev[1] = border[1]
                borderPrev[2] = border[2]
                borderPrev[3] = border[3]
                borderPrev[4] = border[4]
            end
 
            self:repaint()
        end

        self.__fadeTime = fadeTime
    end,

    onClick = function(self, x, y, button)
        local cb = self.cb
        if cb and button == 1 then
            cb(self, x, y, button)
        end
    end
})


-- Basic list, consisting of multiple list items.
uie.add("list", {
    base = "column",
    cacheable = false,

    isList = true,
    grow = true,

    style = {
        padding = 0,
        spacing = 1,
        -- border = { 0.3, 0.3, 0.3, 1 }
    },

    init = function(self, items, cb)
        uie.__column.init(self, uiu.map(items, uie.listItem))
        self.cb = cb
        self.enabled = true
        self.selected = false
    end,

    layoutLateLazy = function(self)
        self:layoutLate()
    end,

    layoutLateChildren = function(self)
        local children = self.children
        if children then
            local width = self.innerWidth
            if self.grow then
                for i = 1, #children do
                    local c = children[i]
                    width = math.max(width, c.width)
                end
            end
            for i = 1, #children do
                local c = children[i]
                c.parent = self
                c.width = width
                c:layoutLateLazy()
            end
        end
    end,
})

uie.add("listH", {
    base = "row",
    cacheable = false,

    isList = true,
    grow = true,

    style = uie.__list.__default.style,

    init = function(self, items, cb)
        uie.__row.init(self, uiu.map(items, uie.listItem))
        self.cb = cb
        self.enabled = true
        self.selected = false
    end,

    layoutLateLazy = function(self)
        self:layoutLate()
    end,

    layoutLateChildren = function(self)
        local children = self.children
        if children then
            local height = self.innerHeight
            if self.grow then
                for i = 1, #children do
                    local c = children[i]
                    height = math.max(height, c.height)
                end
            end
            for i = 1, #children do
                local c = children[i]
                c.parent = self
                c.height = height
                c:layoutLateLazy()
            end
        end
    end,
})

uie.add("listItem", {
    base = "row",
    interactive = 1,
    cacheable = false,

    style = {
        padding = 4,
        spacing = 4,
        radius = 0,

        normalBG = { 0.08, 0.08, 0.08, 0.6 },
        normalFG = { 1, 1, 1, 1 },
        normalBorder = { 0, 0, 0, 0 },

        disabledBG = { 0.05, 0.05, 0.05, 1 },
        disabledFG = { 0.7, 0.7, 0.7, 0.7 },
        disabledBorder = { 0, 0, 0, 0 },

        hoveredBG = { 0.36, 0.36, 0.36, 0.7 },
        hoveredFG = { 1, 1, 1, 1 },
        hoveredBorder = { 0, 0, 0, 0 },

        pressedBG = { 0.1, 0.3, 0.6, 0.7 },
        pressedFG = { 1, 1, 1, 1 },
        pressedBorder = { 0, 0, 0, 0 },

        selectedBG = { 0.2, 0.5, 0.7, 0.7 },
        selectedFG = { 1, 1, 1, 1 },
        selectedBorder = { 0, 0, 0, 0 },

        fadeDuration = 0.2
    },

    init = function(self, text, data)
        if text and text.text and text.data then
            data = text.data
            text = text.text
        end
        uie.__row.init(self, { uie.label(text):as("label") })
        self.data = data
        self.enabled = true
        self.style.bg = {}
        self._label.style.color = {}
        self.style.border = {}
    end,

    getText = function(self)
        return self._label.text
    end,

    setText = function(self, value)
        self._label.text = value
    end,

    getEnabled = function(self)
        if not self.parent.isList then
            return self.__enabled
        end
        return self.parent.enabled and self.__enabled
    end,

    setEnabled = function(self, value)
        self.__enabled = value
    end,

    getInteractive = function(self)
        if not self.parent.isList then
            return self.__enabled and 1 or -1
        end
        return self.parent.enabled and self.__enabled and 1 or -1
    end,

    getSelected = function(self)
        if not self.parent.isList then
            return self.__selected
        end
        return self.parent.selected == self
    end,

    setSelected = function(self, value)
        if not self.parent.isList then
            self.__selected = value
            return
        end
        self.parent.selected = (value and self or nil)
    end,

    update = function(self)
        local style = self.style
        local label = self._label
        local labelStyle = label.style
        local bgPrev = style.bg
        local fgPrev = labelStyle.color
        local borderPrev = style.border
        local bg = bgPrev
        local fg = fgPrev
        local border = borderPrev

        if not self.enabled then
            bg = style.disabledBG
            fg = style.disabledFG
            border = style.disabledBorder
        elseif self.pressed then
            bg = style.pressedBG
            fg = style.pressedFG
            border = style.pressedBorder
        elseif self.selected then
            bg = style.selectedBG
            fg = style.selectedFG
            border = style.selectedBorder
        elseif self.hovered then
            bg = style.hoveredBG
            fg = style.hoveredFG
            border = style.hoveredBorder
        else
            bg = style.normalBG
            fg = style.normalFG
            border = style.normalBorder
        end

        local fadeTime

        if self.__bg ~= bg or self.__fg ~= fg or self.__border ~= border then
            self.__bg = bg
            self.__fg = fg
            self.__border = border
            fadeTime = 0
        else
            fadeTime = self.__fadeTime
        end

        local fadeDuration = style.fadeDuration
        if fadeTime < fadeDuration then
            fadeTime = math.min(fadeDuration, fadeTime + ui.delta)
            local f = fadeTime / fadeDuration

            if #bgPrev == 0 then
                f = 1
            end

            if f < 1 then
                bgPrev[1] = bgPrev[1] + (bg[1] - bgPrev[1]) * f
                bgPrev[2] = bgPrev[2] + (bg[2] - bgPrev[2]) * f
                bgPrev[3] = bgPrev[3] + (bg[3] - bgPrev[3]) * f
                bgPrev[4] = bgPrev[4] + (bg[4] - bgPrev[4]) * f

                fgPrev[1] = fgPrev[1] + (fg[1] - fgPrev[1]) * f
                fgPrev[2] = fgPrev[2] + (fg[2] - fgPrev[2]) * f
                fgPrev[3] = fgPrev[3] + (fg[3] - fgPrev[3]) * f
                fgPrev[4] = fgPrev[4] + (fg[4] - fgPrev[4]) * f

                borderPrev[1] = borderPrev[1] + (border[1] - borderPrev[1]) * f
                borderPrev[2] = borderPrev[2] + (border[2] - borderPrev[2]) * f
                borderPrev[3] = borderPrev[3] + (border[3] - borderPrev[3]) * f
                borderPrev[4] = borderPrev[4] + (border[4] - borderPrev[4]) * f

            else
                bgPrev[1] = bg[1]
                bgPrev[2] = bg[2]
                bgPrev[3] = bg[3]
                bgPrev[4] = bg[4]

                fgPrev[1] = fg[1]
                fgPrev[2] = fg[2]
                fgPrev[3] = fg[3]
                fgPrev[4] = fg[4]

                borderPrev[1] = border[1]
                borderPrev[2] = border[2]
                borderPrev[3] = border[3]
                borderPrev[4] = border[4]
            end

            self:repaint()
        end

        self.__fadeTime = fadeTime
    end,

    onClick = function(self, x, y, button)
        if button == 1 then
            local parent = self.parent
            if parent.isList then
                self.selected = true
            end
            local cb = parent.cb
            if cb then
                cb(parent, self.data or self.text)
            end
        end
    end
})


-- A top menu bar.
uie.add("topbar", {
    base = "row",
    clip = false,
    interactive = 2,

    style = {
        padding = 0,
        spacing = 1
    },

    init = function(self, list)
        uie.__row.init(self, uiu.map(list, uie.__menuItem.map))
        self:with(uiu.fillWidth)
    end
})


-- Menu items in the top bar, behaving similarly to list items.
uie.add("menuItem", {
    base = "listItem",
    clip = false,

    init = function(self, text, data)
        uie.__listItem.init(self, text, data)
    end,

    map = function(item)
        local text, data = table.unpack(item)

        if not text then
            return uie.menuItem(""):with({ interactive = -1, height = 2, style = { padding = 0 } }) -- TODO: Divider!
        end

        return uie.menuItem(text, data)
    end,

    cb = function(self)
        local data = self.data
        if not data then
            return
        end

        if uiu.isCallback(data) then
            data(self)
            return
        end

        local submenu = self.submenu
        if not self.submenu then
            submenu = uie.menuItemSubmenu(uiu.map(data, uie.__menuItem.map))
            self.submenu = submenu
        end

        if self.parent:is("topbar") then
            submenu.x = self.screenX
            submenu.y = self.screenY + self.height + self.parent.style.spacing
        else
            submenu.x = self.screenX + self.width + self.parent.style.spacing
            submenu.y = self.screenY
        end

        table.insert(ui.root.children, submenu)
        ui.root:recollect()
        ui.root:reflow()
    end,

    onClick = function(self, x, y, button)
        if button == 1 then
            local cb = self.cb
            if cb then
                cb(self)
            end
        end
    end
})


uie.add("menuItemSubmenu", {
    base = "column",
    clip = false,

    style = {
        padding = 0,
        spacing = 1
    },

    layoutChildren = function(self)
        local padding = self.style.padding
        local y = padding
        local spacing = self.style.spacing
        local maxWidth = 0
        local children = self.children
        if children then
            for i = 1, #children do
                local c = children[i]
                c.parent = self
                c:layoutLazy()
                y = y + c.y
                c.realX = c.x + padding
                c.realY = y
                y = y + c.height + spacing
                maxWidth = math.max(maxWidth, c.width)
            end
        end
        self.width = maxWidth + self.style.padding * 2
        self.innerWidth = maxWidth
        self.__maxWidth = maxWidth
    end,
    
    layoutLateChildren = function(self)
        local children = self.children
        local width = self.__maxWidth
        if children then
            for i = 1, #children do
                local c = children[i]
                c.parent = self
                c.width = width
                c:layoutLateLazy()
            end
        end
    end,
})


return uie
