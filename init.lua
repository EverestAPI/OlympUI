local ui = require("ui.main")
local uie = require("ui.elements")
ui.e = uie

function ui.init(root, hookLove)
    ui.root = uie.root(root)
    if hookLove ~= false then
        ui.hookLove()
    end
end

return ui
