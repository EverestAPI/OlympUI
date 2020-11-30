local ui = require("ui.main")
local uie = require("ui.elements.main")
local uiu = require("ui.utils")
local utf8 = require("utf8")
require("ui.elements.basic")
require("ui.elements.layout")

-- Basic button, behaving like a row with a label.
uie.add("button", {
    base = "row",

    style = {
        padding = 8,
        spacing = 4,

        normalBG = { 0.13, 0.13, 0.13, 0.8 },
        normalFG = { 1, 1, 1, 1 },
        normalBorder = { 0, 0, 0, 0, 1 },

        disabledBG = { 0.05, 0.05, 0.05, 0.7 },
        disabledFG = { 0.7, 0.7, 0.7, 0.7 },
        disabledBorder = { 0, 0, 0, 0, 1 },

        hoveredBG = { 0.36, 0.36, 0.36, 0.7 },
        hoveredFG = { 1, 1, 1, 1 },
        hoveredBorder = { 0, 0, 0, 0, 1 },

        pressedBG = { 0.2, 0.2, 0.2, 0.7 },
        pressedFG = { 1, 1, 1, 1 },
        pressedBorder = { 0, 0, 0, 0, 1 },

        fadeDuration = 0.2
    },

    init = function(self, label, cb)
        if not label or not label.__ui then
            label = uie.label(label)
        end
        uie.__row.init(self, { label })
        self.label = label
        self.cb = cb
        self.enabled = true
        self.style.bg = {}
        self.label.style.color = {}
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
        return self.label.text
    end,

    setText = function(self, value)
        self.label.text = value
    end,

    update = function(self, dt)
        local style = self.style
        local label = self.label
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
            fadeTime = fadeTime + dt

            if #bgPrev ~= 0 and fadeTime < fadeDuration then
                local f = fadeTime / fadeDuration

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
                borderPrev[5] = borderPrev[5] + (border[5] - borderPrev[5]) * f

            else
                fadeTime = fadeDuration

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
                borderPrev[5] = border[5]
            end

            self:repaint()
            label:repaint()
        end

        self.__fadeTime = fadeTime
    end,

    onClick = function(self, x, y, button)
        local cb = self.cb
        if self.enabled and cb and button == 1 then
            cb(self, x, y, button)
        end
    end
})


