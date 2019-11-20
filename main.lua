local uiu = require("ui.utils")
local uin = require("ui.native")

local ui = {}

ui._enabled = true

ui.debug = false

ui.hovering = false
ui.dragging = false
ui.draggingCounter = 0
ui.focusing = false
ui.mousePresses = 0
ui.mouseX = false
ui.mouseY = false
ui.mouseGlobal = true

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

    ui.delta = love.timer.getDelta()

    local all = root.all
    for i = 1, #all do
        local c = all[i]
        local cb = c.update
        if cb then
            cb(c)
        end
    end

    root:layoutLazy()
    root:layoutLateLazy()

    if root.recollecting then
        root:collect(false)
    end

end


function ui.draw()
    local root = ui.root

    root:drawLazy()

    love.graphics.setColor(1, 1, 1, 1)
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
        local el = ui.interactiveIterate(hovering, "onPress", x, y, button, true)
        ui.dragging = el or false
        ui.focusing = el or false
    else
        ui.interactiveIterate(hovering, "onPress", x, y, button, false)
    end

    print("pressed", hovering or ui.dragging)
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

    print("released", hovering or ui.dragging)
    return hovering or dragging
end

-- Lönn provides these events and expects them to not be propagated further.

function ui.mousedragmoved()
    return ui.hovering or ui.dragging
end

function ui.mousedraged()
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
            end
        })
    end
end


return ui
