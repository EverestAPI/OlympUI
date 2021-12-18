-- Runtime texture atlas generation with cached element canvases? No problem!

-- Huge thanks to Cruor and Vexatos for providing a baseline packing algo!
-- https://github.com/CelestialCartographers/Loenn/blob/e97de93321df9259c6ecc13d2660a6ea0b0d57a9/src/runtime_atlas.lua

local megacanvas = {
    debug = {
        rects = true,
        errorCanvaslessQuads = true,
    },

    convertBlend = true,
    convertBlendShader = love.graphics.newShader([[
        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
            vec4 c = Texel(tex, texture_coords);
            return vec4(c.rgb / c.a, c.a) * color;
        }
    ]]),

    pool = {},
    poolAlive = 0,
    poolUsed = 0,
    poolNew = 0,

    atlases = {},

    quads = setmetatable({}, { __mode = "v" }),
    quadsAlive = 0,

    managedCanvases = setmetatable({}, { __mode = "k" }),

    marked = {},

    quadFastPadding = 32,

    padding = 2
}

-- Love2D exposes a function that can get the theoretical maximum depth. It isn't accurate though.
do
    local arrayFeature = love.graphics.getTextureTypes().array

    local sizeArray = 2048
    local sizeSingle = 4096

    megacanvas.widthMax = sizeSingle
    megacanvas.heightMax = sizeSingle

    if arrayFeature == 1 or arrayFeature == true then
        local min = 1
        local max = 16

        local success, canvas = pcall(love.graphics.newCanvas, sizeArray, sizeArray, max, { type = "array" })
        if success then
            canvas:release()
            min = max
        else
            while max - min > 1 do
                local mid = min + math.ceil((max - min) / 2)
                success, canvas = pcall(love.graphics.newCanvas, sizeArray, sizeArray, mid, { type = "array" })
                if success then
                    canvas:release()
                    min = mid
                else
                    max = mid
                end
            end
        end

        success, canvas = pcall(love.graphics.newCanvas, sizeArray, sizeArray, min, { type = "array" })
        if success then
            canvas:release()
            megacanvas.layersMax = min
            megacanvas.width = sizeArray
            megacanvas.height = sizeArray
        else
            megacanvas.layersMax = false
            megacanvas.width = sizeSingle
            megacanvas.height = sizeSingle
        end

    else
        megacanvas.layersMax = false
        megacanvas.width = sizeSingle
        megacanvas.height = sizeSingle
    end
end



local function rect(x, y, width, height)
    if width < 0 then
        x = x + width
        width = -width
    end
    if height < 0 then
        y = y + height
        height = -height
    end
    return {
        x = x,
        y = y,
        width = width,
        height = height,
        r = x + width,
        b = y + height
    }
end

local function rectSub(r1, r2)
    local tlx = math.max(r1.x, r2.x)
    local tly = math.max(r1.y, r2.y)
    local brx = math.min(r1.x + r1.width, r2.x + r2.width)
    local bry = math.min(r1.y + r1.height, r2.y + r2.height)

    if tlx >= brx or tly >= bry  then
        -- No intersection
        return {r1}
    end

    local remaining = {}

    if r2.width < r2.height then
        -- Large left rectangle
        if tlx > r1.x then
            table.insert(remaining, rect(r1.x, r1.y, tlx - r1.x, r1.height))
        end

        -- Large right rectangle
        if brx < r1.x + r1.width then
            table.insert(remaining, rect(brx, r1.y, r1.x + r1.width - brx, r1.height))
        end

        -- Small top rectangle
        if tly > r1.y then
            table.insert(remaining, rect(tlx, r1.y, brx - tlx, tly - r1.y))
        end

        -- Small bottom rectangle
        if bry < r1.y + r1.height then
            table.insert(remaining, rect(tlx, bry, brx - tlx, r1.y + r1.height - bry))
        end

    else
        -- Small left rectangle
        if tlx > r1.x then
            table.insert(remaining, rect(r1.x, tly, tlx - r1.x, bry - tly))
        end

        -- Small right rectangle
        if brx < r1.x + r1.width then
            table.insert(remaining, rect(brx, tly, r1.x + r1.width - brx, bry - tly))
        end

        -- Large top rectangle
        if tly > r1.y then
            table.insert(remaining, rect(r1.x, r1.y, r1.width, tly - r1.y))
        end

        -- Large bottom rectangle
        if bry < r1.y + r1.height then
            table.insert(remaining, rect(r1.x, bry, r1.width, r1.y + r1.height - bry))
        end
    end

    return remaining
