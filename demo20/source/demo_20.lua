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

local function init_params()
	local p = patch.resources.parameters
	p:define(1, "spriteScale",  0.05, { min = 0.01, max = 0.3, type = "float" })
	p:define(2, "fbkRotation",  0.1,  { min = 0,    max = 2,   type = "float" })
	p:define(3, "fbkZoom",      1.2,  { min = 0.9,  max = 1.5, type = "float" })
	p:define(4, "fbkOpacity",   0.9,  { min = 0.1,  max = 1,   type = "float" })
	p:define(5, "crossHeight",  200,  { min = 50,   max = 400, type = "float" })
	p:define(6, "crossOsc",     50,   { min = 0,    max = 150, type = "float" })
end

--- @public patchControls evaluate user keyboard controls
function patch.patchControls()
	local p = patch.resources.parameters
	if love.keyboard.isDown("r") then patch.init(patch.slot) cfg_timers.globalTimer:reset() end
end


--- @public setCanvases (re)set canvases for this patch
function patch:setCanvases()
	Patch.setCanvases(patch)

	if cfg_screen.UPSCALE_MODE == cfg_screen.LOW_RES then
        patch.canvases.c1 = love.graphics.newCanvas(2*screen.InternalRes.W, 2*screen.InternalRes.H)
		patch.canvases.top1 = love.graphics.newCanvas(2*screen.InternalRes.W, 2*screen.InternalRes.H)
		patch.canvases.top2 = love.graphics.newCanvas(2*screen.InternalRes.W, 2*screen.InternalRes.H)
		patch.canvases.globaltop = love.graphics.newCanvas(2*screen.InternalRes.W, 2*screen.InternalRes.H)
	else
		patch.canvases.c1 = love.graphics.newCanvas(2*screen.ExternalRes.W, 2*screen.ExternalRes.H)
		patch.canvases.top1 = love.graphics.newCanvas(2*screen.ExternalRes.W, 2*screen.ExternalRes.H)
		patch.canvases.top2 = love.graphics.newCanvas(2*screen.ExternalRes.W, 2*screen.ExternalRes.H)
		patch.canvases.globaltop = love.graphics.newCanvas(2*screen.ExternalRes.W, 2*screen.ExternalRes.H)
	end
end


--- @private get_bg get background graphics based on patch.resources
local function get_gameboy()
	local g = patch.resources.graphics
	patch.graphics = {}
	patch.graphics.gameboy = {}
	patch.graphics.gameboy.gb = love.graphics.newImage("demos/demo20/assets/gb.png")
	patch.graphics.gameboy.size = {x = patch.graphics.gameboy.gb:getPixelWidth(), y = patch.graphics.gameboy.gb:getPixelHeight()}
	patch.graphics.gameboy.frames = {}
end


--- @public init init routine
function patch.init(slot, globals, shaderext)
	Patch.init(patch, slot, globals, shaderext)

	PALETTE = palettes.PICO8

	patch:setCanvases()
	patch.fbk = Feedback:new({ tint = {1, 1, 1, 1}, clearColor = {0, 0, 0, 1} })

	get_gameboy()

	init_params()
end


--- @public patch.draw draw routine
function patch.draw()
	local t = cfg_timers.globalTimer.T

	local cx, cy = screen.InternalRes.W , screen.InternalRes.H

	patch:drawSetup()

	-- ## main graphics pipeline ##
    love.graphics.setColor(1,1,1,1)
	love.graphics.setCanvas(patch.canvases.c1)
	love.graphics.clear(0,0,0,0)

	local p = patch.resources.parameters
	local sc = p:get("spriteScale")
	love.graphics.draw(patch.graphics.gameboy.gb,
						cx  - patch.graphics.gameboy.size.x * sc / 2,
						cy - patch.graphics.gameboy.size.y * sc / 2,
						0,
						sc,
						sc)

	local cw, ch = 2*cx/3, p:get("crossHeight") + math.cos(2*math.pi*t/10) * p:get("crossOsc")
	local crx, cry = cx/4 + (cx/4-cw/2), cy/4 + (cy/4-ch/2)

	-- erase globalTop (make it black for correct alpha multiply)
	love.graphics.setCanvas(patch.canvases.globalTop)
	love.graphics.clear(0,0,0,1)

	-- prepare top1
	love.graphics.setCanvas(patch.canvases.top1)
	love.graphics.clear(0,0,0,1)
	love.graphics.setColor(1,1,1,1)
	love.graphics.rectangle("fill", crx, cry, cw, ch, 15, 15)

	-- copy on top2
	love.graphics.setCanvas(patch.canvases.top2)
	love.graphics.clear(0,0,0, t%1)
	love.graphics.setColor(1,1,1,1)
	love.graphics.draw(patch.canvases.top1, cx/2, cy/2, 3.1415/2, cx/2, cy/2)

	-- ## feedback pipeline ##
	patch.fbk:process(patch.canvases.c1, {
		rotation = t * p:get("fbkRotation"),
		scaleX = p:get("fbkZoom"),
		scaleY = p:get("fbkZoom"),
	})

	-- %% cross composition pipeline %%
	love.graphics.setCanvas(patch.canvases.globaltop)
	love.graphics.setColor(1,1,1,1)
	love.graphics.draw(patch.canvases.top1, cx/2, cy/2, 0, 1, 1, cx/2, cy/2)

    -- ## compose output pipeline ##
    love.graphics.setCanvas(patch.canvases.main)
	love.graphics.clear(0,0,0,1)
	local offX, offY = patch.fbk:getDrawOffset()
	love.graphics.setColor(1,1,1,p:get("fbkOpacity"))
	love.graphics.draw(patch.fbk:getOutput(), -cx/2 + offX, -cy/2 + offY)
	love.graphics.setColor(1,1,1,1)
    love.graphics.draw(patch.canvases.c1, -cx/2, -cy/2)

	return patch:drawExec()
end


function patch.update()
	patch:mainUpdate()
end


function patch.commands(s)

end

return patch