-- Basic text input, behaving like a row with a label.
-- TODO: Implement oversize text handling
-- TODO: Implement multiline variant
uie.add("field", {
    base = "row",

    style = {
        padding = 8,
        spacing = 4,

        normalBG = { 0.95, 0.95, 0.95, 0.9 },
        normalFG = { 0, 0, 0, 0.8, 0 },
        normalBorder = { 0.08, 0.08, 0.08, 0.6, 1 },

        disabledBG = { 0.5, 0.5, 0.5, 0.7 },
        disabledFG = { 0, 0, 0, 0.7, 0 },
        disabledBorder = { 0, 0, 0, 0.7, 1 },

        focusedBG = { 1, 1, 1, 0.9 },
        focusedFG = { 0, 0, 0, 0.9, 1 },
        focusedBorder = { 0, 0, 0, 0.9, 1 },

        fadeDuration = 0.2
    },

    init = function(self, text, cb)
        self.index = 0
        local label = uie.label(text)
        uie.__row.init(self, { label })
        self.label = label
        self.cb = cb
        self.enabled = true
        self.style.bg = {}
        self.label.style.color = {}
        self.style.border = {}
        self.blinkTime = 0
    end,

    getEnabled = function(self)
        return self.__enabled
    end,

    setEnabled = function(self, value)
        self.__enabled = value
        self.interactive = value and 1 or -1
    end,

    getText = function(self)
        return self.label.text
    end,

    setText = function(self, value)
        local prev = self.label.text
        self.label.text = value
        local cb = self.cb
        if cb then
            cb(value, prev)
        end
    end,

    update = function(self, dt)
        local style = self.style
        local label = self.label
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
            fadeTime = fadeTime + dt

            if #bgPrev ~= 0 and fadeTime < fadeDuration then
                local f = fadeTime / fadeDuration

                bgPrev[1] = bgPrev[1] + (bg[1] - bgPrev[1]) * f
                bgPrev[2] = bgPrev[2] + (bg[2] - bgPrev[2]) * f
                bgPrev[3] = bgPrev[3] + (bg[3] - bgPrev[3]) * f
                bgPrev[4] = bgPrev[4] + (bg[4] - bgPrev[4]) * f

                fgPrev[1] = fgPrev[1] + (fg[1] - fgPrev[1]) * f
                fgPrev[2] = fgPrev[2] + (fg[2] - fgPrev[2]) * f
                fgPrev[3] = fgPrev[3] + (fg[3] - fgPrev[3]) * f
                fgPrev[4] = fgPrev[4] + (fg[4] - fgPrev[4]) * f
                fgPrev[5] = fgPrev[5] + (fg[5] - fgPrev[5]) * f

                borderPrev[1] = borderPrev[1] + (border[1] - borderPrev[1]) * f
                borderPrev[2] = borderPrev[2] + (border[2] - borderPrev[2]) * f
                borderPrev[3] = borderPrev[3] + (border[3] - borderPrev[3]) * f
                borderPrev[4] = borderPrev[4] + (border[4] - borderPrev[4]) * f
                borderPrev[5] = borderPrev[5] + (border[5] - borderPrev[5]) * f

            else
                fadeTime = fadeDuration

                bgPrev[1] = bg[1]
                bgPrev[2] = bg[2]
                bgPrev[3] = bg[3]
                bgPrev[4] = bg[4]

                fgPrev[1] = fg[1]
                fgPrev[2] = fg[2]
                fgPrev[3] = fg[3]
                fgPrev[4] = fg[4]
                fgPrev[5] = fg[5]

                borderPrev[1] = border[1]
                borderPrev[2] = border[2]
                borderPrev[3] = border[3]
                borderPrev[4] = border[4]
                borderPrev[5] = border[5]
            end

            self:repaint()
            label:repaint()
        end

        local blinkTimePrev = self.blinkTime
        local blinkTime = (blinkTimePrev + dt) % 1
        self.blinkTime = blinkTime
        if blinkTimePrev < 0.5 and blinkTime >= 0.5 or blinkTimePrev >= 0.5 and blinkTime < 0.5 then
            self:repaint()
        end

        self.__fadeTime = fadeTime
    end,

    draw = function(self)
        local x = self.screenX
        local y = self.screenY
        local w = self.width
        local h = self.height
        local text = self.text
        local padding = self.style.padding
        local labelStyle = self.label.style
        local font = labelStyle.font
        local fg = labelStyle.color

        uie.__row.draw(self)

        if self.focused and self.blinkTime < 0.5 and fg and #fg ~= 0 and fg[4] ~= 0 and fg[5] ~= 0 and uiu.setColor(fg) then
            local ix = math.ceil(self.index == 0 and 0 or font:getWidth(text:sub(1, utf8.offset(text, self.index + 1) - 1))) + 0.5
            love.graphics.setLineWidth(fg[5] or 1)
            love.graphics.line(x + ix + padding, y + padding, x + ix + padding, y + h - padding)
        end

    end,

    onPress = function(self, x, y, button)
        if not self.focusing then
            self.__wasKeyRepeat = love.keyboard.hasKeyRepeat()
            love.keyboard.setKeyRepeat(true)
        end

        local label = self.label
        local text = self.text
        local len = utf8.len(self.text)
        local font = label.style.font

        x = x - label.screenX
        if x <= 0 then
            self.index = 0
        elseif x >= label.width - font:getWidth(text:sub(utf8.offset(text, len - 1), utf8.offset(text, len) - 1)) * 0.4 then
            self.index = utf8.len(self.text)
        else
            local min = 0
            local max = len
            while max - min > 1 do
                local mid = min + math.ceil((max - min) / 2)
                local midx = font:getWidth(text:sub(1, utf8.offset(text, mid + 1) - 1)) - font:getWidth(text:sub(utf8.offset(text, mid), utf8.offset(text, mid + 1) - 1)) * 0.4
                if x <= midx then
                    max = mid
                else
                    min = mid
                end
            end
            self.index = min
        end

        self.blinkTime = 0
        self:repaint()
    end,

    onUnfocus = function(self)
        love.keyboard.setKeyRepeat(self.__wasKeyRepeat)
    end,

    onText = function(self, new)
        local text = self.text
        local index = self.index
        if index == 0 then
            self.text = new .. text:sub(utf8.offset(text, index + 1))
        else
            self.text = text:sub(1, utf8.offset(text, index + 1) - 1) .. new .. text:sub(utf8.offset(text, index + 1))
        end
        self.index = self.index + utf8.len(new)
    end,

    onKeyPress = function(self, key)
        local text = self.text
        local index = self.index

        if key == "backspace" then
            if index == 0 then
                return
            elseif index == 1 then
                self.text = text:sub(utf8.offset(text, index + 1))
            else
                self.text = text:sub(1, utf8.offset(text, index) - 1) .. text:sub(utf8.offset(text, index + 1))
            end
            self.index = math.max(0, index - 1)
            self.blinkTime = 0
            self:repaint()

        elseif key == "delete" then
            if index == utf8.len(text) then
                return
            end
            if index == 0 then
                self.text = text:sub(utf8.offset(text, index + 2))
            else
                self.text = text:sub(1, utf8.offset(text, index + 1) - 1) .. text:sub(utf8.offset(text, index + 2))
            end
            self.index = math.min(utf8.len(text), index)
            self.blinkTime = 0
            self:repaint()

        elseif key == "left" then
            self.index = math.max(0, index - 1)
            self.blinkTime = 0
            self:repaint()

        elseif key == "right" then
            self.index = math.min(utf8.len(text), index + 1)
            self.blinkTime = 0
            self:repaint()

        elseif key == "return" then
            self.text = text
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
        bg = {},
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

        normalBG = { 0.13, 0.13, 0.13, 0.8 },
        normalFG = { 1, 1, 1, 1 },
        normalBorder = { 0, 0, 0, 0, 1 },

        disabledBG = { 0.05, 0.05, 0.05, 1 },
        disabledFG = { 0.7, 0.7, 0.7, 0.7 },
        disabledBorder = { 0, 0, 0, 0, 1 },

        hoveredBG = { 0.36, 0.36, 0.36, 0.9 },
        hoveredFG = { 1, 1, 1, 1 },
        hoveredBorder = { 0, 0, 0, 0, 1 },

        pressedBG = { 0.1, 0.3, 0.6, 0.9 },
        pressedFG = { 1, 1, 1, 1 },
        pressedBorder = { 0, 0, 0, 0, 1 },

        selectedBG = { 0.2, 0.5, 0.7, 0.9 },
        selectedFG = { 1, 1, 1, 1 },
        selectedBorder = { 0, 0, 0, 0, 1 },

        fadeDuration = 0.2
    },

    init = function(self, text, data)
        if text and text.text and text.data ~= nil then
            data = text.data
            text = text.text
        end
        local label = uie.label(text)
        uie.__row.init(self, { label })
        self.label = label
        self.data = data
        self.enabled = true
        self.style.bg = {}
        self.label.style.color = {}
        self.style.border = {}
    end,

    getText = function(self)
        return self.label.text
    end,

    setText = function(self, value)
        self.label.text = value
    end,

    getEnabled = function(self)
        local owner = self.owner or self.parent
        if not owner.isList then
            return self.__enabled
        end
        return owner.enabled and self.__enabled
    end,

    setEnabled = function(self, value)
        self.__enabled = value
    end,

    getInteractive = function(self)
        local owner = self.owner or self.parent
        if not owner.isList then
            return self.__enabled and 1 or -1
        end
        return owner.enabled and self.__enabled and 1 or -1
    end,

    getSelected = function(self)
        local owner = self.owner or self.parent
        if not owner.isList then
            return self.__selected
        end
        return owner.selected == self
    end,

    setSelected = function(self, value)
        local owner = self.owner or self.parent
        if not owner.isList then
            self.__selected = value
            return
        end
        owner.selected = value and self or nil
    end,

    update = function(self, dt)
        local style = self.style
        local label = self.label
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
            fadeTime = fadeTime + dt

            if #bgPrev ~= 0 and fadeTime < fadeDuration then
                local f = fadeTime / fadeDuration

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
                borderPrev[5] = borderPrev[5] + (border[5] - borderPrev[5]) * f

            else
                fadeTime = fadeDuration

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
                borderPrev[5] = border[5]
            end

            self:repaint()
            label:repaint()
        end

        self.__fadeTime = fadeTime
    end,

    onClick = function(self, x, y, button)
        if self.enabled and button == 1 then
            local owner = self.owner or self.parent
            if owner.isList then
                self.selected = true
            end
            local cb = owner.cb
            if cb then
                if self.data ~= nil then
                    cb(owner, self.data)
                else
                    cb(owner, self.text)
                end
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
        bg = { 0.08, 0.08, 0.08, 0.8 },
        padding = 0,
        spacing = 1,
        radius = 0
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

    style = {
        bg = { 0.08, 0.08, 0.08, 0.8 }
    },

    init = function(self, text, data)
        uie.__listItem.init(self, text, data)
    end,

    map = function(item)
        local text, data
        if type(item) == "string" then
            text = item
        else
            text, data = table.unpack(item)
        end

        if not text then
            return uie.menuItem(""):with({ interactive = -1, height = 2, style = { padding = 0 } }) -- TODO: Divider!
        end

        return uie.menuItem(text, data)
    end,

    cb = function(self)
        local data = self.data
        if data == nil then
            return
        end

        if uiu.isCallback(data) then
            return data(self)
        end

        local parent = self.parent

        local submenu = parent.submenu
        if submenu then
            submenu:removeSelf()
        end

        local x, y

        if parent:is("topbar") then
            x = self.screenX
            y = self.screenY + self.height + parent.style.spacing
        else
            x = self.screenX + self.width + parent.style.spacing
            y = self.screenY
        end

        parent.submenu = uie.__menuItemSubmenu.spawn(self, x, y, uiu.map(data, uie.__menuItem.map))
    end,

    onClick = function(self, x, y, button)
        if self.enabled and button == 1 then
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
        bg = { 0.08, 0.08, 0.08, 0.8 },
        padding = 0,
        spacing = 1
    },

    init = function(self, owner, children)
        uie.__column.init(self, children)

        self.owner = owner
    end,

    spawn = function(owner, x, y, children)
        local submenu = uie.menuItemSubmenu(owner, children)
        submenu:reflow()

        ::reflow::
        repeat
            submenu:layoutLazy()
        until not submenu.reflowing

        repeat
            submenu:layoutLateLazy()
            if submenu.reflowing then
                goto reflow
            end
        until not submenu.reflowingLate

        submenu.x = x + math.min(0, ui.root.innerWidth - (x + submenu.width))
        submenu.y = y + math.min(0, ui.root.innerHeight - (y + submenu.height))

        table.insert(ui.root.children, submenu)
        ui.root:recollect()
        ui.root:reflow()

        return submenu
    end,

    getFocused = function(self)
        local submenu = self.submenu
        return uie.__default.getFocused(self) or self.owner.focused or (submenu and submenu.focused)
    end,

    update = function(self)
        if not self.owner.alive or not self.focused then
            self:removeSelf()
            return
        end
    end,

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


