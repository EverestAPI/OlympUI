-- Runtime texture atlas generation with cached element canvases? No problem!

-- Huge thanks to Cruor and Vexatos for providing a baseline packing algo!
-- https://github.com/CelestialCartographers/Loenn/blob/e97de93321df9259c6ecc13d2660a6ea0b0d57a9/src/runtime_atlas.lua

local megacanvas = {
    debug = {
        rects = true,
    },

    pages = {},
    pagesCount = 0,

    quads = setmetatable({}, { __mode = "v" }),
    quadsCount = 0,
    quadsAlive = 0,

    marked = {},
    markedCount = 0,

    padding = 2,
    width = 4096,
    height = 4096
}

-- Love2D exposes a function that can get the theoretical maximum depth. It isn't accurate though.
do
    local arrayFeature = love.graphics.getTextureTypes().array

    if arrayFeature == 1 or arrayFeature == true then
        -- 4096 x 4096 x 32bit = 64MB
        -- FIXME: dynamically grow canvas size on demand
        local min = 1
        local max = 4

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
            megacanvas.layers = min
        else
            megacanvas.layers = false
        end

    else
        megacanvas.layers = false
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


local page = {}

local mtPage = {
    __name = "ui.megacanvases.page",
    __index = page
}

function page:init()
    if megacanvas.layers then
        self.canvas = love.graphics.newCanvas(megacanvas.width, megacanvas.height, megacanvas.layers, { type = "array" })
    else
        self.canvas = love.graphics.newCanvas(megacanvas.width, megacanvas.height)
    end
    self.width = megacanvas.width
    self.height = megacanvas.height
    self.layers = {}
    for i = 1, megacanvas.layers or 1 do
        self.layers[i] = {
            index = i,
            layer = megacanvas.layers and i,
            count = 0,
            taken = {},
            spaces = {
                rect(0, 0, megacanvas.width, megacanvas.height)
            }
        }
    end
end

function page:release()
    self.canvas:release()
end

function page:fit(width, height)
    local layers = self.layers
    local min = math.min
    local max = math.max
    for li = 1, megacanvas.layers or 1 do
        local l = layers[li]

        local spaces = l.spaces
        local smallest = false
        local index = false
        for i = 1, #spaces do
            local r1 = spaces[i]
            if width <= r1.width and height <= r1.height then
                if not smallest or
                    (r1.width < smallest.width and r1.height < smallest.height) or
                    (width < height and r1.width <= smallest.width or r1.height <= smallest.height) then
                    smallest = r1
                    index = i
                    if width == r1.width and height == r1.height then
                        break
                    end
                end
            end
        end

        if smallest then
            local r1 = smallest
            if width <= r1.width and height <= r1.height then
                local r2 = rect(r1.x, r1.y, width, height)

                local tlx = max(r1.x, r2.x)
                local tly = max(r1.y, r2.y)
                local brx = min(r1.r, r2.r)
                local bry = min(r1.b, r2.b)

                local remove = true

                if r2.width < r2.height then
                    -- Prefer large left / right rectangles.

                    -- Left rectangle
                    if tlx > r1.x then
                        spaces[index] = rect(r1.x, r1.y, tlx - r1.x, r1.height)
                        index = #spaces + 1
                        remove = false
                    end

                    -- Right rectangle
                    if brx < r1.r then
                        spaces[index] = rect(brx, r1.y, r1.r - brx, r1.height)
                        index = #spaces + 1
                        remove = false
                    end

                    -- Top rectangle
                    if tly > r1.y then
                        spaces[index] = rect(tlx, r1.y, brx - tlx, tly - r1.y)
                        index = #spaces + 1
                        remove = false
                    end

                    -- Bottom rectangle
                    if bry < r1.b then
                        spaces[index] = rect(tlx, bry, brx - tlx, r1.b - bry)
                        index = #spaces + 1
                        remove = false
                    end

                else
                    -- Prefer large top / bottom rectangles.

                    -- Left rectangle
                    if tlx > r1.x then
                        spaces[index] = rect(r1.x, r1.y, tlx - r1.x, bry - tly)
                        index = #spaces + 1
                        remove = false
                    end

                    -- Right rectangle
                    if brx < r1.r then
                        spaces[index] = rect(brx, r1.y, r1.r - brx, bry - tly)
                        index = #spaces + 1
                        remove = false
                    end

                    -- Top rectangle
                    if tly > r1.y then
                        spaces[index] = rect(tlx, r1.y, r1.width, tly - r1.y)
                        index = #spaces + 1
                        remove = false
                    end

                    -- Bottom rectangle
                    if bry < r1.b then
                        spaces[index] = rect(tlx, bry, r1.width, r1.b - bry)
                        index = #spaces + 1
                        remove = false
                    end
                end

                -- TODO merge adjacent rectangles
                -- TODO overlap rectangles

                if remove then
                    table.remove(spaces, index)
                end

                index = l.count + 1
                l.taken[index] = r2
                l.count = index
                return self, self.canvas, l.layer, r2.x, r2.y
            end
        end
    end

    return false
