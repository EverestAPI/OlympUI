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
    mouseFocus = 0
}


local updateID = 0
local prevWidth
local prevHeight
function ui.update()
    local root = ui.root
    if not root then
        return
    end

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
end


function ui.draw()
    local root = ui.root
    if not root then
        return
    end

    ui.drawID = ui.drawID + 1
    uiu.resetColor()
    root:redraw()
    love.graphics.setColor(1, 1, 1, 1)
    uiu.resetColor()

    megacanvas.process()
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

function ui.mousemoved(...)
    ui.mouseEvent = true
    return ui.__mousemoved(...)
end

function ui.mousepressed(x, y, button, istouch, presses)
    local ui = ui

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
                ui.draw(...)
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
