local ui = require("ui.main")
local uie = require("ui.elements.main")
local uiu = require("ui.utils")


-- Dynamic layout generator.
uie.add("dynamic", {
    base = "group",

    init = function(self, children)
        uie.group.init(self)
        self._allFirst = children
        self._dirty = true
    end,

    layoutLate = function(self)
        self._dirty = true
        uie.default.layoutLate(self)
    end,

    generate = function(self)
        if self.generated then
            return nil
        end

        self.generated = true
        return { uie.group({}) }
    end,

    getAll = function(self)
        local allPerRoot = {}
        local total = 0
        local roots = self.children
        for i = 1, #roots do
            local root = roots[i]
            local children = root.children
            local all = {}
            allPerRoot[i] = all
            for ii = 1, #children do
                all[#all + 1] = children[ii]
                total = total + 1
            end
        end

        local allFixed = {}
        local numRoots = #roots
        for i = 1, total, numRoots do
            for j = 0, numRoots - 1 do
                allFixed[i + j] = allPerRoot[j + 1][(i - 1) / numRoots + 1]
            end
        end
        return allFixed
    end,

    setAll = function(self, all)
        local roots = self.children
        for i = 1, #roots do
            local root = roots[i]
            root.children = {}
            root:reflow()
        end
        for i = 1, #all do
            self.next:addChild(all[i])
        end
    end,

    getNext = function(self)
        if self._dirty then
            self:update()
        end

        local roots = self.children
        local min = nil
        local minCount = math.huge
        for i = 1, #roots do
            local root = roots[i]
            local children = root.children
            local count = #children
            if count < minCount then
                min = root
                minCount = count
            end
        end
        return min
    end,

    update = function(self)
        if self._dirty then
            self._dirty = false

            local generated = self:generate()
            if generated then
                local all = self._allFirst or self.all
                self._allFirst = false

                self.children = { }
                for i = 1, #generated do
                    self:addChild(generated[i])
                end

                self.all = all
            end
        end
    end
})


return uie
