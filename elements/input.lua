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
        self.cb = cb
    end,

    revive = function(self)
        self._fadeBGStyle, self._fadeBGPrev, self._fadeBG = {}, false, false
        self._fadeFGStyle, self._fadeFGPrev, self._fadeFG = {}, false, false
        self._fadeBorderStyle, self._fadeBorderPrev, self._fadeBorder = {}, false, false
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
        radius = 3,

        normalBG = { 0.95, 0.95, 0.95, 0.9 },
        normalFG = { 0, 0, 0, 0.8, 0 },
        normalPlaceholder = { 0, 0, 0, 0.4, 0 },
        normalBorder = { 0.08, 0.08, 0.08, 0.6, 1 },

        selectionBG = { 0.2, 0.2, 0.2, 0.7 },

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
        self.selectionStart = false
        self.selectionStop = false
        self.selectionInitial = false
        self.selectionStartX = 0
        self.selectionStopX = 0
        local label = uie.label()
        uie.row.init(self, { label })
        self.label = label
        self.enabled = true
        self.blinkTime = false
        self.blinkX = 0
        self._text = false
        self.placeholder = false
        self.text = text
        self.cb = cb
        self.clip = true
        self.clipPadding = 0
    end,

    revive = function(self)
        self._fadeBGStyle, self._fadeBGPrev, self._fadeBG = {}, false, false
        self._fadeFGStyle, self._fadeFGPrev, self._fadeFG = {}, false, false
        self._fadeBorderStyle, self._fadeBorderPrev, self._fadeBorder = {}, false, false
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

    -- Update the cursor and updates the selected area
    -- Selecting indicates that starting/in a selection (for example holding shift)
    -- indexOnly means this should only move the cursor, selection logic is ignored
    setCursorIndex = function(self, index, selecting, indexOnly)
        local previousIndex = self.index
        local clearedSelection, selectionStart, selectionStop = false, -1, -1
        if indexOnly ~= false then
            if selecting then
                self.selectionInitial = self.selectionInitial or self.index

                if index < self.selectionInitial then
                    self.selectionStart = index
                    self.selectionStop = self.selectionInitial
                else
                    self.selectionStart = self.selectionInitial
                    self.selectionStop = index
                end
            else
                if self:hasSelection() then
                    clearedSelection, selectionStart, selectionStop = true, self.selectionStart, self.selectionStop
                    self:clearSelection()
                end
            end
        end

        self.index = index

        return previousIndex ~= index, clearedSelection, selectionStart, selectionStop
    end,

    getCursorIndex = function(self)
        return self.index
    end,

    hasSelection = function(self)
        return not not (self.selectionStart and self.selectionStop)
    end,

    getSelectedText = function(self)
        local text = self.text or ""
        local selected = text:sub(utf8.offset(text, self.selectionStart + 1), utf8.offset(text, self.selectionStop))
        return selected
    end,

    deleteSelectedText = function(self, clearSelection)
        if self:hasSelection() then
            local text = self.text or ""
            local leftPart = text:sub(1, self.selectionStart == 0 and 0 or utf8.offset(text, self.selectionStart))
            local rightPart = text:sub(utf8.offset(text, self.selectionStop + 1))
            self.text = leftPart .. rightPart
            self.index = self.selectionStart
            if clearSelection ~= false then
                self:clearSelection()
            end
            self:repaint()
        end
    end,

    clearSelection = function(self)
        self.selectionInitial = nil
        self.selectionStart = nil
        self.selectionStop = nil
    end,

    hotkeyModifierHeld = function(self)
        if love.system.getOS == "OS X" then
            return love.keyboard.isDown("rgui", "lgui")
        else
            return love.keyboard.isDown("rctrl", "lctrl")
        end
    end,

    selectionModifierHeld = function(self)
        return love.keyboard.isDown("rshift", "lshift")
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

        local text = self.text or ""
        local font = labelStyle.font
        local padding = style:getIndex("padding", 0)

        local textWidth = font:getWidth(text)
        local innerWidth = self.innerWidth
        local blinkX = uiu.getTextCursorOffset(font, text, self.index)
        local labelX = -label.x

        -- Adapted from FEZMod-Legacy because YOLO.
        if blinkX - labelX >= innerWidth * 0.9 then
            labelX = blinkX - innerWidth * 0.9;
        elseif blinkX - labelX <= innerWidth * 0.25 then
            labelX = blinkX - innerWidth * 0.25;
        end
        labelX = math.floor(math.max(0, math.min(labelX, textWidth)));

        label.x = -labelX
        label.realX = -labelX + padding
        self.blinkX = math.ceil(blinkX - labelX) + 0.5

        if self:hasSelection() then
            self.selectionStartX = uiu.getTextCursorOffset(font, text, self.selectionStart)
            self.selectionStopX = uiu.getTextCursorOffset(font, text, self.selectionStop)

            self.selectionStartX = math.ceil(self.selectionStartX - labelX) + 0.5
            self.selectionStopX = math.ceil(self.selectionStopX - labelX) + 0.5
        end
    end,

    draw = function(self)
        local x = self.screenX
        local y = self.screenY
        local w = self.width
        local h = self.height
        local padding = self.style.padding
        local labelStyle = self.label.style
        local fg = labelStyle.color
        local selectionBG = self.style.selectionBG

        local paddingL, paddingT, paddingB
        if type(padding) == "table" then
            paddingL, paddingT, paddingB = padding[1], padding[2], padding[4]
        else
            paddingL, paddingT, paddingB = padding, padding, padding
        end

        uie.row.draw(self)

        if self.focused and self.blinkTime < 0.5 and fg and fg[5] and fg[4] ~= 0 and fg[5] ~= 0 and uiu.setColor(fg) then
            local ix = self.blinkX
            love.graphics.setLineWidth(fg[5] or 1)
            love.graphics.line(x + ix + paddingL, y + paddingT, x + ix + paddingL, y + h - paddingB)
        end

        if self:hasSelection() then
            local textStartX = self.selectionStartX
            local textStopX = self.selectionStopX
            local drawStart = math.max(x, x + textStartX + paddingL)
            local drawStop = math.min(x + w, x + textStopX + paddingL)
            if drawStop > drawStart then
                uiu.setColor(selectionBG)
                love.graphics.rectangle("fill", drawStart, y + paddingT, drawStop - drawStart, h - paddingT - paddingB)
            end
        end
    end,

    onPress = function(self, x, y, button, dragging, presses)
        if not self.focusing then
            self.__wasKeyRepeat = love.keyboard.hasKeyRepeat()
            love.keyboard.setKeyRepeat(true)
        end

        local label = self.label
        local text = self.text or ""
        local len = utf8.len(text)
        local font = label.style.font
        local selecting = self:selectionModifierHeld()
        local index

        x = x - label.screenX
        if x <= 0 then
            index = 0
        elseif len == 0 or x >= label.width - font:getWidth(text:sub(utf8.offset(text, len - 1), utf8.offset(text, len) - 1)) * 0.4 then
            index = len
        else
            index = uiu.getTextIndexForCursor(font, text, x)
        end

        if button == 1 and presses > 1 and index == self._lastClickIndex then
            local startIndex
            local stopIndex

            if presses == 2 then
                -- Select word
                startIndex = uiu.findWordBorder(text, index, 1)
                stopIndex = uiu.findWordBorder(text, index, -1)

                startIndex = math.max(startIndex, 0)
                stopIndex = math.min(stopIndex - 1, len)

            elseif presses == 3 then
                -- Select line
                -- TODO - Improve once multiline textfields exist
                startIndex = 0
                stopIndex = len

            else
                -- Select everything
                startIndex = 0
                stopIndex = len
            end

            self:setCursorIndex(startIndex, false)
            self:setCursorIndex(stopIndex, true)

        else
            self._lastClickIndex = index
            self:setCursorIndex(index, selecting)
        end

        self.blinkTime = 0
        self:repaint()
        -- Only drag on left click
        self.mouseDrag = button == 1
    end,

    onDrag = function(self, x, y)
        if self.mouseDrag then
            local label = self.label
            local text = self.text or ""
            local font = label.style.font
            local index = 0
            x = x - label.screenX
            y = y - label.screenY
            -- TODO - Improve once fields are multiline
            if y < 0 then
                index = 0
            elseif y > label.height then
                index = utf8.len(text)
            else
                index = uiu.getTextIndexForCursor(font, text, x)
            end
            if self:setCursorIndex(index, true) then
                self:repaint()
            end
        end
    end,

    onRelease = function(self, x, y, button)
        if self.mouseDrag then
            self.mouseDrag = false
        end
    end,

    onUnfocus = function(self)
        love.keyboard.setKeyRepeat(self.__wasKeyRepeat)
        self.blinkTime = false
        self:clearSelection()
    end,

    onText = function(self, new)
        if self:hasSelection() then
            self:deleteSelectedText()
        end
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
        local hotkeyModifierHeld = self:hotkeyModifierHeld()
        local selectionModifierHeld = self:selectionModifierHeld()

        if key == "backspace" then
            if self:hasSelection() then
                self:deleteSelectedText()
            else
                local from = index
                if index == 0 then
                    return
                elseif index == 1 then
                    self.text = text:sub(utf8.offset(text, index + 1))
                else
                    if hotkeyModifierHeld then
                        from = uiu.findWordBorder(text, index - 1, -1)
                    end
                    self.text = text:sub(1, utf8.offset(text, from) - 1) .. text:sub(utf8.offset(text, index + 1))
                end
                self.index = math.max(0, from - 1)
            end
            self.blinkTime = 0
            self:repaint()

        elseif key == "delete" then
            if self:hasSelection() then
                self:deleteSelectedText()
            else
                local from = index + 1
                if index == utf8.len(text) then
                    return
                end
                if hotkeyModifierHeld then
                    from = uiu.findWordBorder(text, index + 2, 1)
                end
                if index == 0 then
                    self.text = text:sub(utf8.offset(text, from + 1))
                else
                    self.text = text:sub(1, utf8.offset(text, index + 1) - 1) .. text:sub(utf8.offset(text, from + 1))
                end
                self.index = math.min(utf8.len(text), index)
            end
            self.blinkTime = 0
            self:repaint()

        elseif key == "left" then
            local targetIndex = index - 1
            if hotkeyModifierHeld then
                targetIndex = uiu.findWordBorder(text, index - 1, -1) - 1
            end
            local newIndex = math.max(0, targetIndex)
            local _, clearedSelection, start, _ = self:setCursorIndex(newIndex, selectionModifierHeld)
            if clearedSelection then
                -- Jump cursor to start of the selection
                self.index = start
            end
            self.blinkTime = 0
            self:repaint()

        elseif key == "home" then
            self:setCursorIndex(0, selectionModifierHeld)
            self.blinkTime = 0
            self:repaint()

        elseif key == "right" then
            local targetIndex = index + 1
            if hotkeyModifierHeld then
                targetIndex = uiu.findWordBorder(text, index + 2, 1)
            end
            local newIndex = math.min(utf8.len(text), targetIndex)
            local _, clearedSelection, _, stop = self:setCursorIndex(newIndex, selectionModifierHeld)
            if clearedSelection then
                -- Jump cursor to end of the selection
                self.index = stop
            end
            self.blinkTime = 0
            self:repaint()

        elseif key == "end" then
            self:setCursorIndex(utf8.len(text), selectionModifierHeld)
            self.blinkTime = 0
            self:repaint()

        elseif key == "return" then
            self.text = text

        elseif hotkeyModifierHeld then
            if key == "a" then
                -- Clear the current selection, set index to start of text and then select until the end
                self:clearSelection()
                self:setCursorIndex(0, false, true)
                self:setCursorIndex(utf8.len(text), true)
                self:repaint()

            elseif key == "c" then
                if self:hasSelection() then
                    love.system.setClipboardText(self:getSelectedText())
                end

            elseif key == "v" then
                local clipboard = love.system.getClipboardText()
                if clipboard then
                    self:deleteSelectedText()
                    self:onText(clipboard)
                end

            elseif key == "x" then
                if self:hasSelection() then
                    love.system.setClipboardText(self:getSelectedText())
                    self:deleteSelectedText()
                end
            end
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
    cbOnItemClick = true,
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

    getSelectedIndex = function(self, children)
        local selected = self.selected
        if not selected then
            return false
        end

        children = children or self.children
        for i = 1, #children do
            local c = children[i]
            if c == selected then
                return i
            end
        end

        return false
    end,

    setSelectedIndex = function(self, value, children)
        self.selected = (children or self.children)[value] or false
    end,

    getSelectedData = function(self, children)
        local selected = self.selected
        if not selected then
            return false
        end

        children = children or self.children
        for i = 1, #children do
            local c = children[i]
            if c == selected then
                if c.data ~= nil then
                    return c.data
                else
                    return c.text
                end
            end
        end

        return false
    end,

    setSelectedData = function(self, value, children)
        children = children or self.children
        for i = 1, #children do
            local c = children[i]
            if c.data ~= nil then
                if c.data == value then
                    self.selected = c
                    return
                end
            else
                if c.text == value then
                    self.selected = c
                    return
                end
            end
        end

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
    cbOnItemClick = true,
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
    end,

    revive = function(self)
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

        local getIsSelected = owner.getIsSelected
        if getIsSelected then
            return getIsSelected(owner, self)
        end

        if not owner.isList then
            return self._selected
        end
        return owner.selected == self
    end,

    setSelected = function(self, value)
        local owner = self.owner or self.parent

        local setIsSelected = owner.setIsSelected
        if setIsSelected then
            return setIsSelected(owner, self, value)
        end

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
            -- Ideally the list owner should be the one to call cb when the selection changes.
            -- Sadly I'm not sure if it's safe to change this behavior without breaking any user code at this point...
            -- -jade
            local cb = owner.cb
            if cb and owner.cbOnItemClick then
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
        local spawnNewMenu = true
        if submenu then
            -- Submenu might still exist if it was closed by clicking one of the options
            -- In which case we should spawn a new menu
            spawnNewMenu = not submenu.alive
            submenu:removeSelf()
        end
        if spawnNewMenu then
            local x, y
            if parent:is("topbar") then
                x = self.screenX
                y = self.screenY + self.height + parent.style.spacing
            else
                x = self.screenX + self.width + parent.style.spacing
                y = self.screenY
            end
            parent.submenu = uie.menuItemSubmenu.spawn(self, x, y, uiu.map(data, uie.menuItem.map))
        end
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

        local width = submenu.width
        local height = submenu.height
        local rootWidth = ui.root.innerWidth
        local rootHeight = ui.root.innerHeight

        if width > rootWidth or height > rootHeight then
            -- Pack into scrollbox if submenu is too large
            submenu.hasScrollbox = true
            width = math.min(width, rootWidth)
            height = math.min(height, rootHeight)
            submenu = uie.scrollbox(submenu):with(uiu.fillHeight(false)):with(uiu.hook({
                calcWidth = function(orig, element)
                    return element.inner.width
                end
            }))
        end

        submenu.x = x + math.min(0, rootWidth - (x + width))
        submenu.y = y + math.min(0, rootHeight - (y + height))

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
            if self.hasScrollbox then
                self.parent:removeSelf()
            end
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

    isList = true,
    cbOnItemClick = true,

    init = function(self, list, cb)
        self._itemsCache = {}
        self.placeholder = list.placeholder
        uie.button.init(self, "")
        self.selected = self:getItemCached(list.placeholder or list[1], 1)
        for i = 1, #list do
            self:getItemCached(list[i], i)
        end
        self.data = list
        self:addChild(uie.icon("ui:icons/drop"):with(uiu.at(0.999 + 1, 0.5 + 5)))
        self.cb = cb
        self.submenuParent = self
    end,

    getSelectedIndex = function(self)
        return uie.list.getSelectedIndex(self, self._itemsCache)
    end,

    setSelectedIndex = function(self, value)
        return uie.list.setSelectedIndex(self, value, self._itemsCache)
    end,

    getSelectedData = function(self)
        return uie.list.getSelectedData(self, self._itemsCache)
    end,

    setSelectedData = function(self, value)
        return uie.list.setSelectedData(self, value, self._itemsCache)
    end,

    getSelected = function(self)
        return self._selected
    end,

    setSelected = function(self, value, text)
        self._selected = value
        if text or text == nil then
            self.text = text or (value and value.text) or self.placeholder or ""
        end
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
            local spawnNewMenu = true
            if submenu then
                -- Submenu might still exist if it was closed by clicking one of the options
                -- In which case we should spawn a new menu
                spawnNewMenu = not submenu.alive
                submenu:removeSelf()
            end
            if spawnNewMenu then
                local submenuParent = self.submenuParent or self
                local submenuData = uiu.map(self.data, function(data, i)
                    local item = self:getItemCached(data, i)
                    item.width = false
                    item.height = false
                    item:layout()
                    return item
                end)
                x = submenuParent.screenX
                y = submenuParent.screenY + submenuParent.height + submenuParent.parent.style.spacing
                self.submenu = uie.menuItemSubmenu.spawn(submenuParent, x, y, submenuData)
            end
        end
    end
})


