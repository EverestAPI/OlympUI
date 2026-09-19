local spikerStatus, spiker = pcall(require, "spiker")
spiker = spikerStatus and spiker
local uiu = require("ui.utils")
local uin = require("ui.native")
local megacanvas = require("ui.megacanvas")

local ui = {
    _enabled = true,

    debug = {
        draw = false,
    },

    log = {
        reflow = false,
        canvas = false,
    },

    stats = {
        canvases = 0,
        draws = 0,
        layouts = 0
    },

    features = {
        metachildren = false,
        mouseGlobal = false,
        eventProxies = false,
        inspector = "f12",
        megacanvas = false,
    },

    eventProxyCache = {},

    runOnceMap = {},
    runLateList = {},

    repaintAll = false,
    globalReflowID = 0,

    updateID = 0,
    drawID = 0,

    fontDebug = love.graphics.newFont(8),

    hovering = false,
    dragging = false,
    draggingCounter = 0,
    focusing = false,

    mousePresses = 0,
    mouseX = false,
    mouseY = false,
    mouseEvent = false,
    mouseFocus = 0,

    -- UI-wide scaling (1 = unscaled). When set to a value other than 1, the
    -- whole UI is laid out and rendered in a virtual resolution of
    -- windowSize / scale, which is then blitted back scaled to the window.
    scale = 1,
    realWidth = 0,
    realHeight = 0,
    virtualWidth = 0,
    virtualHeight = 0
}


local getWidthOrig = love.graphics.getWidth
local getHeightOrig = love.graphics.getHeight
local getMousePosOrig = love.mouse.getPosition

local scaleApplied = false

function ui.applyScale()
    local scale = ui.scale
    if scale <= 0 then
        scale = 1
    end

    -- Keep olympui's text metric compensation in sync with the raster scale
    -- (fonts rasterize at the on-screen size when scaling up, and at the base
    -- size when scaling down, so the compensation factor is max(1, scale)).
    uiu.scale = math.max(1, scale)

    local canvas = love.graphics.getCanvas()
    local vw, vh
    if canvas then
        -- A host is already rendering the UI into a scaled canvas (e.g. its own
        -- virtual-resolution framebuffer): the canvas's size is the virtual size
        -- the elements should lay out against.
        vw, vh = canvas:getDimensions()
    else
        local realWidth, realHeight = love.graphics.getDimensions()
        ui.realWidth = realWidth
        ui.realHeight = realHeight
        vw = math.max(1, math.floor(realWidth / scale))
        vh = math.max(1, math.floor(realHeight / scale))
    end
    ui.virtualWidth = vw
    ui.virtualHeight = vh

    if scale == 1 or scaleApplied then
        return
    end
    scaleApplied = true

    love.graphics.getWidth = function() return vw end
    love.graphics.getHeight = function() return vh end
    love.mouse.getPosition = function()
        local x, y = getMousePosOrig()
        return x / scale, y / scale
    end
end

function ui.unapplyScale()
    if not scaleApplied then
        return
    end
    scaleApplied = false
    love.graphics.getWidth = getWidthOrig
    love.graphics.getHeight = getHeightOrig
    love.mouse.getPosition = getMousePosOrig
end


