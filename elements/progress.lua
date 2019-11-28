local ui = require("ui.main")
local uie = require("ui.elements.main")
local uiu = require("ui.utils")
require("ui.elements.basic")

uie.add("spinner", {
    width = 32,
    height = 32,
    cacheable = false,

    style = {
        color = { 1, 1, 1, 1 }
    },

    time = 0,

    init = function(self)
        self.__polygon = {}
    end,

    update = function(self)
        self.time = (self.time + ui.delta * 0.5) % 1
        self:repaint()
    end,

    draw = function(self)
        love.graphics.setColor(self.style.color)

        local width = self.width
        local height = self.height
        local radius = math.min(width, height) * 0.5

        local thickness = radius * 0.25
        love.graphics.setLineWidth(thickness)

        local cX = self.screenX + width * 0.5 + thickness * 0.5
        local cY = self.screenY + height * 0.5 + thickness * 0.5
        radius = radius - thickness

        local polygon = {}

        local t = 1 - self.time

        local edges = 64

        local progA, progB

        local offs = edges * t * 2
        if t < 0.5 then
            progA = 0 + offs
            progB = edges * t * 2 + offs
        else
            progA = edges * (t - 0.5) * 2 + offs
            progB = edges + offs
        end

        local progAE = math.floor(progA)
        local progBE = math.ceil(progB - 1)

        if progBE - progAE >= 1 then
            local i = 1
            for edge = progAE, progBE do
                local f = edge

                if edge == progAE then
                    f = progA
                elseif edge == progBE then
                    f = progB
                end

                f = (f / (edges)) * math.pi * 2
                local x = cX + math.sin(f) * radius
                local y = cY + math.cos(f) * radius

                polygon[i + 0] = x
                polygon[i + 1] = y
                i = i + 2
            end

            love.graphics.line(polygon)
        end
    end
})


return uie
