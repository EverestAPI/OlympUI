local utf8 = require("utf8")

local uiu = {}


local patchyStatus, patchy = pcall(require, "patchy")
if not patchyStatus then
    patchy = require("ui.patchy")
end

uiu.patchy = patchy


function uiu.nop()
end


function uiu.default(value, default)
    if value ~= nil then
        return value
    end
    return default
end


function uiu.fract(num, default)
    if not num then
        return num, default
    end

    local fract

    if num < 0 then
        num, fract = uiu.fract(-num, default)
        return -num, fract
    end

    fract = num % 1
    if fract <= 0.0001 or fract >= 0.9999 then
        fract = default or 0
    elseif fract <= 0.005 then
        fract = 0
    elseif fract >= 0.995 then
        fract = 1
    end

    return num - (num % 1), fract
end


uiu.dataRoots = {}

function uiu.path(path)
    local root = ""

    local split = path:find(":")
    if split then
        if split == 1 then
            path = path:sub(2)
        else
            root = path:sub(1, split - 1)
            path = path:sub(split + 1)
        end
    end

    root = root or ""
    local mappedRoot = uiu.dataRoots[root]
    if mappedRoot then
        path = mappedRoot .. "/" .. path

    elseif #root > 0 then
        path = root .. "/data/" .. path

    else
        path = "data/" .. path
    end

    return path
end


uiu.imageCache = {}
function uiu.image(path)
    path = uiu.path(path) .. ".png"

    local cache = uiu.imageCache
    local img = cache[path]
    if img then
        return img
    end

    img = love.graphics.newImage(path, { mipmaps = true } )
    img:setFilter("linear", "linear")
    img:setMipmapFilter("linear", 1)
    cache[path] = img
    return img
end


uiu.patchCache = {}
function uiu.patch(path, ids)
    local patch, force

    if ids then
        patch, force = uiu.patch(string.format(path, "_" .. ids[1]))
        if patch or force then
            return patch, force
        end
        for i = 1, #ids do
            patch, force = uiu.patch(string.format(path, ids[i]))
            if patch or force then
                return patch, force
            end
        end
        return uiu.patch(string.format(path, "default"))
    end

    force = false
    ::repath::
    path = uiu.path(path)

    local txt = love.filesystem.read(path .. ".9.txt")
    if txt then
        force = true
        path = txt:match("^()%s*$") and "" or txt:match("^%s*(.*%S)")
        if #path == 0 then
            return false, true
        end
        goto repath
    end

    path = path .. ".9.png"

    local cache = uiu.patchCache
    patch = cache[path]
    if patch ~= nil then
        return patch, force
    end

    local patchStatus
    patchStatus, patch = pcall(patchy.load, path)
    if not patchStatus then
        patch = false
    end
    cache[path] = patch
    return patch, force
end


function uiu.isCallback(cb)
    if type(cb) == "function" then
        return true
    end

    local mt = getmetatable(cb)
    return mt and mt.__call and true
end


function uiu.round(x)
    return x + 0.5 - (x + 0.5) % 1
end
math.round = math.round or uiu.round


function uiu.sign(x)
    return x > 0 and 1 or x < 0 and -1 or 0
end
math.sign = math.sign or uiu.sign


function uiu.listRange(from, to, step)
    local output = {}
    local count = 1
    for i = from, to, (step or 1) do
        output[count] = i
        count = count + 1
    end
    return output
end


function uiu.map(input, fn)
    local output = {}
    for k, v in pairs(input) do
        local newV, newK = fn(v, k, input)
        if newK ~= nil then
            output[newK] = newV
        else
            output[k] = newV
        end
    end
    return output
end


function uiu.fadeSwap(faded, color, colorPrev, prev, next)
    if prev == next then
        return faded, color, colorPrev, colorPrev, next
    end
    local copy = {color[1], color[2], color[3], color[4], color[5]}
    return true, color, copy, copy, next
end


