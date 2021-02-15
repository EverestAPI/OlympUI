local ui = require("ui.main")
local uie = require("ui.elements.main")
require("ui.elements.basic")


-- Basic vertical list.
uie.add("column", {
    base = "group",

    style = {
        spacing = 8
    },

    calcSize = function(self)
        local height = 0
        local addSpacing = false
        local spacing = self.style.spacing
        local children = self.children
        for i = 1, #children do
            local c = children[i]
            if addSpacing then
                height = height + spacing
            end
            height = height + c.height
            addSpacing = true
        end
        return uie.panel.calcSize(self, nil, height)
    end,

    layoutChildren = function(self)
        local style = self.style
        local padding = style.padding
        local paddingL, paddingT
        if type(padding) == "table" then
            paddingL, paddingT = padding[1], padding[2]
        else
            paddingL, paddingT = padding, padding
        end
        local y = paddingT
        local spacing = style.spacing
        local children = self.children
        for i = 1, #children do
            local c = children[i]
            c.parent = self
            c:layoutLazy()
            y = y + c.y
            c.realX = c.x + paddingL
            c.realY = y
            y = y + c.height + spacing
        end
    end
})


-- Basic horizontal list.
uie.add("row", {
    base = "group",

    style = {
        spacing = 8
    },

    calcSize = function(self)
        local width = 0
        local addSpacing = false
        local spacing = self.style.spacing
        local children = self.children
        for i = 1, #children do
            local c = children[i]
            if addSpacing then
                width = width + spacing
            end
            width = width + c.width
            addSpacing = true
        end
        return uie.panel.calcSize(self, width, nil)
    end,

    layoutChildren = function(self)
        local style = self.style
        local padding = style.padding
        local paddingL, paddingT
        if type(padding) == "table" then
            paddingL, paddingT = padding[1], padding[2]
        else
            paddingL, paddingT = padding, padding
        end
        local x = paddingL
        local spacing = style.spacing
        local children = self.children
        for i = 1, #children do
            local c = children[i]
            c.parent = self
            c:layoutLazy()
            x = x + c.x
            c.realX = x
            c.realY = c.y + paddingT
            x = x + c.width + spacing
        end
    end
})


-- TODO: flowRow
-- TODO: flowColumn


return uie