end

local function smallest(rects, width, height)
    local best, index
    for i = #rects, 1, -1 do
        local r = rects[i]
        if r and width <= r.width and height <= r.height then
            if not best or
                (r.width < best.width and r.height < best.height) or
                (width < height and r.width <= best.width or r.height <= best.height) then
                best = r
                index = i
                if width == r.width and height == r.height then
                    break
                end
            end
        end
    end
    return best, index
end

local function cleanupList(list, alive, deadMax)
    if alive and #list - alive < deadMax then
        return false
    end

    -- FIXME: Verify if this is enough to fix the "iterating over cleaned list can give false or nil" bug.
    for key, _ in pairs(list) do
        if not list[key] then
            list[key] = nil
        end
    end

    local removed = false
    for i = #list, 1, -1 do
        if not list[i] then
            table.remove(list, i)
            removed = i
        end
    end
    return removed
end


local atlas = {}

local mtAtlas = {
    __name = "ui.megacanvases.atlas",
    __index = atlas
}

function atlas:init()
    self.width = megacanvas.width
    self.height = megacanvas.height
    self.layers = {}
    self.layersMax = megacanvas.layersMax
    self:grow(1)
    for i = 1, self.layersMax or 1 do
        self.layers[i] = {
            atlas = self,
            index = i,
            layer = self.layersMax and i or nil,
            taken = {},
            spaces = {
                rect(0, 0, self.width, self.height)
            },
            reclaimed = 0,
            reclaimedPrev = 0,
            reclaimedFrames = 0
        }
    end
end

function atlas:release()
    self.canvas:release()
end

function atlas:grow(count)
    if not self.layersMax then
        if (self.layersAllocated or 0) < 1 then
            self.canvas = love.graphics.newCanvas(self.width, self.height)
            self.layersAllocated = 1
        end
        return
    end

    local countOld = self.layersAllocated or 0
    if count <= countOld then
        return
    end
    self.layersAllocated = count

    local canvas = self.canvas

    -- Copy all data from VRAM to RAM first, otherwise we might run out of VRAM trying to hold both canvases.
    local copies
    if canvas then
        copies = {}
        for i = 1, countOld do
            copies[i] = canvas:newImageData(i)
        end
        canvas:release()
    end

    canvas = love.graphics.newCanvas(self.width, self.height, count, { type = "array" })
    self.canvas = canvas

    if copies then
        local sX, sY, sW, sH = love.graphics.getScissor()
        local canvasPrev = love.graphics.getCanvas()
        love.graphics.push()
        love.graphics.origin()
        love.graphics.setScissor()
        love.graphics.setBlendMode("alpha", "premultiplied")

        -- Apparently DPI scale agnostic images are a myth with Love2D and its embedded scaling (defaulting to system scale) needs to be undone on draw.
        local scale = 1 / love.graphics.getDPIScale()

        for i = 1, countOld do
            local copyData = copies[i]
            local copy = love.graphics.newImage(copyData)
            love.graphics.setCanvas(canvas, i)
            love.graphics.draw(copy, 0, 0, 0, scale, scale)
            copyData:release()
            copy:release()
        end

        love.graphics.setBlendMode("alpha", "alphamultiply")
        love.graphics.pop()
        love.graphics.setCanvas(canvasPrev)
        love.graphics.setScissor(sX, sY, sW, sH)
    end
end