end



local quad = {}

local mtQuad = {
    __name = "ui.megacanvases.megaquad",
    __index = quad,
    __gc = function(self)
        self:release(true)
    end
}

function quad:init(width, height)
    self:release()

    if not width then
        width = self.width
        height = self.height
    end

    if self.canvas and (self.canvasWidth ~= width or self.canvasHeight ~= height) then
        self.canvas:release()
        self.canvas = nil
    end

    if not self.canvas then
        self.canvas = love.graphics.newCanvas(width, height)
    end

    self.width = width
    self.canvasWidth = width
    self.height = height
    self.canvasHeight = height
end

function quad:release(full)
    -- FIXME: FREE THE QUAD. MAKE IT REUSED.

    self.quad = false

    if self.markedIndex then
        table.remove(megacanvas.marked, self.markedIndex)
        megacanvas.markedCount = megacanvas.markedCount - 1
        self.markedIndex = false
    end

    if full then
        local old = self.canvas
        if old then
            old:release()
        end

        megacanvas.quads[self.index] = nil
        megacanvas.quadsAlive = megacanvas.quadsAlive - 1
    end
end

function quad:draw(x, y, r, sx, sy, ox, oy, kx, ky)
    local quad = self.quad
    if quad then
        local layer = self.megalayer
        if layer then
            return love.graphics.drawLayer(self.megacanvas, layer, quad, x, y, r, sx, sy, ox, oy, kx, ky)
        else
            return love.graphics.draw(self.megacanvas, quad, x, y, r, sx, sy, ox, oy, kx, ky)
        end
    end

    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.draw(self.canvas, x, y, r, sx, sy, ox, oy, kx, ky)
    love.graphics.setBlendMode("alpha", "alphamultiply")
end

function quad:mark()
    if not self.quad and not self.markedIndex then
        local index = megacanvas.markedCount + 1
        megacanvas.marked[index] = self
        megacanvas.markedCount = index
        self.markedIndex = index
    end
end



megacanvas.blitfix = love.graphics.newShader([[
    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
        vec4 c = Texel(tex, texture_coords);
        return vec4(c.rgb / c.a, c.a) * color;
    }
]])

function megacanvas.newPage()
    local p = setmetatable({}, mtPage)

    local index = megacanvas.pagesCount + 1
    p.index = index
    megacanvas.pages[index] = p
    megacanvas.pagesCount = index

    p:init()
    return p
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

    local index = megacanvas.quadsCount + 1
    q.index = index
    megacanvas.quads[index] = q
    megacanvas.quadsCount = index
    megacanvas.quadsAlive = megacanvas.quadsAlive + 1

    q:init(width, height)
    return q
end