local updateID = 0
local prevWidth
local prevHeight
function ui.update()
    local root = ui.root
    if not root then
        return
    end

    ui.applyScale()

    ui.updateID = ui.updateID + 1

    ui.stats.draws = 0
    ui.stats.layouts = 0

    ui.runOnceMap = {}

    local spiker = spiker
    local spike = spiker and spiker("ui.update", 0.01)

    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()

    root.focused = love.window.hasFocus()

    local resized = prevWidth ~= width or prevHeight ~= height
    local resizedFirst = false
    if not root.all then
        root:collect(true, false)
        resized = true
        resizedFirst = true
    end

    if resized then
        prevWidth = width
        prevHeight = height

        root.width = width
        root.innerWidth = width
        root.height = height
        root.innerHeight = height
        root:reflow()

        if resizedFirst then
            root:layoutLazy()
            root:layoutLateLazy()
        end

        ui.interactiveIterate(ui.focusing, "onUnfocus")
        ui.focusing = false
    end
    spike = spike and spike("root resize")

    local dragging = ui.dragging
    if dragging and not dragging.isRooted then
        ui.interactiveIterate(dragging, "onRelease")
        ui.dragging = false
    end
    local focusing = ui.focusing
    if focusing and not focusing.isRooted then
        ui.interactiveIterate(focusing, "onUnfocus")
        ui.focusing = false
    end
    if ui.mousePresses > 0 or love.window.hasMouseFocus() then
        ui.mouseFocus = 2
    elseif ui.mouseFocus > 0 then
        ui.mouseFocus = ui.mouseFocus - 1
        if ui.mouseFocus == 0 then
            ui.hovering = false
        end
    end
    if not ui.mouseX or (not ui.mouseEvent and ui.mouseFocus > 0) then
        local mouseX, mouseY = love.mouse.getPosition()
        local mouseState = false
        if uin and ui.features.mouseGlobal then
            mouseX, mouseY, mouseState = uin.getGlobalMouseState()
            local windowX, windowY = uin.getWindowPosition()
            mouseX = mouseX - windowX
            mouseY = mouseY - windowY
            mouseState = mouseState
        else
            mouseState = false
        end

        ui.__mousemoved(mouseX, mouseY)
    end
    spike = spike and spike("mouse")

    local dt = love.timer.getDelta()
    ui.dt = dt

    local iLast = 0
    ::reupdate::
    local all = root.all
    for i = iLast + 1, #all do
        local c = all[i]

        if c.__updateID ~= updateID then
            local revived = c.__updateID ~= updateID - 1
            c.__updateID = updateID
            local cb
            local forceUpdate = false

            if not c.__awakened then
                c.__awakened = true
                cb = c.awake
                if cb then
                    cb(c)
                else
                    forceUpdate = true
                end
                cb = nil
            end

            if revived then
                cb = c.revive
                if cb then
                    cb(c)
                end
                cb = nil
            end

            local cdt = dt

            if forceUpdate or c.onscreen then
                cb = c.update
                if not c.updateHidden then
                    cdt = cdt + c.__dtHidden
                    c.__dtHidden = 0
                end
            else
                cb = c.updateHidden
                if cb == true then
                    cb = c.update
                end
                if not cb then
                    c.__dtHidden = c.__dtHidden + dt
                end
            end
            if cb then
                cb(c, cdt)
            end
        end

        iLast = i
        if root:collect() then
            goto reupdate
        end
    end
    spike = spike and spike("update")

    local runLateList = ui.runLateList
    ui.runLateList = {}
    for i = 1, #runLateList do
        runLateList[i]()
    end

    ::reflow::
    repeat
        root:layoutLazy()
    until not root.reflowing

    repeat
        root:layoutLateLazy()
        if root.reflowing then
            goto reflow
        end
    until not root.reflowingLate
    spike = spike and spike("layout")

    root:collect()
    spike = spike and spike("collect")

    updateID = updateID + 1
    spike = spike and spiker(spike)

    ui.unapplyScale()
end


function ui.draw()
    local root = ui.root
    if not root then
        return
    end

    ui.applyScale()

    ui.drawID = ui.drawID + 1
    uiu.resetColor()
    root:redraw()
    love.graphics.setColor(1, 1, 1, 1)
    uiu.resetColor()

    megacanvas.process()

    ui.unapplyScale()
end


-- ui.draw() renders with virtual (scaled) coordinates. When the host isn't
-- already providing a scaled render target, draw the whole UI to the backbuffer
-- wrapped in a graphical scale. Fonts rasterize at the on-screen size when
-- scaling up, and at the base size when scaling down (supersampled by the
-- graphical scale); images rasterize at base size. Either way there is no
-- canvas roundtrip, so the UI stays sharp at device resolution.
-- olympui's scissor calls are NOT affected by graphical transforms, so its
-- virtual-coordinate scissors are translated to real screen pixels here while
-- the UI is drawn.
local function uiDrawScaled(scale)
    local setScissorOrig = love.graphics.setScissor
    local getScissorOrig = love.graphics.getScissor

    local shadowScissor = { 0, 0, 0, 0 }
    local shadowActive = false

    love.graphics.setScissor = function(x, y, w, h)
        if x == nil then
            shadowActive = false
            return setScissorOrig()
        end

        shadowActive = true
        shadowScissor[1], shadowScissor[2], shadowScissor[3], shadowScissor[4] = x, y, w, h

        -- Rendering into a (virtual-resolution) element canvas: the scissor is
        -- already in the canvas's pixel space. On the screen it has to be
        -- expressed in real pixels.
        if love.graphics.getCanvas() then
            setScissorOrig(x, y, w, h)
        else
            setScissorOrig(x * scale, y * scale, w * scale, h * scale)
        end
    end

    love.graphics.getScissor = function()
        if not shadowActive then
            return
        end

        return shadowScissor[1], shadowScissor[2], shadowScissor[3], shadowScissor[4]
    end

    love.graphics.push()
    love.graphics.scale(scale, scale)
    ui.draw()
    love.graphics.pop()

    love.graphics.setScissor = setScissorOrig
    love.graphics.getScissor = getScissorOrig
