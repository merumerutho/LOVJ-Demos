local Patch = lovjRequire ("lib/patch")
local screen = lovjRequire ("lib/screen")
local cfg_screen = lovjRequire("cfg/cfg_screen")
local cfg_timers = lovjRequire ("cfg/cfg_timers")

local patch = Patch:new()

local ROACH_WIDTH = 128
local ROACH_HEIGHT = 165
local NUM_FRAMES_ROACH = 35

local PALETTE

--- @private patchControls handle controls for current patch
function patch.patchControls()
	-- Hanger
	if love.keyboard.isDown("x") then patch.hang = true else patch.hang = false end
	-- Reset
	if love.keyboard.isDown("r") then patch.init(patch.slot) end
end

--- @private get_roach get roach :)
local function get_roach()
	local g = patch.resources.graphics
	patch.graphics.roach = {}
	patch.graphics.roach.image = love.graphics.newImage(g:get("roach"))
	patch.graphics.roach.size = {x = ROACH_WIDTH, y = ROACH_HEIGHT}
	patch.graphics.roach.frames = {}
	for i=0,patch.graphics.roach.image:getWidth() / ROACH_WIDTH do
		table.insert(patch.graphics.roach.frames, love.graphics.newQuad(i*ROACH_WIDTH,					-- x
																		0,								-- y
																		ROACH_WIDTH,					-- width
																		ROACH_HEIGHT,					-- height
																		patch.graphics.roach.image))	-- img
	end
end


--- @private init_params Initialize parameters for this patch
local function init_params()
	local g = patch.resources.graphics
	local p = patch.resources.parameters

	patch.graphics = {}

	g:setName(1, "roach")				g:set("roach", "demos/demo18/assets/cockroach.png")
	get_roach()

	--g:setName(2, "love")				g:set("love", "data/graphics/love.png")

	p:define(1, "gridCount",    20,   { min = 2,   max = 40,  step = 1, type = "int" })
	p:define(2, "showRoach",    1,    { min = 0,   max = 1,   step = 1, type = "int" })
	p:define(3, "roachScale",   0.75, { min = 0.1, max = 2.0, type = "float" })
	p:define(4, "animSpeed",    25,   { min = 5,   max = 60,  type = "float" })
	p:define(5, "bgScale",      0.1,  { min = 0.02,max = 0.5, type = "float" })

	patch.resources.parameters = p
	patch.resources.graphics = g
end

--- @public setCanvases (re)set canvases for this patch
function patch:setCanvases()
	Patch.setCanvases(patch)  -- call parent function
	-- patch-specific execution (window canvas)
	if cfg_screen.UPSCALE_MODE == cfg_screen.LOW_RES then
		patch.canvases.window = love.graphics.newCanvas(screen.InternalRes.W, screen.InternalRes.H)
		patch.canvases.roach = love.graphics.newCanvas(screen.InternalRes.W, screen.InternalRes.H)
		patch.canvases.love = love.graphics.newCanvas(screen.InternalRes.W, screen.InternalRes.H)
	else
		patch.canvases.window = love.graphics.newCanvas(screen.ExternalRes.W, screen.ExternalRes.H)
		patch.canvases.roach = love.graphics.newCanvas(screen.ExternalRes.W, screen.ExternalRes.H)
		patch.canvases.love = love.graphics.newCanvas(screen.ExternalRes.W, screen.ExternalRes.H)
	end
end


function patch.init(slot, globals, shaderext)
	Patch.init(patch, slot, globals, shaderext)
	patch.hang = false
	patch:setCanvases()

	init_params()
end


function patch.draw()
	patch:drawSetup()

	local p = patch.resources.parameters
	local t = cfg_timers.globalTimer.T

	love.graphics.setCanvas(patch.canvases.main)

	local n = math.floor(p:get("gridCount"))
	local scaling = p:get("bgScale")
	local animSpd = p:get("animSpeed")

	for i = -1, n do
		for j = -1, n do
			love.graphics.draw(patch.graphics.roach.image,
								patch.graphics.roach.frames[math.floor(t*animSpd + j + i) % NUM_FRAMES_ROACH + 1],
								(screen.InternalRes.W / n)*i,
								(screen.InternalRes.H / n)*j,
								0,
								scaling,
								scaling)
		end
	end

	-- Hue rotation
	love.graphics.setColor(.5+.5*math.sin((2*math.pi)*t),.5+.5*math.sin((2*math.pi)*(t+.3333)),.5+.5*math.sin((2*math.pi)*(t+.6666)),1)

	-- Draw main roach
	local rScale = p:get("roachScale")
	if p:get("showRoach") == 1 then
		love.graphics.draw(patch.graphics.roach.image,
							patch.graphics.roach.frames[math.floor(t*animSpd) % NUM_FRAMES_ROACH + 1],
							screen.InternalRes.W/2+ROACH_WIDTH*rScale/2,
							10,
							0,
							-rScale,
							rScale)
	end

	love.graphics.setColor(1,1,1,1)

	return patch:drawExec()
end


function patch.update()
	patch:mainUpdate()
end


function patch.commands(s)

end

return patch