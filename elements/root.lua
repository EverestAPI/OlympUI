local ui = require("ui.main")
local uie = require("ui.elements.main")
local uiu = require("ui.utils")


local function collectAll(all, allMap, el)
    local children = el.children
    if children then
        for i = 1, #children do
            local c = children[i]
            c.parent = el
            c.onscreen = false
            all[#all + 1] = c
            local id = c.id
            if id then
                allMap[id] = c
            end
            collectAll(all, allMap, c)
        end
    end
    return all
end

local function collectAllInteractive(all, el, prl, prt, pbl, pbt, pbr, pbb, pi)
    local children = el.children
    if children then
        local min = math.min
        local max = math.max

        for i = 1, #children do
            local c = children[i]

            local crl = prl + c.realX
            local crt = prt + c.realY
            local crr = crl + c.width
            local crb = crt + c.height

            if not (
                crr < pbl or pbr < crl or
                crb < pbt or pbb < crt
            ) then
                c.onscreen = true

                local cbl = max(pbl, crl)
                local cbt = max(pbt, crt)
                local cbr = min(pbr, crr)
                local cbb = min(pbb, crb)

                local interactive = c.interactive

                if pi and interactive >= 0 then
                    local visibleRect = c.__cached.visibleRect
                    visibleRect[1] = cbl
                    visibleRect[2] = cbt
                    visibleRect[3] = cbr
                    visibleRect[4] = cbb

                    if interactive >= 1 then
                        all[#all + 1] = c
                    end

                    collectAllInteractive(all, c, crl, crt, cbl, cbt, cbr, cbb, true)
                else
                    collectAllInteractive(all, c, crl, crt, cbl, cbt, cbr, cbb, false)
                end
            end
        end
    end
    return all
end


-- Special root element.
uie.add("root", {
    id = "root",
    cacheable = false,
    init = function(self, child)
        uiu.hook(child, {
            layoutLazy = function(orig, self)
                self.width = self.parent.width
                self.height = self.parent.height
                self.reflowing = true
                self.reflowingLate = true
                orig(self)
            end
        })
        self.children = { child }
    end,

    calcSize = function(self)
        local width = 0
        local height = 0

        local max = math.max

        local children = self.children
        for i = 1, #children do
            local c = children[i]
            width = max(width, c.x + c.width)
            height = max(height, c.y + c.height)
        end

        self.innerWidth = width
        self.innerHeight = height
        self.width = width
        self.height = height
    end,

    layoutLate = function(self)
        self:layoutLateChildren()
        self:collect(true, true)
    end,

    recollect = function(self)
        self.recollecting = 1
    end,

    collect = function(self, basic, interactive)
        self.recollecting = -1

        if basic then
            self.all, self.allMap = collectAll({}, {}, self)
        end

        if interactive then
            self.allInteractive = collectAllInteractive({}, self, 0, 0, 0, 0, love.graphics.getWidth(), love.graphics.getHeight(), true)
        end
    end,

    getChildAt = function(self, mx, my)
        local allInteractive = self.allInteractive
        if allInteractive then
            for i = #allInteractive, 1, -1 do
                local c = allInteractive[i]
                local retc = nil

                while c and c ~= self do
                    local visibleRect = c.__cached.visibleRect
                    local el = visibleRect[1]
                    local et = visibleRect[2]
                    local er = visibleRect[3]
                    local eb = visibleRect[4]

                    if
                        mx < el or er < mx or
                        my < et or eb < my
                    then
                        goto next
                    end

                    retc = retc or c
                    c = c.parent
                end

                if retc then
                    return retc
                end

                ::next::
            end
        end

        return nil
    end,
})


return uie
