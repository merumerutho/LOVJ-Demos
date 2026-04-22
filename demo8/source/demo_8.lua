local Patch = lovjRequire("lib/patch")
local palettes = lovjRequire("lib/utils/palettes")
local kp = lovjRequire("lib/utils/keypress")
local Timer = lovjRequire("lib/timer")
local cfg_timers = lovjRequire("cfg/cfg_timers")


-- import pico8 palette
local PALETTE = palettes.TIC80

local patch = Patch:new()

--- @private init_params initialize patch parameters
local function init_params()
	local g = patch.resources.graphics
	local p = patch.resources.parameters

	p:define(1, "speed",      100,    { min = 10,  max = 500,  type = "float" })
	p:define(2, "horizon",    0.225,  { min = 0.05,max = 0.45, type = "float" })
	p:define(3, "sway",       50,     { min = 0,   max = 150,  type = "float" })

end

--- @public patchControls evaluate user keyboard controls
function patch:patchControls()
	local p = patch.resources.parameters

    -- insert here your patch controls
end


--- @public init init routine
function patch:init(slot, globals, shaderext)
	Patch.init(self, slot, globals, shaderext)
	self:setCanvases()

	patch.resources.parameters,
	patch.resources.graphics = init_params()
end

--- @private draw_bg draw background graphics
local function draw_stuff()
	local t = cfg_timers.globalTimer.T

	local g = patch.resources.graphics
	local p = patch.resources.parameters

	local w = screen.InternalRes.W
	local h = screen.InternalRes.H

	local gap = p:get("horizon") * screen.InternalRes.H + 20 + 16*math.sin(t/8)

	love.graphics.setColor(0,0,0,1)

	for x = 16, 16*16, 16 do
		local ly = gap - 8*32*16 / (x - t * p:get("speed") % 16)
		love.graphics.line(0, ly, w, ly)
		love.graphics.line(0, h - ly, w, h - ly)
	end

	-- horizon must be always present
	local ly = gap - 8*32*16 / (16*16)
	love.graphics.line(0, ly, w, ly)
	love.graphics.line(0, h - ly, w, h - ly)

	local n = screen.InternalRes.W / 5
	local spacing = screen.InternalRes.W / 320 + 1

	for x = -n, n, spacing do
		love.graphics.line(w/2 - 4*x + p:get("sway")*math.sin(t/2), gap - 16,
				w/2 - 24*x + p:get("sway")*math.sin(t/2), -16)
		love.graphics.line(w/2 - 4*x + p:get("sway")*math.sin(t/2), h - gap + 16,
				w/2 - 24*x + p:get("sway")*math.sin(t/2), h + 16)
	end

	love.graphics.setColor(1,1,1,1)
end

--- @public patch.draw draw routine
function patch:draw()
	self:drawSetup()
	-- clear main canvas
	patch.canvases.main:renderTo(function()
									love.graphics.clear(1,1,1,1)
								end )
	-- draw picture
	draw_stuff()

	return self:drawExec()
end


function patch:update()
	self:mainUpdate()
end


function patch:commands(s)

end

return patch