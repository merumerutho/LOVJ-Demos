local Patch = lovjRequire("lib/patch")
local cfg_timers = lovjRequire("cfg/cfg_timers")

local patch = Patch:new()

local plasma_code = [[
	extern float _time;
	extern float _freq1;
	extern float _freq2;
	extern float _freq3;
	extern float _speed;
	extern float _paletteSpeed;
	extern float _contrast;
	extern float _scale;
	extern float _distortion;

	#define PI 3.14159265

	vec3 palette(float t) {
		vec3 a = vec3(0.5, 0.5, 0.5);
		vec3 b = vec3(0.5, 0.5, 0.5);
		vec3 c = vec3(1.0, 1.0, 1.0);
		vec3 d = vec3(0.00, 0.33, 0.67);
		return a + b * cos(2.0 * PI * (c * t + d));
	}

	vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
		vec2 uv = (tc - 0.5) * _scale;
		float t = _time * _speed;

		float v = sin(uv.x * _freq1 + t);
		v += sin(uv.y * _freq2 + t * 0.7);
		v += sin((uv.x * _freq1 + uv.y * _freq2) * 0.5 + t * 1.3);
		v += sin(length(uv) * _freq3 + t * 0.9);

		float dist = sin(uv.y * 3.0 + t * 0.5) * _distortion;
		v += sin((uv.x + dist) * _freq2 * 1.5 + t * 1.1);

		v *= 0.2 * _contrast;
		vec3 col = palette(v + _time * _paletteSpeed);
		return vec4(col, 1.0);
	}
]]

local function init_params()
	local p = patch.resources.parameters

	p:define(1, "freq1",        4.0,  { min = 0.5, max = 20, type = "float" })
	p:define(2, "freq2",        6.0,  { min = 0.5, max = 20, type = "float" })
	p:define(3, "freq3",        3.0,  { min = 0.5, max = 20, type = "float" })
	p:define(4, "speed",        0.5,   { min = 0,   max = 2,    type = "float" })
	p:define(5, "paletteSpeed", 0.05, { min = 0,   max = 1,    type = "float" })
	p:define(6, "contrast",     1.0,  { min = 0.2, max = 3,  type = "float" })
	p:define(7, "scale",        4.0,  { min = 0.5, max = 12, type = "float" })
	p:define(8, "distortion",   0.3,  { min = 0,   max = 2,  type = "float" })
end

function patch.patchControls() end

function patch.init(slot, globals, shaderext)
	Patch.init(patch, slot, globals, shaderext)
	patch:setCanvases()
	init_params()
	patch.shader = love.graphics.newShader(plasma_code)
	patch.srcCanvas = love.graphics.newCanvas(screen.InternalRes.W, screen.InternalRes.H)
end

function patch.draw()
	local p = patch.resources.parameters
	local t = cfg_timers.globalTimer.T

	patch:drawSetup()

	patch.shader:send("_time", t)
	patch.shader:send("_freq1", p:get("freq1"))
	patch.shader:send("_freq2", p:get("freq2"))
	patch.shader:send("_freq3", p:get("freq3"))
	patch.shader:send("_speed", clock.beatsToHz(p:get("speed")))
	patch.shader:send("_paletteSpeed", clock.beatsToHz(p:get("paletteSpeed")))
	patch.shader:send("_contrast", p:get("contrast"))
	patch.shader:send("_scale", p:get("scale"))
	patch.shader:send("_distortion", p:get("distortion"))

	love.graphics.setShader(patch.shader)
	love.graphics.draw(patch.srcCanvas)
	love.graphics.setShader()

	return patch:drawExec()
end

function patch.update()
	patch:mainUpdate()
end

function patch.commands(s) end

return patch
