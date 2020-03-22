local uiu = require("ui.utils")
local uin = require("ui.native")

local ui = {
    _enabled = true,

    debugLog = false,
    debugDraw = false,
    repaintAll = false,

    fontDebug = love.graphics.newFont(8),

    hovering = false,
    dragging = false,
    draggingCounter = 0,
    focusing = false,

    mousePresses = 0,
    mouseX = false,
    mouseY = false,
    mouseGlobal = true
}


local updateID = 0
local prevWidth
local prevHeight
function ui.update()
    local root = ui.root
    if not root then
        return
    end

    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()

    root.focused = love.window.hasFocus()

    if prevWidth ~= width or prevHeight ~= height then
        prevWidth = width
        prevHeight = height

        root.width = width
        root.innerWidth = width
        root.height = height
        root.innerHeight = height
        root:reflow()

        if not root.all then
            root:collect(true, false)
            root:layoutLazy()
            root:layoutLateLazy()
        end
    end

    if ui.mouseGlobal then
        local mouseX, mouseY = love.mouse.getPosition()
        local mouseState = false
        if uin then
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

    local dt = love.timer.getDelta()
    ui.dt = dt

    ::reupdate::
    local all = root.all
    for i = 1, #all do
        local c = all[i]

        if c.__updateID ~= updateID then
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

            local cdt = dt

            if forceUpdate or c.onscreen then
                cb = c.update
                if not c.updateHidden then
                    cdt = cdt + c.__dtHidden
                    c.__dtHidden = 0
                end
            else
                cb = c.updateHidden
                if not cb then
                    c.__dtHidden = c.__dtHidden + dt
                end
            end
            if cb then
                cb(c, cdt)
            end
        end

        if root:collect() then
            goto reupdate
        end
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

    root:collect()

    updateID = updateID + 1
end


function ui.draw()
    uiu.resetColor()
    ui.root:redraw()
    love.graphics.setColor(1, 1, 1, 1)
    uiu.resetColor()
end


function ui.interactiveIterate(el, funcid, ...)
    if not el then
        return nil
    end

    local parent = el.parent
    if parent then
        parent = ui.interactiveIterate(parent, funcid, ...)
    end

    if funcid then
        local func = el[funcid]
        if func then
            func(el, ...)
        end
    end

    if el.interactive == 0 then
        return parent
    end
    return el
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
    ui.mouseGlobal = false
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
        local el = ui.interactiveIterate(hovering, "onPress", x, y, button, true)
        ui.dragging = el or false
        ui.focusing = el or false
    else
        ui.interactiveIterate(hovering, "onPress", x, y, button, false)
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
            dragging = false
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
    return ui.interactiveIterate(ui.focusing, "onKeyPress", key, scancode, isrepeat)
end

function ui.keyreleased(key, scancode)
    return ui.interactiveIterate(ui.focusing, "onKeyRelease", key, scancode)
end

function ui.textinput(text)
    return ui.interactiveIterate(ui.focusing, "onText", text)
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


return ui