function atlas:fit(width, height)
    local layers = self.layers
    for li = 1, #layers do
        local l = layers[li]

        local spaces = l.spaces
        local space, index = smallest(l.spaces, width, height)

        if space then
            local taken = rect(space.x, space.y, width, height)
            local full = true

            if taken.width < taken.height then
                --[[
                    +-----------+-----------+
                    |taken      |taken.r    |
                    |           |space.y    |
                    |           |s.r - t.r  |
                    |           |space.h    |
                    +-----------+           |
                    |space.x    |           |
                    |taken.b    |           |
                    |taken.w    |           |
                    |s.b - t.b  |           |
                    |           |           |
                    +-----------------------+
                ]]
                if taken.r < space.r then
                    spaces[index] = rect(taken.r, space.y, space.r - taken.r, space.height)
                    index = #spaces + 1
                    full = false
                end
                if taken.b < space.b then
                    spaces[index] = rect(space.x, taken.b, taken.width, space.b - taken.b)
                    index = #spaces + 1
                    full = false
                end

            else
                --[[
                    +-----------+-----------+
                    |taken      |taken.r    |
                    |           |space.y    |
                    |           |s.r - t.r  |
                    |           |taken.h    |
                    +-----------+-----------+
                    |space.x                |
                    |taken.b                |
                    |space.w                |
                    |s.b - t.b              |
                    |                       |
                    +-----------------------+
                ]]
                if taken.r < space.r then
                    spaces[index] = rect(taken.r, space.y, space.r - taken.r, taken.height)
                    index = #spaces + 1
                    full = false
                end
                if taken.b < space.b then
                    spaces[index] = rect(space.x, taken.b, space.width, space.b - taken.b)
                    index = #spaces + 1
                    full = false
                end
            end

            -- TODO merge adjacent rectangles
            -- TODO overlap rectangles

            if full then
                table.remove(spaces, index)
            end

            self:grow(l.index)
            index = #l.taken + 1
            l.taken[index] = taken
            taken.index = index
            return l, taken
        end
    end

    return false
end

function atlas:cleanup()
    local layers = self.layers
    for li = 1, #layers do
        local l = layers[li]

        local reclaimed = l.reclaimed
        local reclaimedFrames = l.reclaimedFrames

        if reclaimed >= 16 or (reclaimed >= 8 and reclaimed == l.reclaimedPrev) then
            reclaimedFrames = reclaimedFrames + 1
        else
            reclaimedFrames = 0
            l.reclaimedPrev = reclaimed
        end

        if reclaimedFrames < 30 and reclaimed < 32 then
            l.reclaimedFrames = reclaimedFrames

        else
            l.reclaimedFrames = 0
            local taken = l.taken
            local spaces = {
                rect(0, 0, self.width, self.height)
            }

            for ti = 1, #taken do
                local t
                -- FIXME: taken shouldn't contain holes yet sometimes it does?!
                -- FIXME: Even with cleanupList, t can sometimes be nil (not false but NIL)?!!
                repeat
                    t = taken[ti]
                    if not t then
                        table.remove(taken, ti)
                    end
                until t or ti > #taken
                if not t then
                    break
                end

                t.index = ti

                -- In case of debugging emergency, break glass and print(svg .. "</svg>\n")
                --[===[
                local svg = string.format([[
<svg xmlns="http://www.w3.org/2000/svg" width="%d" viewBox="0 0 %d %d">
]], self.width / 8, self.width, self.height)

                local function svgrect(text, r, attrs)
                    svg = svg .. string.format([[
    <rect debug="%s" x="%d" y="%d" width="%d" height="%d" %s/>
]], text, r.x, r.y, r.width, r.height, attrs)
                end

                svgrect("bg", rect(0, 0, self.width, self.height), [[fill="none" stroke="rgba(0, 0, 0, 1)" stroke-width="1px"]])

                for si = 1, #spaces do
                    svgrect("space " .. tostring(si), spaces[si], [[fill="rgba(0, 0, 255, 0.5)" stroke="rgba(0, 0, 255, 1)" stroke-width="1px"]])
                end

                for tti = 1, ti - 1 do
                    svgrect("taken " .. tostring(tti), taken[tti], [[fill="rgba(0, 255, 0, 0.2)" stroke="rgba(0, 255, 0, 1)" stroke-width="1px"]])
                end

                svgrect("taken " .. tostring(ti), t, [[fill="rgba(0, 255, 0, 1)" stroke="rgba(0, 255, 0, 1)" stroke-width="1px"]])
                ]===]

                for si = #spaces, 1, -1 do
                    local s = spaces[si]
                    local result = rectSub(s, t)
                    table.remove(spaces, si)
                    for ri = 1, #result do
                        ---svgrect("new " .. tostring(si) .. " " .. tostring(ri), result[ri], [[fill="rgba(255, 0, 0, 0.2)" stroke="rgba(255, 0, 0, 1)" stroke-width="1px"]])
                        table.insert(spaces, result[ri])
                    end
                end
            end

            l.spaces = spaces
            l.reclaimed = 0
        end
    end
