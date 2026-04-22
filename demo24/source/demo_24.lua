local Patch = lovjRequire("lib/patch")
local palettes = lovjRequire("lib/utils/palettes")
local kp = lovjRequire("lib/utils/keypress")
local Envelope = lovjRequire("lib/signals/envelope")
local Lfo = lovjRequire("lib/signals/lfo")
local Timer = lovjRequire("lib/timer")
local cfg_timers = lovjRequire("cfg/cfg_timers")
local cfg_shaders  = lovjRequire("cfg/cfg_shaders")

-- declare palette
local PALETTE

local patch = Patch:new()

local sea_reflection = love.graphics.newShader(table.getValueByName("19_sea_reflection", cfg_shaders.PostProcessShaders))

local t

--- @private init_params initialize patch parameters
local function init_params()
	local g = patch.resources.graphics
	local p = patch.resources.parameters

	p:define(1, "moonSize", 1.0, { min = 0, max = 3, type = "float" })

	patch.resources.parameters = p
end

--- @public patchControls evaluate user keyboard controls
function patch:patchControls()
	local p = patch.resources.parameters
	if kp.isDown("left") then p:set("moonSize", math.max(p:get("moonSize") - .01, 0)) end
	if kp.isDown("right") then p:set("moonSize", math.min(p:get("moonSize") + .01, 2.)) end
end


--- @public init init routine
function patch:init(slot, globals, shaderext)
	Patch.init(self, slot, globals, shaderext)
	PALETTE = palettes.PICO8
	self:setCanvases()

	init_params()

	t = 0

	sea_reflection:send("_splitY", 0.5)
	sea_reflection:send("_waveAmp", 0.01)
	sea_reflection:send("_waveFreq", 0.1)
	sea_reflection:send("_waveSpeed", 0.2)

	patch.lfo = Lfo:new(clock.syncRate("1/2bar"), 0)
	patch.srcCanvas = love.graphics.newCanvas(screen.InternalRes.W, screen.InternalRes.H)
end

local function draw_stuff()
	local sw, sh = screen.InternalRes.W, screen.InternalRes.H
	local p = patch.resources.parameters

	love.graphics.setCanvas(patch.srcCanvas)
	love.graphics.clear(0, 0, 0, 0)
	---  DRAW HERE
	love.graphics.setColor(1,1,1)  -- white 
	love.graphics.circle("fill", sw/2, sh/4, math.sqrt(sw^2 + sh^2)/10 * p:get("moonSize"))

	if cfg_shaders.enabled then
		love.graphics.setShader(sea_reflection)
	end
  ---  STOP DRAWING HERE
  
  love.graphics.setCanvas(patch.canvases.main)

	love.graphics.draw(patch.srcCanvas)

end

--- @public patch.draw draw routine
function patch:draw()
	self:drawSetup()

	-- draw picture
	draw_stuff()

	return self:drawExec()
end


function patch:update()
  -- reflection time
  if cfg_shaders.enabled then
    sea_reflection:send("_time", cfg_timers.globalTimer.T) 
  end

	self:mainUpdate()
	patch.lfo:UpdateFreq(clock.syncRate("1/2bar"))
	patch.lfo:UpdateTrigger(t)
end


function patch:commands(s)

end

return patch