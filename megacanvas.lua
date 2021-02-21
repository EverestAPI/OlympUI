-- Runtime texture atlas generation with cached element canvases? No problem!

-- Huge thanks to Cruor and Vexatos for providing a baseline packing algo!
-- https://github.com/CelestialCartographers/Loenn/blob/e97de93321df9259c6ecc13d2660a6ea0b0d57a9/src/runtime_atlas.lua

local megacanvas = {
    debug = {
        rects = true,
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

    marked = {},

    quadFastPadding = 32,

    padding = 2,
    width = 4096,
    height = 4096
}

-- Love2D exposes a function that can get the theoretical maximum depth. It isn't accurate though.
do
    local arrayFeature = love.graphics.getTextureTypes().array

    if arrayFeature == 1 or arrayFeature == true then
        -- 4096 x 4096 x 32bit = 64MB
        -- FIXME: Dynamically grow canvas size on demand.
        local min = 1
        local max = 16

        local success, canvas = pcall(love.graphics.newCanvas, 16, 16, max, { type = "array" })
        if success then
            canvas:release()
            min = max
        else
            while max - min > 1 do
                local mid = min + math.ceil((max - min) / 2)
                success, canvas = pcall(love.graphics.newCanvas, 16, 16, mid, { type = "array" })
                if success then
                    canvas:release()
                    min = mid
                else
                    max = mid
                end
            end
        end

        success, canvas = pcall(love.graphics.newCanvas, 16, 16, min, { type = "array" })
        if success then
            canvas:release()
            megacanvas.layersMax = min
        else
            megacanvas.layersMax = false
        end

    else
        megacanvas.layersMax = false
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

local function cleanup(list, alive, deadMax)
    if alive and #list - alive < deadMax then
        return false
    end

    for i = #list, 1, -1 do
        if not list[i] then
            table.remove(list, i)
        end
    end
    return true
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
                rect(0, 0, megacanvas.width, megacanvas.height)
            }
        }
    end
end

function atlas:release()
    self.canvas:release()
end

function atlas:grow(count)
    if not self.layersMax then
        if (self.layersAllocated or 0) < 1 then
            self.canvas = love.graphics.newCanvas(megacanvas.width, megacanvas.height)
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

    canvas = love.graphics.newCanvas(megacanvas.width, megacanvas.height, count, { type = "array" })
    self.canvas = canvas

    if copies then
        -- FIXME: blend mode?

        local sX, sY, sW, sH = love.graphics.getScissor()
        local canvasPrev = love.graphics.getCanvas()
        love.graphics.push()
        love.graphics.origin()
        love.graphics.setScissor()

        for i = 1, countOld do
            local copyData = copies[i]
            local copy = love.graphics.newImage(copyData)
            love.graphics.setCanvas(canvas, i)
            love.graphics.draw(copy, 0, 0)
            copyData:release()
            copy:release()
        end

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
            return l, taken
        end
    end

    return false
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

    if not self.canvas then
        self.canvas, self.canvasWidth, self.canvasHeight, self.canvasNew = megacanvas.pool.get(width + megacanvas.quadFastPadding, height + megacanvas.quadFastPadding)
    end

    self.width = width
    self.height = height

    self.lifetime = 0
end

