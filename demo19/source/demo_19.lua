local Patch = lovjRequire("lib/patch")
local palettes = lovjRequire("lib/utils/palettes")
local kp = lovjRequire("lib/utils/keypress")
local Timer = lovjRequire("lib/timer")
local cfg_timers = lovjRequire("cfg/cfg_timers")
local cfg_screen = lovjRequire("cfg/cfg_screen")
local Envelope = lovjRequire("lib/signals/envelope")
local Lfo = lovjRequire("lib/signals/lfo")
local Feedback = lovjRequire("lib/feedback")

local PALETTE

local waveShaderCode = [[
	extern float _time;
	extern float _warpAmount;
	extern float _colorR;
	extern float _colorG;
	extern float _colorB;
	vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
	{
		float c = 1. - abs(sin(_time + texture_coords.y + texture_coords.x * _warpAmount));
		texture_coords.y = mod(texture_coords.x, c);
		c = 1. - abs(sin(_time + texture_coords.y + texture_coords.x * _warpAmount));
		texture_coords.x = mod(texture_coords.y, c);
		c = 1. - abs(sin(_time + texture_coords.y + texture_coords.x * _warpAmount));

		return vec4(_colorR + .01 * sin(c + _time), c * _colorG, _colorB + .02 * sin(c * _time), 1.);
	}
]]


local patch = Patch:new()

local function init_params()
	local p = patch.resources.parameters
	-- geometry
	p:define(1,  "innerRadius",  50,   { min = 10,  max = 150, type = "float" })
	p:define(2,  "outerRadius",  100,  { min = 20,  max = 250, type = "float" })
	p:define(3,  "innerCount",   10,   { min = 2,   max = 30,  step = 1, type = "int" })
	p:define(4,  "outerCount",   16,   { min = 2,   max = 40,  step = 1, type = "int" })
	p:define(5,  "ballSize",     7,    { min = 1,   max = 25,  type = "float" })
	p:define(6,  "ampRange",     0.7,  { min = 0,   max = 1,   type = "float" })
	-- motion (cycles per beat — synced to global BPM)
	p:define(7,  "innerSpeed",   0.5,   { min = 0.0625, max = 2,   type = "float" })
	p:define(8,  "outerSpeed",   0.125, { min = 0.0625, max = 1,   type = "float" })
	p:define(9,  "pulseSpeed",   0.25,  { min = 0.0625, max = 1,   type = "float" })
	p:define(10, "innerLayers",  5,    { min = 1,   max = 10,  step = 1, type = "int" })
	p:define(11, "layerSpread",  30,   { min = 5,   max = 80,  type = "float" })
	-- background shader
	p:define(12, "bgWarp",       5.0,  { min = 1,   max = 20,  type = "float" })
	p:define(13, "bgColorR",     0.2,  { min = 0,   max = 1,   type = "float" })
	p:define(14, "bgColorG",     0.8,  { min = 0,   max = 1,   type = "float" })
	p:define(15, "bgColorB",     0.65, { min = 0,   max = 1,   type = "float" })
	p:define(16, "bgTimeScale",  0.5,  { min = 0,   max = 2,   type = "float" })
	-- feedback (ghost trails behind the balls)
	p:define(17, "fbkDecay",     0.85, { min = 0.1, max = 1,   type = "float" })
	p:define(18, "fbkRotation",  0.02, { min = 0,   max = 0.5, type = "float" })
	p:define(19, "fbkZoom",      1.01, { min = 0.95,max = 1.15,type = "float" })
	p:define(20, "fbkTintR",     1.0,  { min = 0,   max = 1,   type = "float" })
	p:define(21, "fbkTintG",     1.0,  { min = 0,   max = 1,   type = "float" })
	p:define(22, "fbkTintB",     1.0,  { min = 0,   max = 1,   type = "float" })
end

function patch:patchControls()
	local p = patch.resources.parameters
	if kp.isDown("x") then patch.hang = true else patch.hang = false end
end


function patch:setCanvases()
	Patch.setCanvases(self)
	local w, h
	if cfg_screen.UPSCALE_MODE == cfg_screen.LOW_RES then
		w, h = screen.InternalRes.W, screen.InternalRes.H
	else
		w, h = screen.ExternalRes.W, screen.ExternalRes.H
	end
	patch.canvases.balls = love.graphics.newCanvas(w, h)
end


function patch:init(slot, globals, shaderext)
	Patch.init(self, slot, globals, shaderext)
	PALETTE = palettes.PICO8

	self:setCanvases()

	init_params()

	patch.timers = {}
	patch.timers.bpm = Timer:new(clock.beatDuration())

	patch.env = Envelope:new(0.1, 0.2, 0.5, 0.3)
	patch.compiledShader = love.graphics.newShader(waveShaderCode)
	patch.bgCanvas = love.graphics.newCanvas(screen.InternalRes.W, screen.InternalRes.H)
	patch.fbk = Feedback:new({
		width = screen.InternalRes.W,
		height = screen.InternalRes.H,
		clearColor = {0, 0, 0, 0},
	})