function megacanvas.pack(q)
    local padding = megacanvas.padding
    local widthPadded = q.width + padding * 2
    local heightPadded = q.height + padding * 2

    local pages = megacanvas.pages
    local p, canvas, layer, x, y
    for i = 1, megacanvas.pagesCount do
        p, canvas, layer, x, y = pages[i]:fit(widthPadded, heightPadded)
        if p then
            break
        end
    end

    if not p then
        p, canvas, layer, x, y = megacanvas.newPage():fit(widthPadded, heightPadded)
    end

    love.graphics.setCanvas(canvas, layer or nil)
    love.graphics.setScissor(x, y, widthPadded, heightPadded)
    love.graphics.clear(0, 0, 0, 0)

    if megacanvas.debug.rects then
        love.graphics.setColor(0, 1, 0, 1)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x + 0.5, y + 0.5, widthPadded - 1, heightPadded - 1)
        love.graphics.setColor(1, 1, 1, 1)
    end

    love.graphics.draw(q.canvas, x + padding, y + padding)

    q.canvas:release()
    q.canvas = nil
    q.quad = love.graphics.newQuad(x + padding, y + padding, q.width, q.height, p.width, p.height)
    q.megacanvas = canvas
    q.megalayer = layer
end

function megacanvas.process()
    local quads = megacanvas.quads
    local quadsCount = megacanvas.quadsCount

    if quadsCount - megacanvas.quadsAlive > 128 then
        for i = quadsCount, 1, -1 do
            local q = quads[i]
            if not q then
                table.remove(quads, i)
            end
        end
        quadsCount = #quads
        megacanvas.quadsCount = quadsCount
        for i = 1, quadsCount do
            quads[i].index = i
        end
    end

    local sX, sY, sW, sH = love.graphics.getScissor()
    local canvasPrev = love.graphics.getCanvas()
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setBlendMode("alpha", "premultiplied")
    local shaderPrev = love.graphics.getShader()
    love.graphics.setShader(megacanvas.blitfix)

    local markedCount = megacanvas.markedCount
    if markedCount > 0 then
        local marked = megacanvas.marked
        for i = 1, markedCount do
            local q = marked[i]
            q.markedIndex = false
            megacanvas.pack(q)
        end
        megacanvas.marked = {}
        megacanvas.markedCount = 0
    end

    love.graphics.setShader(shaderPrev)
    love.graphics.setBlendMode("alpha", "alphamultiply")
    love.graphics.pop()
    love.graphics.setCanvas(canvasPrev)
    love.graphics.setScissor(sX, sY, sW, sH)
end

function megacanvas.dump(prefix)
    if megacanvas.debug.rects then
        local sX, sY, sW, sH = love.graphics.getScissor()
        local canvasPrev = love.graphics.getCanvas()
        love.graphics.push()
        love.graphics.origin()
        love.graphics.setColor(0, 0, 1, 1)
        love.graphics.setLineWidth(1)

        local pages = megacanvas.pages
        for pi = 1, megacanvas.pagesCount do
            local p = pages[pi]
            local canvas = p.canvas
            local layers = p.layers
            for li = 1, megacanvas.layers or 1 do
                local l = layers[li]
                love.graphics.setCanvas(canvas, l.layer or nil)
                local spaces = l.spaces
                for si = 1, #spaces do
                    local s = spaces[si]
                    love.graphics.setScissor(s.x, s.y, s.width, s.height)
                    love.graphics.clear(0, 0, 0, 0)
                    love.graphics.rectangle("line", s.x + 0.5, s.y + 0.5, s.width - 1, s.height - 1)
                end
            end
        end

        love.graphics.pop()
        love.graphics.setCanvas(canvasPrev)
        love.graphics.setScissor(sX, sY, sW, sH)
    end

    local pages = megacanvas.pages
    for pi = 1, megacanvas.pagesCount do
        local p = pages[pi]
        local canvas = p.canvas
        local layers = p.layers
        for li = 1, megacanvas.layers or 1 do
            if layers[li].count > 0 then
                local fh = io.open(prefix .. string.format("page_%d_layer_%d.png", pi, li), "wb")
                if fh then
                    local id = canvas:newImageData(megacanvas.layers and li or nil)
                    local fd = id:encode("png")
                    id:release()
                    fh:write(fd:getString())
                    fh:close()
                    fd:release()
                end
            end
        end
    end
end

return setmetatable(megacanvas, {
    __call = function(self, ...)
        return self.new(...)
    end
})
