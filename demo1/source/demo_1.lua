-- demo_1.lua

local Patch = lovjRequire("lib/patch")
local Timer = lovjRequire("lib/timer")
local Envelope = lovjRequire("lib/signals/envelope")
local palettes = lovjRequire("lib/utils/palettes")
local kp = lovjRequire("lib/utils/keypress")
local cfg_timers = lovjRequire("cfg/cfg_timers")

-- import pico8 palette
local PALETTE = palettes.PICO8

local patch = Patch:new()

--- @private inScreen Check if pixel in screen boundary
local function inScreen(x, y)
	return (x > 0 and x < screen.InternalRes.W and y > 0 and y < screen.InternalRes.H)
end


--- @private init_params initialize parameters for this patch
local function init_params()
	local p = patch.resources.parameters

	p:define(1, "a",         0.5,  { min = -5,  max = 5,   type = "float" })
	p:define(2, "b",         1.0,  { min = -5,  max = 5,   type = "float" })
	p:define(3, "gridSize",  20,   { min = 5,   max = 40,  step = 1, type = "int" })
	p:define(4, "pixelSize", 3,    { min = 1,   max = 10,  step = 1, type = "int" })
	p:define(5, "wobble",    8,    { min = 0,   max = 30,  type = "float" })
	p:define(6, "timeScale", 1.0,  { min = 0.1, max = 5.0, type = "float" })

	return p
end

--- @private patchControls handle controls for current patch
function patch.patchControls()
	local p = patch.resources.parameters
	local gr = patch.resources.graphics
	local gl = patch.resources.globals
	
	-- INCREASE
	if kp.isDown("up") then
		-- Param "a"
		if kp.isDown("a") then p:set("a", p:get("a") + .1) end
		-- Param "b"
		if kp.isDown("b") then p:set("b", p:get("b") + .1) end
	end
	
	-- DECREASE
	if kp.isDown("down") then
		-- Param "a"
		if kp.isDown("a") then p:set("a", p:get("a") - .1) end
		-- Param "b"
		if kp.isDown("b") then p:set("b", p:get("b") - .1) end
	end
	
	-- Hanger
	if kp.isDown("x") then patch.hang = true else patch.hang = false end

	return p, gr, gl
end

--- @public init init routine
function patch.init(slot, globals, shaderext)
	Patch.init(patch, slot, globals, shaderext)

	patch.resources.parameters = init_params()

	patch:setCanvases()

	patch.timers = {}
	patch.timers.bpm = Timer:new(clock.beatDuration())

	patch.env = Envelope:new(0.005, 0, 1, 0.5)
end

--- @public patch.draw draw routine
function patch.draw()
	patch:drawSetup()

	local p = patch.resources.parameters
	local t = cfg_timers.globalTimer.T

	local gridSize  = math.floor(p:get("gridSize"))
	local pixelSize = math.floor(p:get("pixelSize"))
	local wobble    = p:get("wobble")
	local timeScale = p:get("timeScale")
	local tScaled   = t * timeScale

	for x = -gridSize, gridSize, .25 do
		for y = -gridSize, gridSize, .25 do
			local r = ((x * x) + (y * y)) + 10 * math.sin(tScaled / 2.5)
			local x1 = x * math.cos(tScaled) - y * math.sin(tScaled)
			local y1 = x * math.sin(tScaled) + y * math.cos(tScaled)
			local w, h = screen.InternalRes.W, screen.InternalRes.H
			local px = w / 2 + (r - p:get("b")) * x1
			local py = h / 2 + (r - p:get("a")) * y1
			px = px + wobble * math.cos(r)
			local col = -r * 2 + math.atan(x1, y1)
			col = palettes.getColor(PALETTE, (math.floor(col) % 16) + 1)
			if inScreen(px, py) then
				love.graphics.setColor(col[1], col[2], col[3], patch.env:Calculate(t))
				love.graphics.rectangle("fill", px, py, pixelSize, pixelSize)
			end
		end
	end


	return patch:drawExec()
end


function patch.update()
	patch:mainUpdate()
	patch.timers.bpm:set_reset_t(clock.beatDuration())
	patch.timers.bpm:update()

	patch.env:UpdateTrigger(patch.timers.bpm:activated())
end


function patch.commands(s)

end


return patch