end


local function drawBalls(t, p)
	local cx, cy = screen.InternalRes.W / 2, screen.InternalRes.H / 2
	local innerR    = p:get("innerRadius")
	local outerR    = p:get("outerRadius")
	local innerN    = math.floor(p:get("innerCount"))
	local outerN    = math.floor(p:get("outerCount"))
	local bSize     = p:get("ballSize")
	local ampBase   = p:get("ampRange")
	local innerSpd  = clock.beatsToHz(p:get("innerSpeed"))
	local outerSpd  = clock.beatsToHz(p:get("outerSpeed"))
	local pulseSpd  = clock.beatsToHz(p:get("pulseSpeed"))
	local layers    = math.floor(p:get("innerLayers"))
	local layerSpr  = p:get("layerSpread")

	local amp = ampBase + (1 - ampBase) * math.abs(math.sin(2 * math.pi * t * pulseSpd))

	-- inner ring layers
	love.graphics.setColor(1, 1, 1, 0.8)
	for j = -layers, layers do
		for i = 1, innerN do
			love.graphics.circle("fill",
				cx + amp * (innerR + 10 * math.sin(2 * math.pi * (t * innerSpd + j / 5))) * math.cos(2 * math.pi * i / innerN + t * innerSpd + j / 4),
				cy + amp * (layerSpr * j + 10) * math.sin(2 * math.pi * i / innerN + t * innerSpd + j / 4),
				math.abs(math.sin(i / 2 + t * innerSpd)) * bSize * 0.7 + 2)
		end
	end

	-- outer ring
	love.graphics.setColor(1, 1, 1, 0.7)
	for i = 0, outerN do
		love.graphics.circle("fill",
			cx + (outerR + 10 * math.sin(2 * math.pi * (t * 2 * outerSpd + 4 * i / outerN))) * math.cos(2 * math.pi * (t * outerSpd + i / outerN)),
			cy + (outerR + 10 * math.sin(2 * math.pi * (t * 2 * outerSpd + 4 * i / outerN))) * math.sin(2 * math.pi * (t * outerSpd + i / outerN)),
			bSize)
	end
end


function patch:draw()
	local t = cfg_timers.globalTimer.T
	local p = patch.resources.parameters

	self:drawSetup()

	love.graphics.setCanvas(patch.bgCanvas)
	love.graphics.setColor(1, 1, 1, 1)

	if cfgShaders.enabled and patch.compiledShader then
		local s = patch.compiledShader
		love.graphics.setShader(s)
		s:send("_time", t * clock.beatsToHz(p:get("bgTimeScale")))
		s:send("_warpAmount", p:get("bgWarp"))
		s:send("_colorR", p:get("bgColorR"))
		s:send("_colorG", p:get("bgColorG"))
		s:send("_colorB", p:get("bgColorB"))
	end

	love.graphics.setCanvas(patch.canvases.main)
	love.graphics.draw(patch.bgCanvas)
	love.graphics.setShader()

	-- 2) draw balls onto a transparent canvas
	love.graphics.setCanvas(patch.canvases.balls)
	love.graphics.clear(0, 0, 0, 0)
	love.graphics.setColor(1, 1, 1, 1)
	drawBalls(t, p)

	-- 3) feed balls into feedback loop
	patch.fbk:process(patch.canvases.balls, {
		rotation = t * p:get("fbkRotation"),
		scaleX   = p:get("fbkZoom"),
		scaleY   = p:get("fbkZoom"),
		tint     = { p:get("fbkTintR"), p:get("fbkTintG"), p:get("fbkTintB"), p:get("fbkDecay") },
	})

	-- 4) composite: feedback ghosts (additive), then crisp balls on top
	local offX, offY = patch.fbk:getDrawOffset()
	love.graphics.setCanvas(patch.canvases.main)
	love.graphics.setBlendMode("add", "alphamultiply")
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(patch.fbk:getOutput(), offX, offY)
	love.graphics.draw(patch.canvases.balls)
	love.graphics.setBlendMode("alpha")

	love.graphics.setColor(1, 1, 1, 1)

	return self:drawExec()
end


function patch:update()
	self:mainUpdate()
	patch.timers.bpm:set_reset_t(clock.beatDuration())
	patch.timers.bpm:update()

	patch.env:UpdateTrigger(patch.timers.bpm:activated())
end


function patch:commands(s)

end

return patch