end



local quad = {}

local mtQuad = {
    __name = "ui.megacanvases.megaquad",
    __index = quad,
    __gc = function(self)
        self:release(true, true)
    end
}

function quad:init(width, height)
    self:release()

    if not width then
        width = self.width
        height = self.height
    end

    if self.canvas and (self.canvasWidth < width or self.canvasHeight < height) then
        megacanvas.pool.free(self.canvas, self.canvasWidth, self.canvasHeight, self.canvasNew)
        self.canvas = nil
    end

    if width > megacanvas.widthMax or height > megacanvas.heightMax then
        error(string.format("Requested pooled canvas size too large: %d x %d - maximum allowed is %d x %d", width, height, megacanvas.widthMax, megacanvas.heightMax))
    end

    if not self.canvas then
        self.canvas, self.canvasWidth, self.canvasHeight, self.canvasNew = megacanvas.pool.get(
            math.min(megacanvas.widthMax, math.ceil(width / megacanvas.quadFastPadding + 1) * megacanvas.quadFastPadding),
            math.min(megacanvas.heightMax, math.ceil(height / megacanvas.quadFastPadding + 1) * megacanvas.quadFastPadding)
        )
    end

    self.width = width
    self.height = height

    self.large = width > (megacanvas.width - megacanvas.padding) or height > (megacanvas.height - megacanvas.padding)

    self.lifetime = 0
end

