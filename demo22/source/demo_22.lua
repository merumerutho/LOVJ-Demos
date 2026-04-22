local Patch = lovjRequire("lib/patch")
local palettes = lovjRequire("lib/utils/palettes")
local kp = lovjRequire("lib/utils/keypress")
local Timer = lovjRequire("lib/timer")
local cfg_timers = lovjRequire("cfg/cfg_timers")
local cfg_screen = lovjRequire("cfg/cfg_screen")
local Lfo = lovjRequire("lib/signals/lfo")

local PALETTE

local textSlideShow = {"wired sound, wired soul, "}

local patch = Patch:new()

--- @private init_params initialize patch parameters
local function init_params()
	local p = patch.resources.parameters
	p:define(1,  "gridRows",    25,   { min = 2,    max = 60,  step = 1, type = "int" })
	p:define(2,  "gridCols",    40,   { min = 2,    max = 80,  step = 1, type = "int" })
	p:define(3,  "gridStep",    0.5,  { min = 0.1,  max = 2.0, type = "float" })
	p:define(4,  "speed",       0.5,  { min = 0.0625, max = 2.0, type = "float" })
	p:define(5,  "arcSize",     40,   { min = 1,    max = 200, type = "float" })
	p:define(6,  "waveAmp",     8,    { min = 0,    max = 40,  type = "float" })
	p:define(7,  "spreadX",     4,    { min = 1,    max = 20,  type = "float" })
	p:define(8,  "spreadY",     8,    { min = 1,    max = 20,  type = "float" })
	p:define(9,  "hue",         0.3,  { min = 0,    max = 1,   type = "float" })
	p:define(10, "saturation",  0.5,  { min = 0,    max = 1,   type = "float" })
end

--- @public patchControls evaluate user keyboard controls
function patch:patchControls()
	local p = patch.resources.parameters
	if kp.isDown("x") then patch.hang = true else patch.hang = false end
end

function patch:setCanvases()
	Patch.setCanvases(self)
	if cfg_screen.UPSCALE_MODE == cfg_screen.LOW_RES then
		patch.canvases.balls = love.graphics.newCanvas(screen.InternalRes.W, screen.InternalRes.H)
		patch.canvases.bg = love.graphics.newCanvas(screen.InternalRes.W, screen.InternalRes.H)
	else
		patch.canvases.balls = love.graphics.newCanvas(screen.ExternalRes.W, screen.ExternalRes.H)
		patch.canvases.bg = love.graphics.newCanvas(screen.ExternalRes.W, screen.ExternalRes.H)
	end
end


--- @public init init routine
function patch:init(slot, globals, shaderext)
	Patch.init(self, slot, globals, shaderext)
	PALETTE = palettes.PICO8
	self:setCanvases()

	init_params()

	patch.push = Lfo:new(clock.syncRate("4bar"), 0)

	patch.fontSize = 8
	patch.ANSI_font = love.graphics.newFont("demos/demo22/assets/arial.ttf", patch.fontSize)
	patch.TXT_font = love.graphics.newFont("demos/demo22/assets/c64mono.ttf", patch.fontSize*2)
end


--- @private draw_scene draw the arc grid
local function draw_scene()
	local t = cfg_timers.globalTimer.T
	local p = patch.resources.parameters

	local cx = screen.InternalRes.W / 2
	local cy = screen.InternalRes.H / 2

	local rows    = math.floor(p:get("gridRows"))
	local cols    = math.floor(p:get("gridCols"))
	local gStep   = p:get("gridStep")
	local speed   = clock.beatsToHz(p:get("speed"))
	local arcSize = p:get("arcSize")
	local waveAmp = p:get("waveAmp")
	local sX      = p:get("spreadX")
	local sY      = p:get("spreadY")
	local hue     = p:get("hue")
	local sat     = p:get("saturation")

	love.graphics.setFont(patch.ANSI_font)

	for j = -rows, rows, 1 do
		for k = -cols, cols, gStep do
			local x = cx + j * (sX + waveAmp * math.sin(k / 10 + t * speed))
			local y = cy + k * sY + (j * k / 20) + (k * j) * math.sin(t * speed)
			local alpha = math.abs(1 - (t * speed + 0.5 * math.sin(t * speed + k / 10 + j / 10)) % 1)
			local size = 2 * (j + k) + math.sin(t * speed + j - k) * arcSize

			local r = (math.abs(alpha + j - k + math.sin(t * 2 * speed))) * 0.05 + hue
			local g = alpha + 0.4 - math.sin(t * speed + j / 10) % 3
			local b = sat + 0.2 * math.abs(math.sin(k + t * speed))

			love.graphics.setColor(r, g, b, alpha)
			love.graphics.arc("fill",
				20 * math.sin(k) + x, y,
				size,
				0.5 * math.sin(t * speed + k),
				0.1 * math.sin(j * k * 10),
				1)
		end
	end

	love.graphics.setColor(0, 0, 0, 1)
end

--- @public patch.draw draw routine
function patch:draw()
	self:drawSetup(patch.hang)

	patch.canvases.main:renderTo(function()
		love.graphics.clear(0, 0, 0, 1)
	end)

	draw_scene()

	return self:drawExec()
end


function patch:update()
	local t = cfg_timers.globalTimer.T
	patch.push:UpdateFreq(clock.syncRate("4bar"))
	patch.push:UpdateTrigger(true)
	self:mainUpdate()
end


function patch:commands(s)

end

return patch
