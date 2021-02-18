local ui = require("ui.main")
local uie = require("ui.elements.main")
local uiu = require("ui.utils")


local function collectAll(all, el, collection)
    el.__collection = collection
    local children = el.children
    if children then
        for i = 1, #children do
            local c = children[i]
            c.parent = el
            all[#all + 1] = c
            collectAll(all, c, collection)
        end
    end
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
                if not c.onscreen then
                    c.onscreen = true
                    c:repaint()
                end

                local cbl = max(pbl, crl)
                local cbt = max(pbt, crt)
                local cbr = min(pbr, crr)
                local cbb = min(pbb, crb)

                local clip = c.clip
                local cpbl = clip and cbl or pbl
                local cpbt = clip and cbt or pbt
                local cpbr = clip and cbr or pbr
                local cpbb = clip and cbb or pbb

                local interactive = c.interactive

                if pi and interactive >= 0 then
                    local visibleRect = c.__cached.visibleRect
                    visibleRect[1] = cbl
                    visibleRect[2] = cbt
                    visibleRect[3] = cbr
                    visibleRect[4] = cbb

                    if interactive > 0 then
                        all[#all + 1] = c
                    end

                    collectAllInteractive(all, c, crl, crt, cpbl, cpbt, cpbr, cpbb, true)
                else
                    collectAllInteractive(all, c, crl, crt, cpbl, cpbt, cpbr, cpbb, false)
                end

            else
                c.onscreen = false
                -- Doesn't need to be set false recursively.
                -- Anything that has an offscreen parent is already ignored elsewhere.
                -- Anything that was offscreen before will get its children rechecked later.
            end
        end
    end
end


-- Special root element.
uie.add("root", {
    id = "root",
    cacheable = false,
    interactive = -1,

    all = false,

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
        self:collect(false, true)
    end,

    recollect = function(self, basic, interactive)
        if basic == nil then
            self.recollectingBasic = true
            self.recollectingInteractive = true
        else
            self.recollectingBasic = basic
            self.recollectingInteractive = interactive
        end
    end,

    collect = function(self, basic, interactive)
        if basic == nil then
            basic = self.recollectingBasic
            interactive = self.recollectingInteractive
        end

        if basic then
            self.recollectingBasic = false
            local all = {}
            collectAll(all, self, self.__collection + 1)
            self.all = all
        end

        if interactive then
            self.recollectingInteractive = false
            local all = {}
            collectAllInteractive(all, self, 0, 0, 0, 0, love.graphics.getWidth(), love.graphics.getHeight(), true)
            self.allInteractive = all
        end

        return basic or interactive
    end,

    getChildAt = function(self, mx, my)
        local all = self.allInteractive
        if all then
            for i = #all, 1, -1 do
                local c = all[i]
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
