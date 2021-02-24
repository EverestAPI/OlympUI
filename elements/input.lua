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

        normalBG = { 0.13, 0.13, 0.13, 0.9 },
        normalFG = { 1, 1, 1, 1 },
        normalBorder = { 0, 0, 0, 0, 1 },

        disabledBG = { 0.05, 0.05, 0.05, 0.7 },
        disabledFG = { 0.7, 0.7, 0.7, 0.7 },
        disabledBorder = { 0, 0, 0, 0, 1 },

        hoveredBG = { 0.36, 0.36, 0.36, 1 },
        hoveredFG = { 1, 1, 1, 1 },
        hoveredBorder = { 0, 0, 0, 0, 1 },

        pressedBG = { 0.2, 0.2, 0.2, 1 },
        pressedFG = { 1, 1, 1, 1 },
        pressedBorder = { 0, 0, 0, 0, 1 },

        fadeDuration = 0.2
    },

    init = function(self, label, cb)
        if not label or not label.__ui then
            label = uie.label(label)
        end
        uie.row.init(self, { label })
        self.label = label
        self.enabled = true
        self._fadeBGStyle, self._fadeBGPrev, self._fadeBG = {}, false, false
        self._fadeFGStyle, self._fadeFGPrev, self._fadeFG = {}, false, false
        self._fadeBorderStyle, self._fadeBorderPrev, self._fadeBorder = {}, false, false
        self.cb = cb
    end,

    getEnabled = function(self)
        return self._enabled
    end,

    setEnabled = function(self, value)
        self._enabled = value
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
        local bg, bgPrev, bgNext = self._fadeBGStyle, self._fadeBG, nil
        local fg, fgPrev, fgNext = self._fadeFGStyle, self._fadeFG, nil
        local border, borderPrev, borderNext = self._fadeBorderStyle, self._fadeBorder, nil

        if not self.enabled then
            bgNext = style.disabledBG
            fgNext = style.disabledFG
            borderNext = style.disabledBorder
        elseif self.pressed then
            bgNext = style.pressedBG
            fgNext = style.pressedFG
            borderNext = style.pressedBorder
        elseif self.hovered then
            bgNext = style.hoveredBG
            fgNext = style.hoveredFG
            borderNext = style.hoveredBorder
        else
            bgNext = style.normalBG
            fgNext = style.normalFG
            borderNext = style.normalBorder
        end

        local faded = false
        local fadeSwap = uiu.fadeSwap
        faded, style.bg, bgPrev, self._fadeBGPrev, self._fadeBG = fadeSwap(faded, bg, self._fadeBGPrev, bgPrev, bgNext)
        faded, labelStyle.color, fgPrev, self._fadeFGPrev, self._fadeFG = fadeSwap(faded, fg, self._fadeFGPrev, fgPrev, fgNext)
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
            faded = fade(faded, f, bg, bgPrev, bgNext)
            faded = fade(faded, f, fg, fgPrev, fgNext)
            faded = fade(faded, f, border, borderPrev, borderNext)

            if faded then
                self:repaint()
                label:repaint()
            end

            self._fadeTime = fadeTime
        end
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
        normalPlaceholder = { 0, 0, 0, 0.4, 0 },
        normalBorder = { 0.08, 0.08, 0.08, 0.6, 1 },

        disabledBG = { 0.5, 0.5, 0.5, 0.7 },
        disabledFG = { 0, 0, 0, 0.7, 0 },
        disabledBorder = { 0, 0, 0, 0.7, 1 },

        focusedBG = { 1, 1, 1, 0.9 },
        focusedFG = { 0, 0, 0, 0.9, 1 },
        focusedPlaceholder = { 0, 0, 0, 0.5, 1 },
        focusedBorder = { 0, 0, 0, 0.9, 1 },

        fadeDuration = 0.2
    },

    init = function(self, text, cb)
        self.index = 0
        local label = uie.label()
        uie.row.init(self, { label })
        self.label = label
        self.enabled = true
        self._fadeBGStyle, self._fadeBGPrev, self._fadeBG = {}, false, false
        self._fadeFGStyle, self._fadeFGPrev, self._fadeFG = {}, false, false
        self._fadeBorderStyle, self._fadeBorderPrev, self._fadeBorder = {}, false, false
        self.blinkTime = false
        self._text = false
        self.placeholder = false
        self.text = text
        self.cb = cb
    end,

    getEnabled = function(self)
        return self._enabled
    end,

    setEnabled = function(self, value)
        self._enabled = value
        self.interactive = value and 1 or -1
    end,

    getPlaceholder = function(self)
        return self._placeholder
    end,

    setPlaceholder = function(self, value)
        value = value ~= "" and value
        self._placeholder = value
        if not self.text then
            self.label.text = value or ""
        end
    end,

    getText = function(self)
        return self._text
    end,

    setText = function(self, value)
        value = value ~= "" and value
        local prev = self._text
        self._text = value
        self.label.text = value or self.placeholder or ""
        local cb = self.cb
        if cb then
            cb(self, value or "", prev or "")
        end
    end,

    update = function(self, dt)
        local style = self.style
        local label = self.label
        local labelStyle = label.style
        local bg, bgPrev, bgNext = self._fadeBGStyle, self._fadeBG, nil
        local fg, fgPrev, fgNext = self._fadeFGStyle, self._fadeFG, nil
        local border, borderPrev, borderNext = self._fadeBorderStyle, self._fadeBorder, nil

        if not self.enabled then
            bgNext = style.disabledBG
            fgNext = style.disabledFG
            borderNext = style.disabledBorder
        elseif self.focused then
            bgNext = style.focusedBG
            fgNext = self.text and style.focusedFG or style.focusedPlaceholder
            borderNext = style.focusedBorder
        else
            bgNext = style.normalBG
            fgNext = self.text and style.normalFG or style.normalPlaceholder
            borderNext = style.normalBorder
        end

        local faded = false
        local fadeSwap = uiu.fadeSwap
        faded, style.bg, bgPrev, self._fadeBGPrev, self._fadeBG = fadeSwap(faded, bg, self._fadeBGPrev, bgPrev, bgNext)
        faded, labelStyle.color, fgPrev, self._fadeFGPrev, self._fadeFG = fadeSwap(faded, fg, self._fadeFGPrev, fgPrev, fgNext)
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
            faded = fade(faded, f, bg, bgPrev, bgNext)
            faded = fade(faded, f, fg, fgPrev, fgNext)
            faded = fade(faded, f, border, borderPrev, borderNext)

            if faded then
                self:repaint()
                label:repaint()
            end

            self._fadeTime = fadeTime
        end

        local blinkTimePrev = self.blinkTime
        if blinkTimePrev then
            local blinkTime = (blinkTimePrev + dt) % 1
            self.blinkTime = blinkTime
            if blinkTimePrev < 0.5 and blinkTime >= 0.5 or blinkTimePrev >= 0.5 and blinkTime < 0.5 then
                self:repaint()
            end
        end
    end,

    draw = function(self)
        local x = self.screenX
        local y = self.screenY
        local w = self.width
        local h = self.height
        local text = self.text or ""
        local padding = self.style.padding
        local labelStyle = self.label.style
        local font = labelStyle.font
        local fg = labelStyle.color

        local paddingL, paddingT, paddingB
        if type(padding) == "table" then
            paddingL, paddingT, paddingB = padding[1], padding[2], padding[4]
        else
            paddingL, paddingT, paddingB = padding, padding, padding
        end

        uie.row.draw(self)

        if self.focused and self.blinkTime < 0.5 and fg and fg[5] and fg[4] ~= 0 and fg[5] ~= 0 and uiu.setColor(fg) then
            local ix = math.ceil(self.index == 0 and 0 or font:getWidth(text:sub(1, utf8.offset(text, self.index + 1) - 1))) + 0.5
            love.graphics.setLineWidth(fg[5] or 1)
            love.graphics.line(x + ix + paddingL, y + paddingT, x + ix + paddingL, y + h - paddingB)
        end

    end,

    onPress = function(self, x, y, button)
        if not self.focusing then
            self.__wasKeyRepeat = love.keyboard.hasKeyRepeat()
            love.keyboard.setKeyRepeat(true)
        end

        local label = self.label
        local text = self.text or ""
        local len = utf8.len(text)
        local font = label.style.font

        x = x - label.screenX
        if x <= 0 then
            self.index = 0
        elseif len == 0 or x >= label.width - font:getWidth(text:sub(utf8.offset(text, len - 1), utf8.offset(text, len) - 1)) * 0.4 then
            self.index = len
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
        self.blinkTime = false
    end,

    onText = function(self, new)
        local text = self.text or ""
        local index = self.index
        if index == 0 then
            self.text = new .. text:sub(utf8.offset(text, index + 1))
        else
            self.text = text:sub(1, utf8.offset(text, index + 1) - 1) .. new .. text:sub(utf8.offset(text, index + 1))
        end
        self.index = self.index + utf8.len(new)
    end,

    onKeyPress = function(self, key)
        local text = self.text or ""
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


