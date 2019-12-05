local ui = require("ui.main")
local uiu = require("ui.utils")
local uie = require("ui.elements")
ui.u = uiu
ui.e = uie

function ui.init(root, hookLove)
    ui.root = uie.root(root)
    if hookLove ~= false then
        ui.hookLove()
    end
end

function ui.quick()
    return ui, uiu, uie
end

return ui