end

function ui.drawScaled()
    ui.applyScale()

    local scale = ui.scale or 1

    if scale == 1 then
        -- Re-enable element canvas caching once back at the unscaled UI.
        ui.repaintAll = false
        ui.draw()
        ui.unapplyScale()
        return
    end

    -- Render everything fresh every frame: cached element canvases are stored
    -- at virtual resolution and would be upscaled (soft) under the graphical
    -- scale, so bypass them to keep all UI elements sharp at device resolution.
    ui.repaintAll = true
    uiDrawScaled(scale)

    ui.unapplyScale()
end


function ui.runLate(cb)
    ui.runLateList[#ui.runLateList + 1] = cb
end

function ui.runOnce(cb, ...)
    if ui.runOnceMap[cb] then
        return
    end
    ui.runOnceMap[cb] = true
    cb(...)
end


function ui.interactiveIterate(el, funcid, ...)
    local handled = false

    if not el then
        return nil, false
    end

    local parent = el.parent
    if parent then
        parent, handled = ui.interactiveIterate(parent, funcid, ...)
    end

    if funcid then
        local func = el[funcid]
        if func then
            handled = func(el, ...)
        end
    end

    if el.interactive == 0 then
        return parent, false
    end

    return el, handled ~= false
end


function ui.__mousemoved(x, y, dx, dy)
    local ui = ui
    local root = ui.root
    if not root then
        return
    end

    if not dx or not dy then
        if not ui.mouseX or not ui.mouseY then
            dx = 0
            dy = 0
        else
            dx = x - ui.mouseX
            dy = y - ui.mouseY
        end
    end
    ui.mouseX = x
    ui.mouseY = y

    if dx == 0 and dy == 0 then
        return ui.dragging or ui.hovering
    end

    local hoveringPrev = ui.hovering
    local hoveringNext = root:getChildAt(x, y)
    ui.hovering = hoveringNext or false

    if hoveringPrev ~= hoveringNext then
        if hoveringPrev then
            local cb = hoveringPrev.onLeave
            if cb then
                cb(hoveringPrev)
            end
        end
        if hoveringNext then
            local cb = hoveringNext.onEnter
            if cb then
                cb(hoveringNext)
            end
        end
    end

    local dragging = ui.dragging
    if (dx ~= 0 or dy ~= 0) and dragging then
        local cb = dragging.onDrag
        if cb then
            cb(dragging, x, y, dx, dy)
        end
    end

    return ui.dragging or hoveringNext
end

function ui.mousemoved(x, y, dx, dy)
    if ui.scale and ui.scale ~= 1 and x then
        x, y = x / ui.scale, y / ui.scale
        if dx then
            dx = dx / ui.scale
        end
        if dy then
            dy = dy / ui.scale
        end
    end
    ui.mouseEvent = true
    return ui.__mousemoved(x, y, dx, dy)
end

function ui.mousepressed(x, y, button, istouch, presses)
    local ui = ui

    if ui.scale and ui.scale ~= 1 then
        x, y = x / ui.scale, y / ui.scale
    end

    if ui.mousePresses == 0 and uin then
        uin.captureMouse(true)
    end
    ui.mousePresses = ui.mousePresses + presses

    local root = ui.root
    if not root then
        return
    end

    ui.draggingCounter = ui.draggingCounter + 1

    local hovering = root:getChildAt(x, y)
    if not ui.dragging or ui.dragging == hovering then
        ui.interactiveIterate(ui.focusing, "onUnfocus", x, y, button, true)
        local el = ui.interactiveIterate(hovering, "onPress", x, y, button, true, presses)
        ui.dragging = el or false
        ui.focusing = el or false
    else
        ui.interactiveIterate(hovering, "onPress", x, y, button, false, presses)
    end

    return hovering or ui.dragging
end

function ui.mousereleased(x, y, button, istouch, presses)
    local ui = ui

    if ui.scale and ui.scale ~= 1 then
        x, y = x / ui.scale, y / ui.scale
    end

    ui.mousePresses = ui.mousePresses - presses
    if ui.mousePresses == 0 and uin then
        uin.captureMouse(false)
    end

    local root = ui.root
    if not root then
        return
    end

    ui.draggingCounter = ui.draggingCounter - 1

    local dragging = ui.dragging
    local hovering = root:getChildAt(x, y)
    if dragging then
        if ui.draggingCounter == 0 then
            ui.dragging = false
            ui.interactiveIterate(dragging, "onRelease", x, y, button, false)
            if dragging == ui.interactiveIterate(root:getChildAt(x, y)) then
                ui.interactiveIterate(dragging, "onClick", x, y, button)
            end
        else
            ui.interactiveIterate(dragging, "onRelease", x, y, button, true)
        end
    elseif hovering then
        ui.interactiveIterate(dragging, "onRelease", x, y, button, false)
    end

    return hovering or dragging
end

-- Lönn provides these events and expects them to not be propagated further.

function ui.mousedragmoved()
    return ui.hovering or ui.dragging
end

function ui.mousedragged()
    return ui.hovering or ui.dragging
end

function ui.mouseclicked()
    return ui.hovering or ui.dragging
end

function ui.wheelmoved(dx, dy)
    local ui = ui
    local root = ui.root
    if not root then
        return
    end

    local hovering = ui.hovering
    if hovering then
        ui.interactiveIterate(hovering, "onScroll", ui.mouseX, ui.mouseY, dx, dy)
    end

    return hovering or ui.dragging
end

function ui.keypressed(key, scancode, isrepeat)
    local el, handled = ui.interactiveIterate(ui.focusing, "onKeyPress", key, scancode, isrepeat)

    if ui.features.inspector and key == ui.features.inspector then
        ui.globalReflowID = ui.globalReflowID + 1
        if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
            ui.debug.draw = (ui.debug.draw ~= -1) and -1 or true

        elseif love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
            ui.debug.draw = (ui.debug.draw ~= -2) and -2 or -3

        else
            ui.debug.draw = not ui.debug.draw
        end

        return true
    end

    return handled
end

function ui.keyreleased(key, scancode)
    local el, handled = ui.interactiveIterate(ui.focusing, "onKeyRelease", key, scancode)
    return handled
end

function ui.textinput(text)
    local el, handled = ui.interactiveIterate(ui.focusing, "onText", text)
    return handled
end


local hookedLoveUpdateDraw = false
local hookedLoveInput = false
function ui.hookLove(hookUpdateDraw, hookInput)
    if hookUpdateDraw ~= false and not hookedLoveUpdateDraw then
        hookedLoveUpdateDraw = true

        uiu.hook(love, {
            update = function(orig, ...)
                local rv = orig(...)
                ui.update(...)
                return rv
            end,

            draw = function(orig, ...)
                local rv = orig(...)

                if ui.scale and ui.scale ~= 1 and not love.graphics.getCanvas() then
                    ui.drawScaled()
                else
                    ui.draw(...)
                end

                return rv
            end
        })
    end

    if hookInput ~= false and not hookedLoveInput then
        hookedLoveInput = true

        uiu.hook(love, {
            mousepressed = function(orig, ...)
                ui.mousepressed(...)
                return orig(...)
            end,

            mousereleased = function(orig, ...)
                ui.mousereleased(...)
                return orig(...)
            end,

            wheelmoved = function(orig, ...)
                ui.wheelmoved(...)
                return orig(...)
            end,

            keypressed = function(orig, ...)
                ui.keypressed(...)
                return orig(...)
            end,

            keyreleased = function(orig, ...)
                ui.keyreleased(...)
                return orig(...)
            end,

            textinput = function(orig, ...)
                ui.textinput(...)
                return orig(...)
            end
        })
    end
end


local mtUI = {}

function mtUI:__index(key)
    local rv = rawget(self, key)
    if rv ~= nil then
        return rv
    end

    if self.features.eventProxies then
        rv = self.eventProxyCache[key]
        if rv ~= nil then
            return rv
        end

        rv = function(...)
            return self.root:foreach(key, ...)
        end
        self.eventProxyCache[key] = rv
        return rv
    end

    return nil
end


return setmetatable(ui, mtUI)
