local Patch = lovjRequire("lib/patch")
local palettes = lovjRequire("lib/utils/palettes")
local videoutils = lovjRequire("lib/utils/video")
local screen_settings = lovjRequire("cfg/cfg_screen")
local cfg_shaders = lovjRequire("cfg/cfg_shaders")
local Timer = lovjRequire("lib/timer")
local cfg_timers = lovjRequire("cfg/cfg_timers")


-- import pico8 palette
local PALETTE

local patch = Patch:new()

--- @public setCanvases (re)set canvases for this patch
function patch:setCanvases()
	Patch.setCanvases(patch)  -- call parent function
	-- patch-specific execution (video canvas)
	if screen_settings.UPSCALE_MODE == screen_settings.LOW_RES then
		patch.canvases.video = love.graphics.newCanvas(screen.InternalRes.W, screen.InternalRes.H)
	else
		patch.canvases.video = love.graphics.newCanvas(screen.ExternalRes.W, screen.ExternalRes.H)
	end
end

--- @private init_params initialize patch parameters
local function init_params()
	local g = patch.resources.graphics
	local p = patch.resources.parameters

    g:setName(1, "video")           g:set("video", "demos/demo7/assets/demo.ogg")

	p:define(1, "playbackSpeed", 1.0,  { min = -2,  max = 4,   type = "float" })
	p:define(2, "loopEnd",       10,   { min = 1,   max = 30,  type = "float" })
	p:define(3, "bgColorR",      0.2,  { min = 0,   max = 1,   type = "float" })
	p:define(4, "bgColorG",      0.4,  { min = 0,   max = 1,   type = "float" })
	p:define(5, "bgColorB",      0.1,  { min = 0,   max = 1,   type = "float" })

	patch.resources.graphics = g
end

--- @public patchControls evaluate user keyboard controls
function patch.patchControls()
	local p = patch.resources.parameters

    -- insert here your patch controls
end


--- @public init init routine
function patch.init(slot, globals, shaderext)
	Patch.init(patch, slot, globals, shaderext)
	PALETTE = palettes.PICO8

	patch:setCanvases()

	init_params()

    local g = patch.resources.graphics
    patch.video = {}
    patch.video.handle = love.graphics.newVideo(g:get("video"))
    patch.video.pos = 0
	patch.video.scaleX = screen.InternalRes.W / patch.video.handle:getWidth()
	patch.video.scaleY = screen.InternalRes.H / patch.video.handle:getHeight()
	patch.video.loopStart = 0
	patch.video.loopEnd = 10
	patch.video.playbackSpeed = 1
    patch.video.handle:play()
end

--- @private draw_bg draw background graphics
local function draw_stuff()
	local g = patch.resources.graphics
	local p = patch.resources.parameters

end

--- @public patch.draw draw routine
function patch.draw()
	patch:drawSetup()

	local t = cfg_timers.globalTimer.T

	local p = patch.resources.parameters
	local col = {p:get("bgColorR"), p:get("bgColorG"), p:get("bgColorB")}
	love.graphics.clear(col)

	love.graphics.setCanvas(patch.canvases.video)
	love.graphics.draw(patch.video.handle, 0, 0, 0, patch.video.scaleX, patch.video.scaleY)

	love.graphics.setCanvas(patch.canvases.main)
	if screen.isUpscalingHiRes() then
		love.graphics.draw(patch.canvases.video, 0, 0, 0, screen.Scaling.X, screen.Scaling.Y)
	else
		love.graphics.draw(patch.canvases.video)
	end

	return patch:drawExec()
end


function patch.update()
    patch:mainUpdate()
    local p = patch.resources.parameters
    patch.video.playbackSpeed = p:get("playbackSpeed")
    patch.video.loopEnd = p:get("loopEnd")
    videoutils.handleLoop(patch.video)
end


function patch.commands(s)

end

return patch