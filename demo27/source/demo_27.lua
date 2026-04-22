local Patch = lovjRequire("lib/patch")
local cfg_timers = lovjRequire("cfg/cfg_timers")

local patch = Patch:new()

local MAX_BALLS = 8

local metaball_code = [[
	extern float _time;
	extern float _threshold;
	extern float _smoothness;
	extern float _glow;
	extern float _paletteSpeed;
	extern int   _numBalls;
	extern vec2  _balls[8];

	#define PI 3.14159265

	vec3 palette(float t) {
		vec3 a = vec3(0.5, 0.5, 0.5);
		vec3 b = vec3(0.5, 0.5, 0.5);
		vec3 c = vec3(2.0, 1.0, 0.0);
		vec3 d = vec3(0.50, 0.20, 0.25);
		return a + b * cos(2.0 * PI * (c * t + d));
	}

	vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
		vec2 uv = tc;
		float aspect = love_ScreenSize.x / love_ScreenSize.y;
		uv.x *= aspect;

		float field = 0.0;
		for (int i = 0; i < 8; i++) {
			if (i >= _numBalls) break;
			vec2 pos = _balls[i];
			pos.x *= aspect;
			float d = length(uv - pos);
			field += _smoothness / (d * d + 0.001);
		}

		float edge = smoothstep(_threshold - _glow, _threshold, field);
		float inner = smoothstep(_threshold, _threshold + _glow * 4.0, field);

		float val = field * 0.01 + _time * _paletteSpeed;
		vec3 col = palette(val);

		vec3 edgeCol = col * edge;
		vec3 coreCol = mix(col, vec3(1.0), inner * 0.5) * inner;
		vec3 result = max(edgeCol, coreCol);

		float bg = smoothstep(_threshold * 0.3, _threshold * 0.5, field);
		result *= bg;

		return vec4(result, 1.0);
	}
]]

local function init_params()
	local p = patch.resources.parameters

	p:define(1, "numBalls",     5,    { min = 2,   max = MAX_BALLS, step = 1, type = "int" })
	p:define(2, "threshold",    8.0,  { min = 1,   max = 30,  type = "float" })
	p:define(3, "smoothness",   0.03, { min = 0.005,max = 0.2, type = "float" })
	p:define(4, "glow",         2.0,  { min = 0,   max = 10,  type = "float" })
	p:define(5, "paletteSpeed", 0.05, { min = 0,   max = 0.5,  type = "float" })
	p:define(6, "orbitRadius",  0.2,  { min = 0.05,max = 0.45,type = "float" })
	p:define(7, "speed",        0.5,  { min = 0,   max = 2,    type = "float" })
	p:define(8, "chaos",        0.5,  { min = 0,   max = 2,   type = "float" })
end

function patch:patchControls() end

function patch:init(slot, globals, shaderext)
	Patch.init(self, slot, globals, shaderext)
	self:setCanvases()
	init_params()
	patch.shader = love.graphics.newShader(metaball_code)
	patch.srcCanvas = love.graphics.newCanvas(screen.InternalRes.W, screen.InternalRes.H)
	patch.ballPositions = {}
	for i = 1, MAX_BALLS do
		patch.ballPositions[i] = { 0.5, 0.5 }
	end
end

function patch:draw()
	local p = patch.resources.parameters
	local t = cfg_timers.globalTimer.T

	self:drawSetup()

	local n = math.floor(p:get("numBalls"))
	local radius = p:get("orbitRadius")
	local spd = clock.beatsToHz(p:get("speed"))
	local chaos = p:get("chaos")
	local pi = math.pi

	for i = 1, MAX_BALLS do
		local phase = (i - 1) / n * 2 * pi
		local r = radius * (1 + 0.3 * math.sin(t * spd * 0.7 + i * 1.7) * chaos)
		local x = 0.5 + r * math.cos(t * spd + phase + math.sin(t * spd * 0.5 + i) * chaos)
		local y = 0.5 + r * math.sin(t * spd * 1.3 + phase + math.cos(t * spd * 0.3 + i * 2.1) * chaos)
		patch.ballPositions[i] = { x, y }
	end

	patch.shader:send("_time", t)
	patch.shader:send("_numBalls", n)
	patch.shader:send("_threshold", p:get("threshold"))
	patch.shader:send("_smoothness", p:get("smoothness"))
	patch.shader:send("_glow", p:get("glow"))
	patch.shader:send("_paletteSpeed", clock.beatsToHz(p:get("paletteSpeed")))

	local flat = {}
	for i = 1, MAX_BALLS do
		flat[i] = patch.ballPositions[i]
	end
	patch.shader:send("_balls", unpack(flat))

	love.graphics.setShader(patch.shader)
	love.graphics.draw(patch.srcCanvas)
	love.graphics.setShader()

	return self:drawExec()
end

function patch:update()
	self:mainUpdate()
end

function patch:commands(s) end

return patch