-- Basic checkbox, behaving like a row with a label.
uie.add("checkbox", {
    base = "row",

    style = {
        padding = 0,
        spacing = 4,

        checkboxNormalBG = { 0.8, 0.8, 0.8, 0.9 },
        checkboxNormalFG = { 0, 0, 0, 0.8, 0 },
        checkboxNormalBorder = { 0.08, 0.08, 0.08, 0.6, 1 },

        checkboxDisabledBG = { 0.5, 0.5, 0.5, 0.7 },
        checkboxDisabledFG = { 0, 0, 0, 0.7, 0 },
        checkboxDisabledBorder = { 0, 0, 0, 0.7, 1 },

        checkboxHoveredBG = { 1, 1, 1, 0.9 },
        checkboxHoveredFG = { 0, 0, 0, 0.9, 1 },
        checkboxHoveredBorder = { 0, 0, 0, 0.9, 1 },

        checkboxPressedBG = { 0.95, 0.95, 0.95, 0.9 },
        checkboxPressedFG = { 0, 0, 0, 0.9, 1 },
        checkboxPressedBorder = { 0, 0, 0, 0.9, 1 },

        activeIconColor = { 0.33, 0.33, 0.33, 1.0 },
        mixedIconColor = { 0.33, 0.33, 0.33, 1.0 },
        inactiveIconColor = { 0.33, 0.33, 0.33, 1.0 }
    },

    init = function(self, label, value, cb)
        if not label or not label.__ui then
            label = uie.label(label)
        end

        local checkbox = uie.button():hook({
            layout = function(orig, self)
                local label = self.parent.label
                local checkbox = self
                local height = label.height
                local heightRounded = math.ceil(label.height / 2) * 2

                orig(self)

                checkbox.width = heightRounded
                checkbox.height = heightRounded
                checkbox.realWidth = heightRounded
                checkbox.realHeight = heightRounded
            end
        })

        checkbox.style.normalBG = self.style.checkboxNormalBG
        checkbox.style.normalFG = self.style.checkboxNormalFG
        checkbox.style.normalBorder = self.style.checkboxNormalBorder

        checkbox.style.disabledBG = self.style.checkboxDisabledBG
        checkbox.style.disabledFG = self.style.checkboxDisabledFG
        checkbox.style.disabledBorder = self.style.checkboxDisabledBorder

        checkbox.style.hoveredBG = self.style.checkboxHoveredBG
        checkbox.style.hoveredFG = self.style.checkboxHoveredFG
        checkbox.style.hoveredBorder = self.style.checkboxHoveredBorder

        checkbox.style.pressedBG = self.style.checkboxPressedBG
        checkbox.style.pressedFG = self.style.checkboxPressedFG
        checkbox.style.pressedBorder = self.style.checkboxPressedBorder

        -- Make sure the label has its height set, checkbox needs this
        label:layout()

        uie.row.init(self, { checkbox, label })

        self.checkbox = checkbox
        self.label = label
        self.enabled = true
        self.cb = cb
        self.value = value
        self.activeIcon = "ui:icons/checkboxCheckmark"
        self.mixedIcon = "ui:icons/checkboxMixed"
        self.inactiveIcon = false

        self:layout()
        self:updateIcon()
    end,

    getEnabled = function(self)
        return self._enabled
    end,

    setEnabled = function(self, value)
        self.checkbox:setEnabled(value)
        self._enabled = value
        self.interactive = value and 1 or -1
    end,

    getText = function(self)
        return self.label.text
    end,

    setText = function(self, value)
        self.label.text = value
    end,

    getValue = function(self)
        return self._value
    end,

    setValue = function(self, value)
        self._value = value
        self:updateIcon()
    end,

    centerIcon = function(self, icon)
        local width, height = icon.image:getDimensions()

        return icon:with(uiu.at(-0.5 - width / 2, -0.5 - height / 2))
    end,

    updateIcon = function(self)
        local checkbox = self.checkbox
        local children = checkbox.children or {}
        local value = self.value
        local previousValue = self._previousIconValue

        if value ~= previousValue then
            while #children > 0 do
                table.remove(children, 1)
            end
        end

        local icon
        local iconColor
        if value and self.activeIcon then
            icon = self.activeIcon
            color = self.style.activeIconColor
        elseif value == nil and self.mixedIcon then
            icon = self.mixedIcon
            color = self.style.mixedIconColor
        elseif value == false and self.inactiveIcon then
            icon = self.inactiveIcon
            color = self.style.inactiveIconColor
        end

        if icon then
            if type(icon) == "string" then
                icon = uie.icon(icon)
            end

            icon = self:centerIcon(icon)
            icon.style.color = color
            checkbox:addChild(icon)
        end

        self._previousIconValue = value

        checkbox:reflow()
    end,

    onClick = function(self, x, y, button)
        if self.enabled and button == 1 then
            self:setValue(not self:getValue())

            if self.cb then
                self:cb(self.value)
            end
        end
    end
})

return uie
