local Patch = lovjRequire("lib/patch")
local palettes = lovjRequire("lib/utils/palettes")
local screen = lovjRequire("lib/screen")
local kp = lovjRequire("lib/utils/keypress")
local Timer = lovjRequire("lib/timer")
local Envelope = lovjRequire("lib/signals/envelope")

local cfg_timers = lovjRequire("cfg/cfg_timers")

local patch = Patch:new()

function patch.patchControls()
	local p = patch.resources.parameters
	if kp.isDown("lctrl") then
		-- Inverter
		patch.invert = kp.isDown("x")
		patch.freeRunning = kp.isDown("f")
  	end
	
	-- Reset
	if kp.isDown("r") then
    	patch.init(patch.slot)
	end
end


local function init_params()
	local p = patch.resources.parameters
	p:define(1, "numRects",    10,   { min = 2,   max = 30,  step = 1, type = "int" })
	p:define(2, "heightJitter", 20,  { min = 1,   max = 60,  type = "float" })
	p:define(3, "driftSpeed",  20,   { min = 0,   max = 100, type = "float" })
	p:define(4, "waveSpeed",   50,   { min = 0,   max = 200, type = "float" })
	return p
end


function patch.init(slot, globals, shaderext)
	Patch.init(patch, slot, globals, shaderext)
	patch.invert = false
	patch:setShaders()
	patch:setCanvases()

	patch.n = 10
	patch.localTimer = 0

	patch.timers = {}
	patch.timers.bpm = Timer:new(clock.beatDuration())
	patch.env = Envelope:new(0, 0, 1, 0.5)
	patch.drawList = {}

	patch.resources.parameters = init_params()
	patch:assignDefaultDraw()
end


--- @private recalculateRects empty drawList and populate with new list of random rectangles
local function recalculateRects()
	local t = cfg_timers.globalTimer.T

	-- erase content of list (garbage collector takes care of this... right?)
	patch.drawList = {}

	-- add new rectangles
	local p = patch.resources.parameters
	local n = math.floor(p:get("numRects"))
	local hJitter = p:get("heightJitter")
	for i = -1, n-1 do
		local iw = screen.InternalRes.W
		local ih = screen.InternalRes.H
		local c = math.random(2)
		local x = math.random(iw / 2)
		local r = math.random(math.max(1, math.floor(hJitter))) + 1
		local y1 = ((ih / n) * i) - r / 2 - 5
		local y2 = y1 + (ih / n)  + r / 2 + 5

		table.insert(patch.drawList, { x = x, y1 = y1, y2 = y2, c = c})
	end
end


--- @private updateRects move rectangles according to some defined behaviour
local function updateRects()
	local t = cfg_timers.globalTimer.T
	local dt = cfg_timers.globalTimer:dt()  -- use this to make the code fps-independent!

	local p = patch.resources.parameters
	local driftSpd = p:get("driftSpeed")
	local waveSpd  = p:get("waveSpeed")
	for k,v in pairs(patch.drawList) do
		v.y1 = v.y1 + (math.sin(t + v.y1 / screen.InternalRes.H)) * driftSpd * dt
		v.y2 = v.y2 + (math.sin(t*1.5) + math.atan(v.x/v.y2))     * waveSpd * dt
		v.x  = v.x  + (math.cos(t*3 - v.y1/screen.InternalRes.H)) * driftSpd * 1.5 * dt
	end

end


--- @public patch.draw draw the patch
function patch.draw()
	patch:drawSetup()  -- call parent setup function

	local t = cfg_timers.globalTimer.T

	local transparency = patch.env:Calculate(t)     -- transparency set according to patch.env Envelope

	if patch.freeRunning then transparency = 1 end  -- in free running, transparency disabled
	local inversion = patch.invert and 1 or 0       -- convert "inversion" bool to int

	-- draw all rectangles
	for k,v in pairs(patch.drawList) do
		local color = palettes.getColor(palettes.BW, 2-inversion)
		if v.c == 1 then
			love.graphics.setColor(color[1], color[2], color[3], transparency)
			love.graphics.rectangle("fill", v.x, v.y1, screen.InternalRes.W - (2 * v.x), v.y2 - v.y1)
		else
			love.graphics.setColor(color[1], color[2], color[3], transparency)
			love.graphics.rectangle("fill", 0, v.y1, screen.InternalRes.W, v.y2 - v.y1)
			color = palettes.getColor(palettes.BW, 1 + inversion)		-- swap color
			love.graphics.setColor(color[1], color[2], color[3], transparency)
			love.graphics.rectangle("fill", v.x, v.y1, screen.InternalRes.W - (2 * v.x), v.y2 - v.y1)
		end
	end

	return patch:drawExec()  -- call parent rendering function
end


function patch.update()
	patch:mainUpdate()

	-- Update bpm timer
	patch.timers.bpm:set_reset_t(clock.beatDuration())
	patch.timers.bpm:update()

	-- Upon bpm timer trigger, update envelope trigger
	patch.env:UpdateTrigger(patch.timers.bpm:activated())

	-- Upon bpm timer trigger, also update rectangles
	if patch.timers.bpm:activated() then
		recalculateRects()
	else
		updateRects()
	end
end

function patch.commands(s)

end

return patch