function uiu.fade(faded, f, color, prev, next)
    if next[5] then
        if f < 1 and prev[5] and color[5] then
            color[1] = prev[1] + (next[1] - prev[1]) * f
            color[2] = prev[2] + (next[2] - prev[2]) * f
            color[3] = prev[3] + (next[3] - prev[3]) * f
            color[4] = prev[4] + (next[4] - prev[4]) * f
            color[5] = prev[5] + (next[5] - prev[5]) * f
            return true

        else
            if color[1] == next[1] and color[2] == next[2] and color[3] == next[3] and color[4] == next[4] and color[5] == next[5] then
                return faded
            end

            color[1] = next[1]
            color[2] = next[2]
            color[3] = next[3]
            color[4] = next[4]
            color[5] = next[5]
            return true
        end

    else
        if f < 1 and prev[4] and color[4] then
            color[1] = prev[1] + (next[1] - prev[1]) * f
            color[2] = prev[2] + (next[2] - prev[2]) * f
            color[3] = prev[3] + (next[3] - prev[3]) * f
            color[4] = prev[4] + (next[4] - prev[4]) * f
            return true

        else
            if color[1] == next[1] and color[2] == next[2] and color[3] == next[3] and color[4] == next[4] then
                return faded
            end

            color[1] = next[1]
            color[2] = next[2]
            color[3] = next[3]
            color[4] = next[4]
            return true
        end
    end
end