-- Alias uie.add("textfield", { base = "field" })
uie.textfield = uie.field


-- Basic list, consisting of multiple list items.
uie.add("list", {
    base = "column",
    cacheable = false,

    isList = true,
    grow = true,

    style = {
        spacing = 1,
    },

    init = function(self, items, cb)
        uie.column.init(self, uiu.map(items, uie.listItem))
        self.enabled = true
        self.selected = false
        self.cb = cb
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
                c.autoWidth = true
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

    style = uie.list.__default.style,

    init = function(self, items, cb)
        uie.row.init(self, uiu.map(items, uie.listItem))
        self.enabled = true
        self.selected = false
        self.cb = cb
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
                c.autoHeight = true
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

        normalBG = { 0.13, 0.13, 0.13, 0.9 },
        normalFG = { 1, 1, 1, 1 },
        normalBorder = { 0, 0, 0, 0, 1 },

        disabledBG = { 0.05, 0.05, 0.05, 0.7 },
        disabledFG = { 0.7, 0.7, 0.7, 0.7 },
        disabledBorder = { 0, 0, 0, 0, 1 },

        hoveredBG = { 0.36, 0.36, 0.36, 1 },
        hoveredFG = { 1, 1, 1, 1 },
        hoveredBorder = { 0, 0, 0, 0, 1 },

        pressedBG = { 0.1, 0.3, 0.6, 1 },
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
        local label = type(text) == "table" and text.__type and text or uie.label(text)
        uie.row.init(self, { label })
        self.label = label
        self.data = data
        self.enabled = true
        self.owner = false
        self._selected = false
        self._fadeBGStyle, self._fadeBGPrev, self._fadeBG = {}, false, false
        self._fadeFGStyle, self._fadeFGPrev, self._fadeFG = {}, false, false
        self._fadeBorderStyle, self._fadeBorderPrev, self._fadeBorder = {}, false, false
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
            return self._enabled
        end
        return owner.enabled and self._enabled
    end,

    setEnabled = function(self, value)
        self._enabled = value
    end,

    getInteractive = function(self)
        local owner = self.owner or self.parent
        if not owner.isList then
            return self._enabled and 1 or -1
        end
        return owner.enabled and self._enabled and 1 or -1
    end,

    getSelected = function(self)
        local owner = self.owner or self.parent
        if not owner.isList then
            return self._selected
        end
        return owner.selected == self
    end,

    setSelected = function(self, value)
        local owner = self.owner or self.parent
        if not owner.isList then
            self._selected = value
            return
        end
        owner.selected = value and self or false
    end,

    update = function(self, dt)
        local style = self.style
        local label = self.label
        local labelStyle = label.style
        local bg, bgPrev, bgNext = self._fadeBGStyle, self._fadeBG, nil
        local fg, fgPrev, fgNext = self._fadeFGStyle, self._fadeFG, nil
        local border, borderPrev, borderNext = self._fadeBorderStyle, self._fadeBorder, nil

        if not self.enabled then
            bgNext = style.disabledBG
            fgNext = style.disabledFG
            borderNext = style.disabledBorder
        elseif self.pressed then
            bgNext = style.pressedBG
            fgNext = style.pressedFG
            borderNext = style.pressedBorder
        elseif self.selected then
            bgNext = style.selectedBG
            fgNext = style.selectedFG
            borderNext = style.selectedBorder
        elseif self.hovered then
            bgNext = style.hoveredBG
            fgNext = style.hoveredFG
            borderNext = style.hoveredBorder
        else
            bgNext = style.normalBG
            fgNext = style.normalFG
            borderNext = style.normalBorder
        end

        local faded = false
        local fadeSwap = uiu.fadeSwap
        faded, style.bg, bgPrev, self._fadeBGPrev, self._fadeBG = fadeSwap(faded, bg, self._fadeBGPrev, bgPrev, bgNext)
        faded, labelStyle.color, fgPrev, self._fadeFGPrev, self._fadeFG = fadeSwap(faded, fg, self._fadeFGPrev, fgPrev, fgNext)
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
            faded = fade(faded, f, bg, bgPrev, bgNext)
            faded = fade(faded, f, fg, fgPrev, fgNext)
            faded = fade(faded, f, border, borderPrev, borderNext)

            if faded then
                self:repaint()
                label:repaint()
            end

            self._fadeTime = fadeTime
        end
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
    interactive = 1,

    isList = false,

    style = {
        bg = { 0.08, 0.08, 0.08, 0.8 },
        padding = 0,
        spacing = 1,
        radius = 0
    },

    init = function(self, list)
        uie.row.init(self, uiu.map(list, uie.menuItem.map))
        self:with(uiu.fillWidth)

        local children = self.children
        for i = 1, #children do
            local child = children[i]
            local img = child.children[2]
            if img and img.id == "ui:icons/nested" then
                img:removeSelf()
                child:addChild(uie.icon("ui:icons/drop"):hook({
                    layoutLateLazy = function(orig, self)
                        -- Always reflow this child whenever its parent gets reflowed.
                        self:layoutLate()
                        self:repaint()
                    end,

                    layoutLate = function(orig, self)
                        local parent = self.parent
                        self.realX = math.floor(parent.width - (parent.style:get("padding") or 0) - 8)
                        self.realY = math.floor(parent.height * 0.5 - 3)
                        orig(self)
                    end
                }))
            end
        end
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
        uie.listItem.init(self, text, data)
        if data and not uiu.isCallback(data) then
            self:addChild(uie.icon("ui:icons/nested"):hook({
                layoutLateLazy = function(orig, self)
                    -- Always reflow this child whenever its parent gets reflowed.
                    self:layoutLate()
                    self:repaint()
                end,

                layoutLate = function(orig, self)
                    local parent = self.parent
                    self.realX = math.floor(parent.width - (parent.style:get("padding") or 0) - 6)
                    self.realY = math.floor(parent.height * 0.5 - 3)
                    orig(self)
                end
            }))
        end
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

        parent.submenu = uie.menuItemSubmenu.spawn(self, x, y, uiu.map(data, uie.menuItem.map))
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

    isList = false,
    grow = false,

    style = {
        bg = { 0.08, 0.08, 0.08, 0.8 },
        padding = 0,
        spacing = 1
    },

    init = function(self, owner, children)
        uie.column.init(self, children)

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
        return uie.default.getFocused(self) or self.owner.focused or (submenu and submenu.focused)
    end,

    update = function(self)
        if not self.owner.alive or not self.focused then
            self:removeSelf()
            return
        end
    end,

    layoutChildren = function(self)
        local style = self.style
        local padding = style.padding
        local paddingL, paddingT, paddingR
        if type(padding) == "table" then
            paddingL, paddingT, paddingR = padding[1], padding[2], padding[3]
        else
            paddingL, paddingT, paddingR = padding, padding, padding
        end
        local y = paddingT
        local spacing = style.spacing
        local maxWidth = 0
        local children = self.children
        if children then
            for i = 1, #children do
                local c = children[i]
                c.parent = self
                c:layoutLazy()
                y = y + c.y
                c.realX = c.x + paddingL
                c.realY = y
                y = y + c.height + spacing
                maxWidth = math.max(maxWidth, c.width)
            end
        end
        self.width = maxWidth + paddingL + paddingR
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
                c.autoWidth = true
                c:layoutLateLazy()
            end
        end
    end,
})


-- Very primitive dropdown.
uie.add("dropdown", {
    base = "button",
    clip = false,
    interactive = 1,

    init = function(self, list, cb)
        self._itemsCache = {}
        self.selected = self:getItemCached(list[1], 1)
        uie.button.init(self, self.selected.text)
        self.data = list
        self.isList = true
        self:addChild(uie.icon("ui:icons/drop"):with(uiu.at(0.999 + 1, 0.5 + 5)))
        self.cb = cb
    end,

    getItemCached = function(self, text, i)
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
        return self:getItemCached(self.data[i], i)
    end,

    onClick = function(self, x, y, button)
        if self.enabled and button == 1 then
            local submenu = self.submenu
            if submenu then
                submenu:removeSelf()
            end

            x = self.screenX
            y = self.screenY + self.height + self.parent.style.spacing

            self.submenu = uie.menuItemSubmenu.spawn(self, x, y, uiu.map(self.data, function(data, i)
                local item = self:getItemCached(data, i)
                item.width = false
                item.height = false
                item:layout()
                return item
            end))
        end
    end
})


return uie