-- Very primitive dropdown.
uie.add("dropdown", {
    base = "button",
    clip = false,
    interactive = 2,

    init = function(self, list, cb)
        self._itemsCache = {}
        self.selected = self:_itemCached(list[1], 1)
        uie.__button.init(self, self.selected.text)
        self.data = list
        self.cb = cb
        self.isList = true
        self:addChild(uie.icon("ui:drop"):with(uiu.at(0.999 + 1, 0.5 + 5)))
    end,

    _itemCached = function(self, text, i)
        local cache = self._itemsCache
        local item = cache[i]
        if item then
            local data
            if text and text.text and text.data ~= nil then
                data = text.data
                text = text.text
            end
            item.text = text
            item.data = data
        else
            item = uie.listItem(text):with({
                owner = self
            }):hook({
                onClick = function(orig, self, x, y, button)
                    orig(self, x, y, button)
                    self.owner.selected = self
                    self.owner.text = self.text
                    self.owner.submenu:removeSelf()
                end
            })
            cache[i] = item
        end
        return item
    end,

    getItem = function(self, i)
        return self:_itemCached(self.data[i], i)
    end,

    onClick = function(self, x, y, button)
        if self.enabled and button == 1 then
            local submenu = self.submenu
            if submenu then
                submenu:removeSelf()
            end

            x = self.screenX
            y = self.screenY + self.height + self.parent.style.spacing

            self.submenu = uie.__menuItemSubmenu.spawn(self, x, y, uiu.map(self.data, function(data, i)
                local item = self:_itemCached(data, i)
                item.width = false
                item.height = false
                item:layout()
                return item
            end))
        end
    end
})


return uie
