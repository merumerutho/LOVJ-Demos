local Patch = lovjRequire("lib/patch")
local palettes = lovjRequire("lib/utils/palettes")
local controls = lovjRequire("lib/controls")
local cfg_timers = lovjRequire("cfg/cfg_timers")
local cfg_shaders = lovjRequire("cfg/cfg_shaders")
local Feedback = lovjRequire("lib/feedback")

local PALETTE = palettes.TIC80

local patch = Patch:new()

local function inScreen(x, y)
	return (x > 0 and x < screen.InternalRes.W and y > 0 and y < screen.InternalRes.H)
end

function patch.patchControls()
end


function patch.generatePoint(i)
	local point = {}
	point.x = screen.InternalRes.W / 2 + math.random(screen.InternalRes.W / 2) - math.random(screen.InternalRes.W / 2)
	point.y = screen.InternalRes.H / 2 + math.random(screen.InternalRes.H / 2) - math.random(screen.InternalRes.H / 2)
	point.dx = tonumber(point.x > screen.InternalRes.W / 2) or -1
	point.dy = tonumber(point.y > screen.InternalRes.H / 2) or -1
	point.i = i
	return point
end


function patch.updatePoints(l)
	local p = patch.resources.parameters

	local t = cfg_timers.globalTimer.T
	local dt = cfg_timers.globalTimer:dt()

	local r = math.random
	local cos = math.cos
	local sin = math.sin
	local pi = math.pi

	for k, v in pairs(l) do
		v.y = v.y + (r() * cos(2 * pi * (t / (p:get("speed_y") * 3) + v.i / #l)) + v.dy * (cos(pi * t * 2)) ^ 3) * dt * 50
		v.x = v.x + (r() * sin(2 * pi * (t / (p:get("speed_x") * 3) + v.i / #l)) + v.dx * (sin(pi * t * 2)) ^ 3) * dt * 50
	end
end

local function init_params()
	local p = patch.resources.parameters

	p:define(1, "speed_x",       20,   { min = 1,   max = 100, type = "float" })
	p:define(2, "speed_y",       30,   { min = 1,   max = 100, type = "float" })
	p:define(3, "lineWidth",     1,    { min = 1,   max = 10,  step = 0.5, type = "float" })
	p:define(4, "fbDecay",       0.92, { min = 0,   max = 1,   type = "float" })
	p:define(5, "fbRotation",    0.01, { min = -0.1,max = 0.1, type = "float" })
	p:define(6, "fbScale",       0.99, { min = 0.9, max = 1.1, type = "float" })
	p:define(7, "fbPixelate",    0.15, { min = 0.02,max = 1.0, type = "float" })
	p:define(8, "tintR",         1.0,  { min = 0,   max = 1,   type = "float" })
	p:define(9, "tintG",         0.75, { min = 0,   max = 1,   type = "float" })
	p:define(10,"tintB",         0.85, { min = 0,   max = 1,   type = "float" })

	return p
end

function patch.init(slot, globals, shaderext)
	Patch.init(patch, slot, globals, shaderext)
	patch.palette = PALETTE
	patch.nPoints = 3 + math.random(32)
	patch.points = {}
	for i = 1, patch.nPoints do
		table.insert(patch.points, patch.generatePoint(i))
	end

	patch:setCanvases()
	patch.resources.parameters = init_params()

	patch.pixShader = love.graphics.newShader(
		"extern float _pixres;\n" ..
		"vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {\n" ..
		"  vec2 uv = floor(tc * _pixres) / _pixres;\n" ..
		"  return Texel(tex, uv) * color;\n" ..
		"}"
	)

	patch.fb = Feedback:new({
		tint = {1, 0.75, 0.85, 0.92},
		rotation = 0.01,
		scaleX = 0.99,
		scaleY = 0.99,
		shader = patch.pixShader,
	})
end

function patch.reset()
	patch.nPoints = 3 + math.random(32)
	patch.points = {}
	for i = 1, patch.nPoints do
		table.insert(patch.points, patch.generatePoint(i))
	end
end

function patch.draw()
	local p = patch.resources.parameters

	patch:drawSetup()

	-- draw points and lines into main canvas
	for k, pix in pairs(patch.points) do
		if inScreen(pix.x, pix.y) then
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.points(pix.x, pix.y)
		end
	end

	love.graphics.setLineWidth(p:get("lineWidth"))
	love.graphics.setColor(1, 1, 1, 1)
	for k, pix in pairs(patch.points) do
		local po = patch.points
		if k == #po then
			love.graphics.line(po[k].x, po[k].y, po[1].x, po[1].y)
		else
			love.graphics.line(po[k].x, po[k].y, po[k + 1].x, po[k + 1].y)
		end
	end

	-- run feedback with pixelate shader on the echo step
	local decay = p:get("fbDecay")
	patch.pixShader:send("_pixres", p:get("fbPixelate"))
	patch.fb:process(patch.canvases.main, {
		rotation = p:get("fbRotation"),
		scaleX   = p:get("fbScale"),
		scaleY   = p:get("fbScale"),
		tint     = { p:get("tintR"), p:get("tintG"), p:get("tintB"), decay },
	})

	-- composite feedback behind fresh lines
	local ox, oy = patch.fb:getDrawOffset()
	love.graphics.setCanvas(patch.canvases.main)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setBlendMode("add", "alphamultiply")
	love.graphics.draw(patch.fb:getOutput(), ox, oy)
	love.graphics.setBlendMode("alpha")

	return patch:drawExec()
end

function patch.update()
	patch:mainUpdate()

	if cfg_timers.fpsTimer:activated() then
		patch.updatePoints(patch.points)
	end
end


function patch.commands(s)

end

return patch
