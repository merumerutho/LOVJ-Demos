local Patch = lovjRequire("lib/patch")
local palettes = lovjRequire("lib/utils/palettes")
local kp = lovjRequire("lib/utils/keypress")
local Timer = lovjRequire("lib/timer")
local cfg_timers = lovjRequire("cfg/cfg_timers")
local cfg_screen = lovjRequire("cfg/cfg_screen")
local Envelope = lovjRequire("lib/signals/envelope")
local Lfo = lovjRequire("lib/signals/lfo")
local Feedback = lovjRequire("lib/feedback")

local patch = Patch:new()

local PALETTE

--- @private init_params initialize patch parameters
local function init_params()
	local p = patch.resources.parameters
	p:define(1,  "sphereCount",  40,   { min = 2,    max = 80,   step = 1, type = "int" })
	p:define(2,  "sphereRadius", 7,    { min = 1,    max = 30,   type = "float" })
	p:define(3,  "spreadX",      100,  { min = 10,   max = 300,  type = "float" })
	p:define(4,  "spreadY",      80,   { min = 10,   max = 300,  type = "float" })
	p:define(5,  "speedX",       0.015, { min = 0.001,max = 0.1,  type = "float" })
	p:define(6,  "speedY",       0.05,  { min = 0.001,max = 0.25, type = "float" })
	p:define(7,  "drift",        50,   { min = 0,    max = 200,  type = "float" })
	p:define(8,  "fbkRotation",  1.0,  { min = 0,    max = 6.28, type = "float" })
	p:define(9,  "fbkZoom",      1.05, { min = 0.9,  max = 1.3,  type = "float" })
	p:define(10, "fbkDecay",     0.7,  { min = 0.1,  max = 1.0,  type = "float" })
	p:define(11, "fbkTintR",     1.0,  { min = 0,    max = 1,    type = "float" })
	p:define(12, "fbkTintG",     0.9,  { min = 0,    max = 1,    type = "float" })
	p:define(13, "fbkTintB",     1.0,  { min = 0,    max = 1,    type = "float" })
end

--- @public patchControls evaluate user keyboard controls
function patch:patchControls()
	local p = patch.resources.parameters
	if love.keyboard.isDown("r") then patch.init(patch.slot) cfg_timers.globalTimer:reset() end
end


--- @public setCanvases (re)set canvases for this patch
function patch:setCanvases()
	Patch.setCanvases(self)

	if cfg_screen.UPSCALE_MODE == cfg_screen.LOW_RES then
        patch.canvases.c1 = love.graphics.newCanvas(2*screen.InternalRes.W, 2*screen.InternalRes.H)
	else
		patch.canvases.c1 = love.graphics.newCanvas(2*screen.ExternalRes.W, 2*screen.ExternalRes.H)
	end
end


--- @public init init routine
function patch:init(slot, globals, shaderext)
	Patch.init(self, slot, globals, shaderext)

	PALETTE = palettes.PICO8

	self:setCanvases()
	patch.fbk = Feedback:new({ clearColor = {0, 0, 0, 0} })

	init_params()
end


--- @public patch.draw draw routine
function patch:draw()
	local t = cfg_timers.globalTimer.T
	local p = patch.resources.parameters

	local cx, cy = screen.InternalRes.W, screen.InternalRes.H

	local count    = math.floor(p:get("sphereCount"))
	local radius   = p:get("sphereRadius")
	local spreadX  = p:get("spreadX")
	local spreadY  = p:get("spreadY")
	local speedX   = clock.beatsToHz(p:get("speedX"))
	local speedY   = clock.beatsToHz(p:get("speedY"))
	local drift    = p:get("drift")

	self:drawSetup()

	-- draw fresh content onto c1
    love.graphics.setColor(1,1,1,1)
	love.graphics.setCanvas(patch.canvases.c1)
	love.graphics.clear(0,0,0,0)

	local half = count / 2
	for i = -half, half, 0.5 do
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.circle("fill",
			cx + spreadX * math.sin(2*math.pi*(t*speedX + i/3)) + drift * math.cos(2*math.pi*(t/100 + i/40)),
			cy + spreadY * math.cos(2*math.pi*(t*speedY + i/20)) + drift * math.sin(2*math.pi*(t/100 + i/40)),
			radius)
	end

	-- feedback with animated transform
	local fbkRot   = p:get("fbkRotation")
	local fbkZoom  = p:get("fbkZoom")
	local fbkDecay = p:get("fbkDecay")

	patch.fbk:process(patch.canvases.c1, {
		rotation = t * fbkRot,
		scaleX = fbkZoom,
		scaleY = fbkZoom,
		tint = { p:get("fbkTintR"), p:get("fbkTintG"), p:get("fbkTintB"), fbkDecay },
	})

	-- compose onto main
    love.graphics.setCanvas(patch.canvases.main)
	love.graphics.clear(0,0,0,0)
	love.graphics.setColor(1,1,1,1)
	local offX, offY = patch.fbk:getDrawOffset()
	love.graphics.draw(patch.fbk:getOutput(), -cx/2 + offX, -cy/2 + offY)

	return self:drawExec()
end


function patch:update()
	self:mainUpdate()
end


function patch:commands(s)

end

return patch
