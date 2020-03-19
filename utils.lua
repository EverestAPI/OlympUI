local uiu = {}

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
    fract = num % 1
    return num - fract, (fract <= 0.0001 or fract >= 0.9999) and (default or 0) or fract
end


uiu.dataRoots = {}

uiu.imageCache = {}
function uiu.image(path)
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

    path = path .. ".png"

    local cache = uiu.imageCache
    local img = cache[path]
    if img then
        return img
    end

    img = love.graphics.newImage(path)
    cache[path] = img
    return img
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
math.sign = math.siggn or uiu.sign


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
            end,

            layoutLate = function(orig, self)
                local width = self.parent.innerWidth * fract - (except >= 0 and except or self.parent.style.spacing)
                if respectSiblings then
                    local children = self.parent.children
                    for i = 1, #children do
                        local c = children[i]
                        if c ~= self then
                            width = width - c.width
                        end
                    end
                end
                self.width = width
                self.innerWidth = width - self.style.padding * 2
                orig(self)
            end
        })

        or
        uiu.hook(el, {
            layoutLazy = function(orig, self)
                -- Always reflow this child whenever its parent gets reflowed.
                self:layout()
            end,

            layout = function(orig, self)
                local width = self.parent.innerWidth * fract - (except >= 0 and except or self.parent.style.spacing)
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
                self.width = width
                self.innerWidth = width - self.style.padding * 2
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
            end,

            layoutLate = function(orig, self)
                local height = self.parent.innerHeight * fract - (except >= 0 and except or self.parent.style.spacing)
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
                self.height = height
                self.innerHeight = height - self.style.padding * 2
                orig(self)
            end
        })

        or
        uiu.hook(el, {
            layoutLazy = function(orig, self)
                -- Always reflow this child whenever its parent gets reflowed.
                self:layout()
            end,

            layout = function(orig, self)
                local height = self.parent.innerHeight * fract - (except >= 0 and except or self.parent.style.spacing)
                if respectSiblings then
                    local children = self.parent.children
                    for i = 1, #children do
                        local c = children[i]
                        if c ~= self then
                            height = height - c.height
                        end
                    end
                end
                self.height = height
                self.innerHeight = height - self.style.padding * 2
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
    uiu.hook(el, {
        layoutLazy = function(orig, self)
            -- Required to allow the container to shrink again.
            orig(self)
            self.width = 0
            self.height = 0
        end,

        layoutLateLazy = function(orig, self)
            -- Always reflow this child whenever its parent gets reflowed.
            self:layoutLate()
        end,

        layoutLate = function(orig, self)
            local width = self.parent.innerWidth
            local height = self.parent.innerHeight
            self.width = width
            self.height = height
            self.innerWidth = width - self.style.padding * 2
            self.innerHeight = height - self.style.padding * 2
            orig(self)
        end
    })
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
            end,

            layoutLate = function(orig, self)
                local parent = self.parent
                if x then
                    self.realX = x + parent.innerWidth * xf
                end
                if y then
                    self.realY = y + parent.innerHeight * yf
                end
                orig(self)
            end
        })
    end

    if type(el) == "number" then
        x = el
        y = arg2
        return apply

    else
        return apply(el, arg2, arg3)
    end
end


function uiu.rightbound(el)
    uiu.hook(el, {
        layoutLateLazy = function(orig, self)
            -- Always reflow this child whenever its parent gets reflowed.
            self:layoutLate()
        end,

        layoutLate = function(orig, self)
            local parent = self.parent
            self.realX = parent.width - parent.style.padding - self.width
            orig(self)
        end
    })
end


function uiu.bottombound(el)
    uiu.hook(el, {
        layoutLateLazy = function(orig, self)
            -- Always reflow this child whenever its parent gets reflowed.
            self:layoutLate()
        end,

        layoutLate = function(orig, self)
            local parent = self.parent
            self.realY = parent.height - parent.style.padding - self.height
            orig(self)
        end
    })
end


table.pack = table.pack or function(...)
    return { ... }
end
table.unpack = table.unpack or _G.unpack


return uiu
