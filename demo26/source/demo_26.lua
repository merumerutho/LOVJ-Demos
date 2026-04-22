local Patch = lovjRequire("lib/patch")
local cfg_timers = lovjRequire("cfg/cfg_timers")

local patch = Patch:new()

local tunnel_code = [[
	extern float _time;
	extern float _speed;
	extern float _twist;
	extern float _radius;
	extern float _texFreqU;
	extern float _texFreqV;
	extern float _fogDensity;
	extern float _paletteShift;
	extern float _wobble;

	#define PI 3.14159265

	vec3 palette(float t) {
		vec3 a = vec3(0.5, 0.5, 0.5);
		vec3 b = vec3(0.5, 0.5, 0.5);
		vec3 c = vec3(1.0, 1.0, 0.5);
		vec3 d = vec3(0.80, 0.90, 0.30);
		return a + b * cos(2.0 * PI * (c * t + d));
	}

	vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
		vec2 uv = tc - 0.5;

		float wobX = sin(_time * 0.7) * _wobble;
		float wobY = cos(_time * 0.9) * _wobble;
		uv += vec2(wobX, wobY);

		float angle = atan(uv.y, uv.x);
		float dist = length(uv);

		if (dist < 0.001) dist = 0.001;
		float depth = _radius / dist;

		float u = angle / PI * _texFreqU + _time * _twist;
		float v = depth * _texFreqV + _time * _speed;

		float pattern = sin(u * 6.0) * cos(v * 4.0);
		pattern += sin(u * 3.0 + v * 2.0 + _time);
		pattern = pattern * 0.5 + 0.5;

		float grid = abs(sin(u * 8.0)) * abs(sin(v * 8.0));
		grid = smoothstep(0.0, 0.15, grid);

		float shade = mix(pattern, grid, 0.4);

		vec3 col = palette(shade * 0.5 + _paletteShift + _time * 0.05);

		float fog = exp(-depth * _fogDensity * 0.1);
		col *= fog;

		float edge = smoothstep(0.0, 0.05, dist) * smoothstep(0.5, 0.35, dist);
		col *= edge;

		return vec4(col, 1.0);
	}
]]

local function init_params()
	local p = patch.resources.parameters

	p:define(1, "speed",        0.25, { min = 0,   max = 1.5,  type = "float" })
	p:define(2, "twist",        0.15, { min = -1,  max = 1,    type = "float" })
	p:define(3, "radius",       0.15, { min = 0.02,max = 0.5, type = "float" })
	p:define(4, "texFreqU",     2.0,  { min = 0.5, max = 8,   type = "float" })
	p:define(5, "texFreqV",     1.0,  { min = 0.2, max = 6,   type = "float" })
	p:define(6, "fogDensity",   1.0,  { min = 0,   max = 5,   type = "float" })
	p:define(7, "paletteShift", 0.0,  { min = 0,   max = 1,   type = "float" })
	p:define(8, "wobble",       0.05, { min = 0,   max = 0.3, type = "float" })
end

function patch.patchControls() end

function patch.init(slot, globals, shaderext)
	Patch.init(patch, slot, globals, shaderext)
	patch:setCanvases()
	init_params()
	patch.shader = love.graphics.newShader(tunnel_code)
	patch.srcCanvas = love.graphics.newCanvas(screen.InternalRes.W, screen.InternalRes.H)
end

function patch.draw()
	local p = patch.resources.parameters
	local t = cfg_timers.globalTimer.T

	patch:drawSetup()

	patch.shader:send("_time", t)
	patch.shader:send("_speed", clock.beatsToHz(p:get("speed")))
	patch.shader:send("_twist", clock.beatsToHz(p:get("twist")))
	patch.shader:send("_radius", p:get("radius"))
	patch.shader:send("_texFreqU", p:get("texFreqU"))
	patch.shader:send("_texFreqV", p:get("texFreqV"))
	patch.shader:send("_fogDensity", p:get("fogDensity"))
	patch.shader:send("_paletteShift", p:get("paletteShift"))
	patch.shader:send("_wobble", p:get("wobble"))

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