-- Adapted from https://love2d.org/forums/viewtopic.php?p=196103&sid=ee7a367880e9968d161c042542058a93#p196103
function uiu.getWrap(font, input, width)
    local wrap = {}

    _, wrap = font:getWrap(input, width)

    if type(input) == "string" then
        return table.concat(wrap, "\n")
    end

    -- Copy the input table to not modify any passed references.
    local ct = {}
    for i = 1, #input do
        ct[i] = input[i]
    end

    local lines = {}

    local li = 1
    local ci = 1
    local cl = #ct
    local wi = 1
    local wl = #wrap

    lines[1] = {}
    while ci <= cl and wi <= wl do
        local from, to = string.find(wrap[wi], ct[ci + 1], nil, true)
        if from and to then -- wrap contains full ct line
            -- copy full ct line with color
            lines[wi][li] = ct[ci]
            lines[wi][li + 1] = ct[ci + 1]
            wrap[wi] = string.sub(wrap[wi], to + 1, -1)
            li = li + 2
            ci = ci + 2
        else -- wrap is not containing a full ct line
            -- copy wrap line in ct color and modify ct
            lines[wi][li] = ct[ci]
            lines[wi][li + 1] = wrap[wi]
            ct[ci + 1] = string.sub(ct[ci + 1], #wrap[wi] + 1, -1)
            li = 1
            wi = wi + 1
            lines[wi] = {}
        end
    end

    -- TODO: Replace the above code from the love2d forums to immediately return a text-compatible table.

    wi = 1
    wrap = {}
    local lc = #lines
    for li = 1, lc do
        local line = lines[li]
        for ci = 1, #line - 1 do
            wrap[wi] = line[ci]
            wi = wi + 1
        end
        if li < lc - 1 then
            wrap[wi] = line[#line] .. "\n"
        else
            wrap[wi] = line[#line]
        end
        wi = wi + 1
    end

    return wrap
end


function uiu.countformat(count, one, more)
    return string.format(count == 1 and one or more, count)
end


local prevR = -1
local prevG = -1
local prevB = -1
local prevA = -1

function uiu.resetColor()
    prevR = -1
end

function uiu.setColor(r, g, b, a)
    if r then
        if g then
            a = a or 1

        else
            g = r[2]
            if not g then
                return false
            end
            b = r[3]
            a = r[4] or 1
            r = r[1]
        end

    else
        return false
    end

    if a < 0.0001 then
        return false
    end

    if r ~= prevR or g ~= prevG or b ~= prevB or a ~= prevA then
        love.graphics.setColor(r, g, b, a)
        prevR = r
        prevG = g
        prevB = b
        prevA = a
    end

    return true
end


function uiu.drawCanvas(canvas, x, y, r, sx, sy, ox, oy, kx, ky)
    if canvas.draw then
        canvas:draw(x, y, r, sx, sy, ox, oy, kx, ky)
    else
        love.graphics.setBlendMode("alpha", "premultiplied")
        love.graphics.draw(canvas.canvas, x, y, r, sx, sy, ox, oy, kx, ky)
        love.graphics.setBlendMode("alpha", "alphamultiply")
    end
end


function uiu.magic(fn, ...)
    local magic = uiu.magic
    local mask = { ... }

    return function(...)
        local input = { ... }
        local args = {}

        local ii = 1

        for i = 1, #mask do
            local arg = mask[i]
            if arg == magic then
                arg = input[ii]
                ii = ii + 1
            end
            args[i] = arg
        end

        local offs = #args + 1
        for i = ii, #input do
            args[i - ii + offs] = input[i]
        end

        return fn(table.unpack(args))
    end
end


function uiu.hook(target, nameOrMap, cb)
    if type(target) == "string" or (target and not nameOrMap) then
        cb = nameOrMap
        nameOrMap = target
        return function(target)
            uiu.hook(target, nameOrMap, cb)
        end
    end

    if type(nameOrMap) ~= "string" then
        for name, cb in pairs(nameOrMap) do
            uiu.hook(target, name, cb)
        end
        return target
    end

    local name = nameOrMap
    local orig = target[name] or uiu.nop
    target[name] = function(...)
        return cb(orig, ...)
    end
    return target
end


function uiu.fillWidth(el, arg2, arg3)
    local except
    local fract
    local respectSiblings
    local late

    local function apply(el)
        except = uiu.default(except, 0)
        except, fract = uiu.fract(except, 1)
        respectSiblings = uiu.default(respectSiblings, false)
        late = uiu.default(late, true)

        local exceptSpacing = false -- FIXME: Expose exceptSpacing!

        return
        late and
        uiu.hook(el, {
            layoutLazy = function(orig, self)
                -- Required to allow the container to shrink again.
                orig(self)
                self.width = 0
            end,

            layoutLateLazy = function(orig, self)
                -- Always reflow this child whenever its parent gets reflowed.
                self:layoutLate()
                self:repaint()
            end,

            layoutLate = function(orig, self)
                local extra = except
                if exceptSpacing then
                    extra = extra + self.parent.style.spacing
                end
                local width = self.parent.innerWidth * fract - extra
                if respectSiblings then
                    local spacing = self.parent.style.spacing
                    local children = self.parent.children
                    for i = 1, #children do
                        local c = children[i]
                        if c ~= self then
                            width = width - c.width - spacing
                        end
                    end
                end
                width = math.floor(width)
                self.width = width
                self.innerWidth = width - (self.style:getIndex("padding", 1) or 0) - (self.style:getIndex("padding", 3) or 0)
                orig(self)
            end
        })

        or
        uiu.hook(el, {
            layoutLazy = function(orig, self)
                -- Always reflow this child whenever its parent gets reflowed.
                self:layout()
                self:repaint()
            end,

            layout = function(orig, self)
                local extra = except
                if exceptSpacing then
                    extra = extra + self.parent.style.spacing
                end
                local width = self.parent.innerWidth * fract - extra
                if respectSiblings then
                    local spacing = self.parent.style.spacing
                    local children = self.parent.children
                    for i = 1, #children do
                        local c = children[i]
                        if c ~= self then
                            width = width - c.width - spacing
                        end
                    end
                end
                width = math.floor(width)
                self.width = width
                self.innerWidth = width - (self.style:get("padding") or 0) * 2
                orig(self)
            end
        })
    end

    if el == nil then
        return apply

    elseif type(el) == "number" then
        except = el
        respectSiblings = arg2
        late = arg3
        return apply

    elseif type(el) == "boolean" then
        respectSiblings = el
        late = arg2
        return apply

    else
        return apply(el)
    end
end


function uiu.fillHeight(el, arg2, arg3)
    local except
    local fract
    local respectSiblings
    local late

    local function apply(el)
        except = uiu.default(except, 0)
        except, fract = uiu.fract(except, 1)
        respectSiblings = uiu.default(respectSiblings, false)
        late = uiu.default(late, true)

        local exceptSpacing = false -- FIXME: Expose exceptSpacing!

        return
        late and
        uiu.hook(el, {
            layoutLazy = function(orig, self)
                -- Required to allow the container to shrink again.
                orig(self)
                self.height = 0
            end,

            layoutLateLazy = function(orig, self)
                -- Always reflow this child whenever its parent gets reflowed.
                self:layoutLate()
                self:repaint()
            end,

            layoutLate = function(orig, self)
                local extra = except
                if exceptSpacing then
                    extra = extra + self.parent.style.spacing
                end
                local height = self.parent.innerHeight * fract - extra
                if respectSiblings then
                    local spacing = self.parent.style.spacing
                    local children = self.parent.children
                    for i = 1, #children do
                        local c = children[i]
                        if c ~= self then
                            height = height - c.height - spacing
                        end
                    end
                end
                height = math.floor(height)
                self.height = height
                self.innerHeight = height - (self.style:get("padding") or 0) * 2
                orig(self)
            end
        })

        or
        uiu.hook(el, {
            layoutLazy = function(orig, self)
                -- Always reflow this child whenever its parent gets reflowed.
                self:layout()
                self:repaint()
            end,

            layout = function(orig, self)
                local extra = except
                if exceptSpacing then
                    extra = extra + self.parent.style.spacing
                end
                local height = self.parent.innerHeight * fract - extra
                if respectSiblings then
                    local spacing = self.parent.style.spacing
                    local children = self.parent.children
                    for i = 1, #children do
                        local c = children[i]
                        if c ~= self then
                            height = height - c.height - spacing
                        end
                    end
                end
                height = math.floor(height)
                self.height = height
                self.innerHeight = height - (self.style:get("padding") or 0) * 2
                orig(self)
            end
        })
    end

    if el == nil then
        return apply

    elseif type(el) == "number" then
        except = el
        respectSiblings = arg2
        late = arg3
        return apply

    elseif type(el) == "boolean" then
        respectSiblings = el
        late = arg2
        return apply

    else
        return apply(el)
    end
end


function uiu.fill(el)
    local except
    local fract

    local function apply(el)
        except = uiu.default(except, 0)
        except, fract = uiu.fract(except, 1)

        return uiu.hook(el, {
            layoutLazy = function(orig, self)
                -- Required to allow the container to shrink again.
                orig(self)
                self.width = 0
                self.height = 0
            end,

            layoutLateLazy = function(orig, self)
                -- Always reflow this child whenever its parent gets reflowed.
                self:layoutLate()
                self:repaint()
            end,

            layoutLate = function(orig, self)
                local width = math.floor(self.parent.innerWidth * fract - except)
                local height = math.floor(self.parent.innerHeight * fract - except)
                self.width = width
                self.height = height
                local padding = self.style:get("padding") or 0
                self.innerWidth = width - padding * 2
                self.innerHeight = height - padding * 2
                orig(self)
            end
        })
    end

    if el == nil then
        return apply

    elseif type(el) == "number" then
        except = el
        return apply

    else
        return apply(el)
    end
end


function uiu.at(el, arg2, arg3)
    local x
    local xf
    local y
    local yf

    local function apply(el)
        x, xf = uiu.fract(x, 0)
        y, yf = uiu.fract(y, 0)

        return
        uiu.hook(el, {
            layoutLateLazy = function(orig, self)
                -- Always reflow this child whenever its parent gets reflowed.
                self:layoutLate()
                self:repaint()
            end,

            layoutLate = function(orig, self)
                local parent = self.parent
                if x then
                    self.realX = math.floor(x + parent.innerWidth * xf)
                end
                if y then
                    self.realY = math.floor(y + parent.innerHeight * yf)
                end
                orig(self)
            end
        })
    end

    if type(el) == "number" or type(el) == "boolean" then
        x = el
        y = arg2
        return apply

    else
        x = arg2
        y = arg3
        return apply(el)
    end
end


function uiu.rightbound(el, arg2)
    local offs
    local offsf

    local function apply(el)
        offs, offsf = uiu.fract(offs, 0)
        if not offs then
            offs = 0
        end

        return
        uiu.hook(el, {
            layoutLateLazy = function(orig, self)
                -- Always reflow this child whenever its parent gets reflowed.
                self:layoutLate()
                self:repaint()
            end,

            layoutLate = function(orig, self)
                local parent = self.parent
                self.realX = math.floor(parent.width - (parent.style:get("padding") or 0) - self.width - offs - parent.innerWidth * offsf)
                orig(self)
            end
        })
    end

    if type(el) == "number" then
        offs = el
        return apply

    else
        offs = arg2
        return apply(el)
    end
end


function uiu.bottombound(el, arg2)
    local offs
    local offsf

    local function apply(el)
        offs, offsf = uiu.fract(offs, 0)
        if not offs then
            offs = 0
        end

        return
        uiu.hook(el, {
            layoutLateLazy = function(orig, self)
                -- Always reflow this child whenever its parent gets reflowed.
                self:layoutLate()
                self:repaint()
            end,

            layoutLate = function(orig, self)
                local parent = self.parent
                self.realY = math.floor(parent.height - (parent.style:get("padding") or 0) - self.height - offs - parent.innerHeight * offsf)
                orig(self)
            end
        })
    end

    if type(el) == "number" then
        offs = el
        return apply

    else
        offs = arg2
        return apply(el)
    end
end

-- Word "jumping" typically allows underscores as part of words
function uiu.isWordCharacter(char, allowUnderscore)
    if allowUnderscore ~= false and char == "_" then
        return true
    end

    if char == " " then
        return false
    end

    -- Punctuation characters
    if string.match(char, "%p") then
        return false
    end

    return true
end

function uiu.findWordBorder(text, index, direction)
    local len = utf8.len(text)

    if len == 0 then
        return 0
    end

    local start = index
    local stop = direction > 0 and len or 1

    for i = start, stop, direction do
        local offset = utf8.offset(text, i)
        local char = utf8.char(utf8.codepoint(text, offset, offset))
        local wordChar = uiu.isWordCharacter(char)

        if not wordChar then
            return i - direction
        end
    end

    return stop
end

function uiu.getTextCursorOffset(font, text, index)
    -- Returns nil if out of bounds for the text, default to 0
    local utf8Offset = utf8.offset(text, index + 1) or 0
    return index == 0 and 0 or font:getWidth(text:sub(1, utf8Offset - 1))
end


function uiu.getTextIndexForCursor(font, text, x)
    local min = 0
    local max = utf8.len(text) + 1
    while max - min > 1 do
        local mid = min + math.ceil((max - min) / 2)
        local midx = font:getWidth(text:sub(1, utf8.offset(text, mid + 1) - 1)) - font:getWidth(text:sub(utf8.offset(text, mid), utf8.offset(text, mid + 1) - 1)) * 0.4
        if x <= midx then
            max = mid
        else
            min = mid
        end
    end
    return min
end


local mtStyleDeep = {
    __index = function(self, key)
        return self.__styleOrig[key]
    end,

    __newindex = function(self, key, value)
        self.__styleOrig[key] = value

        local children = self.el.children
        for i = 1, #children do
            children[i].style[key] = value
        end
    end
}

function uiu.styleDeep(el)
    el.__style = setmetatable({
        el = el,
        __styleOrig = el.__style,
        get = function(self, ...)
            return self.__styleOrig:get(...)
        end,
        getIndex = function(self, ...)
            return self.__styleOrig:getIndex(...)
        end,
    }, mtStyleDeep)

    el:hook({
        repaint = function(orig, self)
            local children = self.children
            for i = 1, #children do
                children[i]:repaint()
            end
        end
    })

    return el
end


table.pack = table.pack or function(...)
    return { ... }
end
table.unpack = table.unpack or _G.unpack


return uiu