function quad:release(full, gc)
    if self.quad then
        local space = self.space
        space.reclaimed = true
        local layer = self.layer
        local taken = layer.taken
        table.remove(taken, space.index)
        for i = space.index, #taken do
            taken[i].index = i
        end
        layer.spaces[#layer.spaces + 1] = space
        layer.reclaimed = layer.reclaimed + 1
        self.space = false
        self.quad = false
        self.layer = false
        self.converted = false
    end

    if self.marked then
        megacanvas.marked[self.marked] = false
        self.marked = false
    end

    if full then
        local canvas = self.canvas
        if canvas then
            self.canvas = false
            if gc then
                -- There's a very high likelihood that the canvas has been GC'd as well if we're here.
                -- ... might as well just dispose it entirely. Whoops!
                megacanvas.managedCanvases[canvas] = nil
                canvas:release()
                megacanvas.pool.free(false, self.canvasWidth, self.canvasHeight, self.canvasNew)
            else
                megacanvas.pool.free(canvas, self.canvasWidth, self.canvasHeight, self.canvasNew)
            end
        end

        local index = self.index
        if index then
            self.index = false
            megacanvas.quads[index] = false
            megacanvas.quadsAlive = megacanvas.quadsAlive - 1
        end
    end
end

function quad:draw(x, y, r, sx, sy, ox, oy, kx, ky)
    self.lifetime = 0

    local quad = self.quad
    if quad then
        local layer = self.layer
        local converted = self.converted
        if not converted then
            love.graphics.setBlendMode("alpha", "premultiplied")
            local layer = self.layer
            if layer.layer then
                love.graphics.drawLayer(layer.atlas.canvas, layer.layer, quad, x, y, r, sx, sy, ox, oy, kx, ky)
            else
                love.graphics.draw(layer.atlas.canvas, quad, x, y, r, sx, sy, ox, oy, kx, ky)
            end
            love.graphics.setBlendMode("alpha", "alphamultiply")

        else
            if layer.layer then
                return love.graphics.drawLayer(layer.atlas.canvas, layer.layer, quad, x, y, r, sx, sy, ox, oy, kx, ky)
            else
                return love.graphics.draw(layer.atlas.canvas, quad, x, y, r, sx, sy, ox, oy, kx, ky)
            end
        end
        return
    end

    if self.canvas then
        love.graphics.setBlendMode("alpha", "premultiplied")
        love.graphics.draw(self.canvas, x, y, r, sx, sy, ox, oy, kx, ky)
        love.graphics.setBlendMode("alpha", "alphamultiply")
    elseif megacanvas.debug.errorCanvaslessQuads then
        error("Trying to draw a megacanvas quad without an assigned canvas")
    end
end

function quad:mark()
    if not self.quad and not self.marked and not self.large then
        local index = #megacanvas.marked + 1
        megacanvas.marked[index] = self
        self.marked = index
    end
end



function megacanvas.pool.get(width, height)
    local pool = megacanvas.pool

    ::retry::
    local best, index = smallest(pool, width, height)

    megacanvas.poolUsed = megacanvas.poolUsed + 1

    if best then
        megacanvas.poolAlive = megacanvas.poolAlive - 1
        pool[index] = false

        if tostring(best.canvas) == "Canvas: NULL" then
            print(debug.traceback("GETTING A RELEASED CANVAS FROM THE POOL!"))
            goto retry
        end

        return best.canvas, best.width, best.height, false
    end

    megacanvas.poolNew = megacanvas.poolNew + 1
    local canvas = love.graphics.newCanvas(width, height)

    local mt = getmetatable(canvas)
    if not mt.__megacanvasPoolRelease then
        mt.__megacanvasPoolRelease = true
        local release = mt.__index.release
        mt.__index.release = function(self, ...)
            if megacanvas.managedCanvases[self] then
                print(debug.traceback("RELEASING POOL-MANAGED CANVAS THAT IS STILL IN USE! " .. tostring(canvas)))
            end
            return release(self, ...)
        end
    end

    megacanvas.managedCanvases[canvas] = true
    return canvas, width, height, true
end

function megacanvas.pool.free(canvas, width, height, new)
    megacanvas.poolUsed = megacanvas.poolUsed - 1
    if new then
        megacanvas.poolNew = megacanvas.poolNew - 1
    end

    if canvas then
        if tostring(canvas) == "Canvas: NULL" then
            print(debug.traceback("FREEING A RELEASED CANVAS TO THE POOL!"))
            return
        end

        megacanvas.poolAlive = megacanvas.poolAlive + 1
        local pool = megacanvas.pool
        for i = 1, #pool + 1 do
            if not pool[i] then
                pool[i] = {
                    canvas = canvas,
                    width = width,
                    height = height,
                    lifetime = 0
                }
                break
            end
        end
    end
end

function megacanvas.pool.sort(a, b)
    return a.width * a.height < b.width * b.height
end

function megacanvas.pool.cleanup()
    local min = 8
    local max = 24
    local deadMax = 32
    local lifetimeMax = 60 * 10

    local pool = megacanvas.pool
    local alive = megacanvas.poolAlive

    if alive >= max or #pool - alive > deadMax then
        cleanupList(pool)
        alive = #pool
        if alive >= max then
            table.sort(pool, megacanvas.pool.sort)
            for i = #pool - min - 1, 1, -1 do
                local canvas = pool[i].canvas
                megacanvas.managedCanvases[canvas] = nil
                canvas:release()
                table.remove(pool, i)
            end
            alive = min
        end
    end

    for i = #pool, 1, -1 do
        local entry = pool[i]
        if entry then
            local lifetime = entry.lifetime + 1
            if lifetime < lifetimeMax then
                entry.lifetime = lifetime
            else
                local canvas = entry.canvas
                megacanvas.managedCanvases[canvas] = nil
                canvas:release()
                table.remove(pool, i)
                alive = alive - 1
            end
        end
    end

    megacanvas.poolAlive = alive
end

function megacanvas.newAtlas()
    local a = setmetatable({}, mtAtlas)

    local index = #megacanvas.atlases + 1
    a.index = index
    megacanvas.atlases[index] = a

    a:init()
    return a
end

function megacanvas.new(width, height)
    local q = setmetatable({}, mtQuad)

    if _G.newproxy then
        local proxy = _G.newproxy(true)
        getmetatable(proxy).__gc = function()
            mtQuad.__gc(q)
        end
        q.__proxy = proxy
    end

    local index = #megacanvas.quads + 1
    q.index = index
    megacanvas.quads[index] = q
    megacanvas.quadsAlive = megacanvas.quadsAlive + 1

    q:init(width, height)
    return q
end

function megacanvas.process()
    local lifetimeMax = 60 * 5

    local quads = megacanvas.quads
    local quadsAlive = true

    for i = 1, #quads do
        local q = quads[i]
        if q then
            local lifetime = q.lifetime + 1
            if lifetime < lifetimeMax then
                q.lifetime = lifetime
            else
                q:release(true)
                quadsAlive = false
            end
        end
    end

    local cleaned = cleanupList(quads, quadsAlive and megacanvas.quadsAlive, 32)
    if cleaned then
        for i = cleaned, #quads do
            quads[i].index = i
        end
        megacanvas.quadsAlive = #quads
    end

    local atlases = megacanvas.atlases
    for ai = 1, #atlases do
        atlases[ai]:cleanup()
    end

    megacanvas.pool.cleanup()

    local marked = megacanvas.marked
    local markedCount = #marked
    if markedCount < 0 then
        return
    end

    local padding = megacanvas.padding

    local markedLast = math.max(1, markedCount - 4)
    for mi = markedCount, markedLast, -1 do
        local q = marked[mi]
        if q then
            q.marked = false

            local widthPadded = q.width + padding * 2
            local heightPadded = q.height + padding * 2

            for ai = 1, #atlases do
                q.layer, q.space = atlases[ai]:fit(widthPadded, heightPadded)
                if q.layer then
                    break
                end
            end

            if not q.layer then
                q.layer, q.space = megacanvas.newAtlas():fit(widthPadded, heightPadded)
            end
        end
    end

    local sX, sY, sW, sH = love.graphics.getScissor()
    local canvasPrev = love.graphics.getCanvas()
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setBlendMode("alpha", "premultiplied")
    local shaderPrev
    if megacanvas.convertBlend then
        love.graphics.getShader()
        love.graphics.setShader(megacanvas.convertBlendShader)
    end
    love.graphics.setColor(1, 1, 1, 1)

    for mi = markedCount, markedLast, -1 do
        local q = marked[mi]
        if q then
            marked[mi] = nil

            local widthPadded = q.width + padding * 2
            local heightPadded = q.height + padding * 2
            local layer = q.layer
            local space = q.space

            local x = space.x
            local y = space.y

            if layer.layer then
                love.graphics.setCanvas(layer.atlas.canvas, layer.layer)
            else
                love.graphics.setCanvas(layer.atlas.canvas)
            end
            love.graphics.setScissor(x, y, widthPadded, heightPadded)
            love.graphics.clear(0, 0, 0, 0)

            x = x + padding
            y = y + padding

            local quad = love.graphics.newQuad(0, 0, q.width, q.height, q.canvasWidth, q.canvasHeight)
            love.graphics.draw(q.canvas, x, y)

            megacanvas.pool.free(q.canvas, q.canvasWidth, q.canvasHeight, q.canvasNew)
            q.canvas = nil

            quad:setViewport(x, y, q.width, q.height, layer.atlas.width, layer.atlas.height)
            q.quad = quad
            q.converted = megacanvas.convertBlend
        end
    end

    if megacanvas.convertBlend then
        love.graphics.setShader(shaderPrev)
    end
    love.graphics.setBlendMode("alpha", "alphamultiply")
    love.graphics.pop()
    love.graphics.setCanvas(canvasPrev)
    love.graphics.setScissor(sX, sY, sW, sH)
end

function megacanvas.dump(prefix)
    local atlases = megacanvas.atlases
    local quads = megacanvas.quads

    if megacanvas.debug.rects then
        local sX, sY, sW, sH = love.graphics.getScissor()
        local canvasPrev = love.graphics.getCanvas()
        love.graphics.push()
        love.graphics.origin()
        love.graphics.setScissor()
        love.graphics.setLineWidth(1)

        local atlases = megacanvas.atlases
        for ai = 1, #atlases do
            local a = atlases[ai]
            local canvas = a.canvas
            local layers = a.layers
            for li = 1, a.layersAllocated do
                local l = layers[li]
                if l.layer then
                    love.graphics.setCanvas(canvas, l.layer)
                else
                    love.graphics.setCanvas(canvas)
                end
                local spaces = l.spaces
                for si = 1, #spaces do
                    local r = spaces[si]
                    if r.reclaimed then
                        love.graphics.setColor(0.5, 0, 0, 0.5)
                        love.graphics.rectangle("fill", r.x + 0.5, r.y + 0.5, r.width - 1, r.height - 1)
                    else
                        love.graphics.setColor(0, 0, 0.5, 0.5)
                        love.graphics.rectangle("fill", r.x + 0.5, r.y + 0.5, r.width - 1, r.height - 1)
                    end
                end
                for si = 1, #spaces do
                    local r = spaces[si]
                    if r.reclaimed then
                        love.graphics.setColor(1, 0, 0, 1)
                    else
                        love.graphics.setColor(0, 0, 1, 1)
                    end
                    love.graphics.rectangle("line", r.x + 0.5, r.y + 0.5, r.width - 1, r.height - 1)
                end
                local taken = l.taken
                for ti = 1, #taken do
                    local r = taken[ti]
                    love.graphics.setColor(0, 1, 0, 1)
                    love.graphics.rectangle("line", r.x + 0.5, r.y + 0.5, r.width - 1, r.height - 1)
                end
            end
        end

        for qi = 1, #quads do
            local q = quads[qi]
            if q and q.canvas and q.quad then
                love.graphics.setCanvas(q.canvas)
                love.graphics.setColor(1, 0, 0, 0.5)
                love.graphics.rectangle("fill", 0, 0, q.width, q.height)
            end
        end

        love.graphics.pop()
        love.graphics.setCanvas(canvasPrev)
        love.graphics.setScissor(sX, sY, sW, sH)
    end

    for ai = 1, #atlases do
        local a = atlases[ai]
        local canvas = a.canvas
        local layers = a.layers
        for li = 1, a.layersAllocated or 1 do
            local l = layers[li]
            local fh = io.open(prefix .. string.format("atlas_%d_layer_%d.png", ai, li), "wb")
            if fh then
                local id = canvas:newImageData(l.layer)
                local fd = id:encode("png")
                id:release()
                fh:write(fd:getString())
                fh:close()
                fd:release()
            end
        end
    end

    for qi = 1, #quads do
        local q = quads[qi]
        if q and q.canvas then
            local fh = io.open(prefix .. string.format("quad_%d.png", qi), "wb")
            if fh then
                local id = q.canvas:newImageData()
                local fd = id:encode("png")
                id:release()
                fh:write(fd:getString())
                fh:close()
                fd:release()
            end
        end
    end
end

return setmetatable(megacanvas, {
    __call = function(self, ...)
        return self.new(...)
    end
})