function quad:release(full, gc)
    if self.quad then
        -- FIXME: Merge the new free space with other free spaces.
        self.space.reclaimed = true
        self.layer.spaces[#self.layer.spaces + 1] = self.space
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
        if gc then
            -- There's a very high likelihood that the canvas has been GC'd as well if we're here.
            -- ... might as well just dispose it entirely. Whoops!
            local canvas = self.canvas
            if canvas then
                canvas:release()
            end
        elseif self.canvas then
            megacanvas.pool.free(self.canvas, self.canvasWidth, self.canvasHeight, self.canvasNew)
            self.canvas = false
        end

        megacanvas.quads[self.index] = false
        megacanvas.quadsAlive = megacanvas.quadsAlive - 1
        self.index = false
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

    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.draw(self.canvas, x, y, r, sx, sy, ox, oy, kx, ky)
    love.graphics.setBlendMode("alpha", "alphamultiply")
end

function quad:mark()
    if not self.quad and not self.marked then
        local index = #megacanvas.marked + 1
        megacanvas.marked[index] = self
        self.marked = index
    end
end



function megacanvas.pool.get(width, height)
    local pool = megacanvas.pool
    local best, index = smallest(pool, width, height)

    megacanvas.poolUsed = megacanvas.poolUsed + 1

    if best then
        megacanvas.poolAlive = megacanvas.poolAlive - 1
        pool[index] = false
        return best.canvas, best.width, best.height, false
    end

    megacanvas.poolNew = megacanvas.poolNew + 1
    return love.graphics.newCanvas(width, height), width, height, true
end

function megacanvas.pool.free(canvas, width, height, new)
    local pool = megacanvas.pool

    megacanvas.poolUsed = megacanvas.poolUsed - 1
    if new then
        megacanvas.poolNew = megacanvas.poolNew - 1
    end

    megacanvas.poolAlive = megacanvas.poolAlive + 1
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

function megacanvas.pool.sort(a, b)
    return a.width * a.height < b.width * b.height
end

function megacanvas.pool.cleanup()
    local min = 8
    local max = 24
    local deadMax = 32
    local lifetimeMax = 60 * 8

    local pool = megacanvas.pool
    local alive = megacanvas.poolAlive

    if alive >= max or #pool - alive > deadMax then
        cleanup(pool)
        alive = #pool
        if alive >= max then
            table.sort(pool, megacanvas.pool.sort)
            for i = 1, #pool - min do
                pool[1].canvas:release()
                table.remove(pool, 1)
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
                entry.canvas:release()
                pool[i] = false
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
    megacanvas.pool.cleanup()

    local lifetimeMax = 60 * 12

    local quads = megacanvas.quads

    for i = 1, #quads do
        local q = quads[i]
        if q then
            local lifetime = q.lifetime + 1
            if lifetime < lifetimeMax then
                q.lifetime = lifetime
            else
                q:release(true)
            end
        end
    end

    if cleanup(quads, megacanvas.quadsAlive, 32) then
        for i = 1, #quads do
            quads[i].index = i
        end
        megacanvas.quadsAlive = #quads
    end

    local marked = megacanvas.marked
    local markedCount = #marked
    if markedCount < 0 then
        return
    end

    local atlases = megacanvas.atlases
    local padding = megacanvas.padding

    local markedLast = math.max(1, markedCount - 4)
    for i = markedCount, markedLast, -1 do
        local q = marked[i]
        if q then
            q.marked = false

            local widthPadded = q.width + padding * 2
            local heightPadded = q.height + padding * 2

            for i = 1, #atlases do
                q.layer, q.space = atlases[i]:fit(widthPadded, heightPadded)
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

    for i = markedCount, markedLast, -1 do
        local q = marked[i]
        if q then
            marked[i] = nil

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

            if megacanvas.debug.rects then
                love.graphics.setColor(0, 1, 0, 1)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", x + 0.5, y + 0.5, widthPadded - 1, heightPadded - 1)
                love.graphics.setColor(1, 1, 1, 1)
            end

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
                    local s = spaces[si]
                    love.graphics.setScissor(s.x, s.y, s.width, s.height)
                    if s.reclaimed then
                        love.graphics.setColor(1, 0, 0, 0.5)
                        love.graphics.rectangle("fill", s.x + 0.5, s.y + 0.5, s.width - 1, s.height - 1)
                        love.graphics.setColor(1, 0, 0, 1)
                    else
                        love.graphics.clear(0, 0, 1, 0.5)
                        love.graphics.setColor(0, 0, 1, 1)
                    end
                    love.graphics.rectangle("line", s.x + 0.5, s.y + 0.5, s.width - 1, s.height - 1)
                end
            end
        end

        love.graphics.setScissor()

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
            if #l.taken > 0 then
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
