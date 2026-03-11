local cursor = {}

function cursor.hand()
    local c = love.mouse.getSystemCursor("hand")
    love.mouse.setCursor(c)
end

function cursor.default()
    local c = love.mouse.getSystemCursor("arrow")
    love.mouse.setCursor(c)
end

return cursor