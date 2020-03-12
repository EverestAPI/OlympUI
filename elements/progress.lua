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

    progress = false,

    time = 0,

    init = function(self)
        self.__polygon = {}
    end,

    update = function(self, dt)
        self.time = (self.time + dt * 0.5) % 1
        self:repaint()
    end,

    draw = function(self)
        if not uiu.setColor(self.style.color) then
            return
        end

        local width = self.width
        local height = self.height
        local radius = math.min(width, height) * 0.5

        local thickness = radius * 0.25
        love.graphics.setLineWidth(thickness)

        local cX = self.screenX + width * 0.5 + thickness * 0.5
        local cY = self.screenY + height * 0.5 + thickness * 0.5
        radius = radius - thickness

        local polygon = {}

        local edges = 64

        local progA = 0
        local progB = self.progress

        if progB then
            progB = progB * edges

        else
            local t = self.time
            local offs = edges * t * 2
            if t < 0.5 then
                progA = offs + 0
                progB = offs + edges * t * 2
            else
                progA = offs + edges * (t - 0.5) * 2
                progB = offs + edges
            end
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

                f = (1 - f / (edges) + 0.5) * math.pi * 2
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
