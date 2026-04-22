local Patch = lovjRequire("lib/patch")
local palettes = lovjRequire("lib/utils/palettes")
local kp = lovjRequire("lib/utils/keypress")
local Timer = lovjRequire("lib/timer")
local cfg_timers = lovjRequire("cfg/cfg_timers")
local cfg_screen = lovjRequire("cfg/cfg_screen")
local Lfo = lovjRequire("lib/signals/lfo")

local patch = Patch:new()

local PALETTE
local resW, resH


--- @private get_bg get background graphics based on patch.resources
local function get_bg()
	local g = patch.resources.graphics
	patch.graphics = {}
	patch.graphics.bg = {}
	patch.graphics.bg.wired = love.graphics.newImage(g:get("wired"))
	patch.graphics.bg.soul = love.graphics.newImage(g:get("soul"))
	patch.graphics.bg.image = patch.graphics.bg.wired
	patch.graphics.bg.size = {x = patch.graphics.bg.image:getPixelWidth(), y = patch.graphics.bg.image:getPixelHeight()}
	patch.graphics.bg.frames = {}
end

--- @private init_params initialize patch parameters
local function init_params()
	local g = patch.resources.graphics
	local p = patch.resources.parameters
	g:setName(1, "wired")				g:set("wired", "demos/demo13/assets/wired.png")
	g:setName(2, "soul")				g:set("soul", "demos/demo13/assets/soul.png")
	get_bg()
	p:define(1, "bgSpeed",   10,    { min = 1,    max = 50,  type = "float" })
	p:define(2, "bgLayer1",  1,    { min = 0,    max = 1,   step = 1, type = "int" })
	p:define(3, "bgLayer2",  1,    { min = 0,    max = 1,   step = 1, type = "int" })
	p:define(4, "bgLayer3",  1,    { min = 0,    max = 1,   step = 1, type = "int" })
	p:define(5, "dw",        0.83, { min = 0.01, max = 2.0, type = "float" })
	p:define(6, "dh",        0.66, { min = 0.01, max = 2.0, type = "float" })
	p:define(7, "nBalls",    30,   { min = 2,    max = 80,  step = 1, type = "int" })
	p:define(8, "radiusX",   70,   { min = 10,   max = 200, type = "float" })
	p:define(9, "radiusY",   50,   { min = 10,   max = 200, type = "float" })
	p:define(10,"ballSize",  7,    { min = 1,    max = 30,  type = "float" })

end

--- @public patchControls evaluate user keyboard controls
function patch.patchControls()
	local p = patch.resources.parameters
	-- Hanger
	if kp.isDown("x") then patch.hang = true else patch.hang = false end

	if kp.keypressOnRelease("1") then p:set("bgLayer1", (1-p:get("bgLayer1"))) end
	if kp.keypressOnRelease("2") then p:set("bgLayer2", (1-p:get("bgLayer2"))) end
	if kp.keypressOnRelease("3") then p:set("bgLayer3", (1-p:get("bgLayer3"))) end
end

function patch:setCanvases()
	Patch.setCanvases(patch)  -- call parent function
	-- patch-specific execution (window canvas)
	if not screen.isUpscalingHiRes() then
		resW, resH = screen.InternalRes.W, screen.InternalRes.H
	else
		resW, resH = screen.ExternalRes.W, screen.ExternalRes.H
	end
	patch.canvases.balls = love.graphics.newCanvas(resW, resH)
	patch.canvases.bg = love.graphics.newCanvas(resW, resH)
end


--- @public init init routine
function patch.init(slot, globals, shaderext)
	Patch.init(patch, slot, globals, shaderext)
	PALETTE = palettes.PICO8
	patch:setCanvases()

	init_params()

	patch.push = Lfo:new(clock.syncRate("4bar"), 0)

end

--- @private draw_bg draw background graphics
local function draw_bg()
	local t = cfg_timers.globalTimer.T

	local g = patch.resources.graphics
	local p = patch.resources.parameters

	love.graphics.setCanvas(patch.canvases.bg)

	local nX = math.ceil(resW / patch.graphics.bg.size.x)
	local nY = math.ceil(resH / patch.graphics.bg.size.y)

	love.graphics.setColor(0,0,0,1)
	love.graphics.rectangle("fill", 0, 0, resW, resH)
	love.graphics.setColor(1,1,1,1)

	local bg_alpha = 1 - ((t*2) % 1)

	if p:get("bgLayer1") == 1 and bg_alpha then
		for cx = -1, nX do
			for cy = -1, nY do
				local x = cx * patch.graphics.bg.size.x
				local y = cy * patch.graphics.bg.size.y + ((2 * (cx % 2)-1) * (t*20)) % patch.graphics.bg.size.y
			
				love.graphics.setColor(1, (cy+1)/(nY+1), (cy+1)/(nY+1), bg_alpha)
				love.graphics.draw(patch.graphics.bg.image, x, y)
			end
		end
	end

	love.graphics.setCanvas(patch.canvases.balls)
	love.graphics.clear()

	local nBalls = math.floor(p:get("nBalls"))

	local radiusX = p:get("radiusX")
	local radiusY = p:get("radiusY")
	local size = p:get("ballSize")

	local dw = p:get("dw")
	local dh = p:get("dh")

	local push = patch.push:Sine(t)

	for i = 1, nBalls do
		local cx = resW/2 + push * radiusX * math.sin(dw*(i/nBalls + t + math.sin(t))*2*math.pi)
		local cy = resH/2 + push * radiusY * math.cos(dh*(i/nBalls + t)*2*math.pi)
		local r = size + 3 * math.sin(3*(t*2+i/nBalls)*2*math.pi)

		love.graphics.setColor(1,1,1,i/nBalls)
		love.graphics.circle("fill", cx, cy, r, 8)
	end

	love.graphics.setColor(1,1,1,1)

	love.graphics.setCanvas(patch.canvases.main)
	love.graphics.draw(patch.canvases.bg)
	love.graphics.draw(patch.canvases.balls)

end

--- @public patch.draw draw routine
function patch.draw()
	patch:drawSetup(patch.hang)

	-- clear main canvas
	patch.canvases.main:renderTo(function()
									love.graphics.clear(1,1,1,1)
								end )

	-- draw picture
	draw_bg()

	return patch:drawExec()
end


function patch.update()
	local t = cfg_timers.globalTimer.T
	local p = patch.resources.parameters

	local amount
	if kp.isDown("lshift") then
		amount = 0.01
	else
		amount = 0.001
	end

	if kp.isDown("up") then p:set("dh", p:get("dh")+amount) end
	if kp.isDown("down") then p:set("dh", p:get("dh")-amount) end
	if kp.isDown("right") then p:set("dw", p:get("dw")+amount) end
	if kp.isDown("left") then p:set("dw", p:get("dw")-amount) end

	if math.floor(t) % 2 == 0 then
		patch.graphics.bg.image = patch.graphics.bg.wired
		patch.graphics.bg.size = {x = patch.graphics.bg.image:getPixelWidth(), y = patch.graphics.bg.image:getPixelHeight()}
	else
		patch.graphics.bg.image = patch.graphics.bg.soul
		patch.graphics.bg.size = {x = patch.graphics.bg.image:getPixelWidth(), y = patch.graphics.bg.image:getPixelHeight()}
	end

	patch.push:UpdateFreq(clock.syncRate("4bar"))
	patch.push:UpdateTrigger(true)

	patch:mainUpdate()
end


function patch.commands(s)

end

return patch