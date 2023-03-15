local ui = require("ui.main")
local uie = require("ui.elements.main")
local uiu = require("ui.utils")
require("ui.elements.basic")
require("ui.elements.layout")
require("ui.elements.input")


local listCommon = {
    cacheable = false,

    isList = true,
    cbOnItemClick = false,
    grow = true,
    recycledMax = 64,

    style = {
        spacing = 1,
        offscreen = 32,
        elementSize = false
    },

    init = function(self, data, dataToElement, cb)
        self._padStart = uie.new({
            id = "padStart",
            cacheable = false
        })

        self._padEnd = uie.new({
            id = "padEnd",
            cacheable = false
        })

        uie.column.init(self, {self._padStart, self._padEnd})

        self.enabled = true
        self._selectedIndex = 0
        self.data = data
        self.dataToElement = dataToElement or self.dataToElement
        self.cb = cb
        self.currentFirst = 0
        self.currentLast = 0
        self.shrinkOnce = false

        self._rendering = {}
        self._recycled = {}
        self._dummy = false

        self:invalidate()
    end,

    dataToElement = function(self, data, el)
        if not el then
            el = uie.listItem()
        end

        el.text = tostring(data)
        el.data = data

        return el
    end,

    getSelectedData = function(self)
        return self.data[self.selectedIndex]
    end,

    setSelectedData = function(self, value)
        local data = self.data
        for i = 1, #data do
            local d = data[i]

            if d == value then
                self.selectedIndex = i
                return
            end
        end

        self.selectedIndex = 0
    end,

    getSelectedIndex = function(self)
        return self._selectedIndex
    end,

    setSelectedIndex = function(self, value, callCb)
        self._selectedIndex = value

        if callCb ~= false --[[ and not nil ]] then
            local cb = self.cb
            if cb then
                cb(self, self.data[value])
            end
        end
    end,

    getIsSelected = function(self, element)
        return self.selectedIndex == element._magicIndex
    end,

    setIsSelected = function(self, element, value)
        self.selectedIndex = value and element._magicIndex or 0
    end,

    layoutLateLazy = function(self)
        self:layoutLate()
    end,

    getDummyElement = function(self)
        if #self.children > 2 then
            return self.children[2]
        end

        local el = self._dummy

        if el then
            return el
        end

        el = self.dataToElement(self, self.data[1], nil)
        el.parent = self
        el:reflow()
        el:layoutLazy()
        el:layoutLateLazy()

        self._dummy = el
        return el
    end,

    setElementSize = function(self, value)
        self.style.elementSize = value
    end,

    addChild = function(self, child, index)
        uie.default.addChild(self, child, index)

        if child._magicIndex then
            self._rendering[child._magicIndex] = child
        end
    end,

    removeChild = function(self, child)
        uie.default.removeChild(self, child)

        if child._magicIndex then
            self._rendering[child._magicIndex] = nil

            if #self._recycled < self.recycledMax then
                self._recycled[#self._recycled + 1] = child
            end
        end
    end,

    invalidate = function(self)
        local children = self.children

        while #children > 2 do
            self:removeChild(children[2])
        end

        self.currentFirst = 0
        self.currentLast = 0

        self._padStart.height = self.innerHeight
        self._padEnd.height = 0

        self.shrinkOnce = true

        self:reflow()
    end,

    updateView = function(self)
        local data = self.data
        local children = self.children
        local recycled = self._recycled

        if #data == 0 then
            while #children > 2 do
                self:removeChild(children[2])
            end

            return
        end

        local rendering = self._rendering
        local dataToElement = self.dataToElement

        local visibleFirst, visibleLast = self:getVisibleFirstLast()

        if visibleFirst == 0 and visibleLast == 0 then
            return
        end

        local currentFirst = self.currentFirst
        local currentLast = self.currentLast

        if visibleFirst == currentFirst and visibleLast == currentLast then
            return
        end

        -- print(currentFirst, currentLast, "->", visibleFirst, visibleLast)

        for i = currentFirst, visibleFirst - 1 do
            local el = rendering[i]

            if el then
                self:removeChild(el)
            end
        end

        for i = visibleLast + 1, currentLast do
            local el = rendering[i]

            if el then
                self:removeChild(el)
            end
        end

        for i = visibleFirst, visibleLast do
            local el = self._rendering[i]

            if not el then
                local elRecycled = recycled[#recycled]

                el = dataToElement(self, data[i], elRecycled)
                el._magicIndex = i

                if elRecycled and el == elRecycled then
                    recycled[#recycled] = nil
                end

                if #children == 2 then
                    self:addChild(el, 2)
                else
                    local min = 2
                    local max = #children - 1
                    while max - min > 1 do
                        local mid = min + math.ceil((max - min) / 2)
                        local midi = children[mid]._magicIndex
                        if i <= midi then
                            max = mid
                        else
                            min = mid
                        end
                    end

                    if i < children[min]._magicIndex then
                        self:addChild(el, min)
                    elseif i < children[max]._magicIndex then
                        self:addChild(el, max)
                    else
                        self:addChild(el, max + 1)
                    end
                end
            end
        end

        self.currentFirst = visibleFirst
        self.currentLast = visibleLast

        self._dummy = false

        -- Delayed reflow required to recalc own size properly for some reasons. The OlympUI Lua layouter is cursed.
        -- Sadly I don't have the time to port the reworked OlympUI C# layouter to Lua, so... this will do.
        -- -jade
        ui.runLate(function()
            ui.runLate(function()
                self:reflow()
            end)
        end)
    end,

    update = function(self, dt)
        self:updateView()
    end,
}




local function merge(t1, t2)
    for k, v in pairs(t2) do
        if (type(v) == "table") and (type(t1[k] or false) == "table") then
            merge(t1[k], t2[k])
        else
            t1[k] = v
        end
    end
    return t1
end

uie.add("magicList", merge({
    base = "column",

    getElementSize = function(self, el)
        return self.style.elementSize or (el or self.dummyElement).height
    end,

    getVisibleFirstLast = function(self)
        local screenY = self.screenY
        local visibleRect = self.__cached.visibleRect
        local vt = visibleRect[2] - screenY
        local vb = visibleRect[4] - screenY

        local elementSize = self.elementSize

        if elementSize <= 0 then
            return 0, 0
        end

        local offscreen = self.style.offscreen

        if (vb - vt) <= 0 then
            -- Could return 0, 0 but that would cause problems with going from 0 items to 1.
            -- Instead, always keep offscreen amount of elements onscreen at minimum.
            return 1, math.min(#self.data, offscreen)
        end

        local elementSizeSpaced = elementSize + self.style.spacing

        return math.max(0, math.floor(vt / elementSizeSpaced) - offscreen) + 1, math.min(#self.data, math.ceil(vb / elementSizeSpaced) + offscreen)
    end,

    layoutLazy = function(self)
        local padStart = self._padStart
        local padEnd = self._padEnd

        local elementSize = self.elementSize
        local spacing = self.style.spacing
        local elementSizeSpaced = elementSize + spacing

        padStart.height = (self.currentFirst - 1) * elementSizeSpaced
        padEnd.height = (#self.data - self.currentLast) * elementSizeSpaced - spacing

        self:layout()
    end,

    layoutLateChildren = function(self)
        local children = self.children
        if children then
            local width = self.innerWidth

            if self.shrinkOnce then
                for i = 1, #children do
                    local c = children[i]
                    c.parent = self
                    c.width = -1
                    c.autoWidth = -1
                    c.reflowing = true
                    c.reflowingLate = true
                    c:layoutLazy()
                    c:layoutLateLazy()
                    c.reflowingLate = true
                end
                width = 0
                self.shrinkOnce = false
            end

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

            if width ~= self.innerWidth then
                self:reflow()
            end
        end
    end,
}, listCommon))


uie.add("magicListH", merge({
    base = "row",

    getElementSize = function(self, el)
        return self.style.elementSize or (el or self.dummyElement).width
    end,

    getVisibleFirstLast = function(self)
        local screenX = self.screenX
        local visibleRect = self.__cached.visibleRect
        local vl = visibleRect[1] - screenX
        local vr = visibleRect[3] - screenX

        local elementSize = self.elementSize

        if (vr - vl) <= 0 or elementSize <= 0 then
            return 0, 0
        end

        local elementSizeSpaced = elementSize + self.style.spacing
        local offscreen = self.style.offscreen

        return math.max(0, math.floor(vl / elementSizeSpaced) - offscreen) + 1, math.min(#self.data, math.ceil(vr / elementSizeSpaced) + offscreen)
    end,

    layoutLazy = function(self)
        local padStart = self._padStart
        local padEnd = self._padEnd

        local elementSize = self.elementSize
        local spacing = self.style.spacing
        local elementSizeSpaced = elementSize + spacing

        padStart.width = (self.currentFirst - 1) * elementSizeSpaced
        padEnd.width = (#self.data - self.currentLast) * elementSizeSpaced - spacing

        self:layout()
    end,

    layoutLateChildren = function(self)
        local children = self.children
        if children then
            local height = self.innerHeight

            if self.shrinkOnce then
                for i = 1, #children do
                    local c = children[i]
                    c.parent = self
                    c.height = -1
                    c.autoHeight = -1
                    c.reflowing = true
                    c.reflowingLate = true
                    c:layoutLazy()
                    c:layoutLateLazy()
                    c.reflowingLate = true
                end
                height = 0
                self.shrinkOnce = false
            end

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

            if height ~= self.innerHeight then
                self:reflow()
            end
        end
    end,
}, listCommon))


return uie
