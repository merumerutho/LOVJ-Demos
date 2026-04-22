local Patch = lovjRequire("lib/patch")
local palettes = lovjRequire("lib/utils/palettes")
local kp = lovjRequire("lib/utils/keypress")
local Envelope = lovjRequire("lib/signals/envelope")
local Lfo = lovjRequire("lib/signals/lfo")
local Timer = lovjRequire("lib/timer")
local cfg_timers = lovjRequire("cfg/cfg_timers")
local cfg_shaders  = lovjRequire("cfg/cfg_shaders")

local PALETTE

local shader_code = [[
	#pragma language glsl3

	extern float _time;

	// Camera / global
	extern float _zoom;
	extern float _rotSpeedY;
	extern float _rotSpeedX;

	// Shape
	extern float _distortion;
	extern float _radialFreq;    // frequency of radial sin (maps 1–12)
	extern float _noiseMix;      // how much angular noise feeds into radial (maps 0–4)
	extern float _noiseModPeriod; // mod() period in angular noise (maps 0.02–1.0)
	extern float _noiseTimeScale; // time multiplier feeding into the mod (maps 0–0.5)

	// Map wiggle
	extern float _mapWiggle;     // amplitude of pos displacement in map() (maps 0–0.2)
	extern float _mapFreq;       // spatial frequency for map wiggle (maps 1–12)
	extern float _mapTimeScale;  // time multiplier for map wiggle (maps 0–6)

	// Lighting
	extern float _specular;
	extern float _colorR;
	extern float _colorG;
	extern float _colorB;

	// UV
	extern float _uvWarp;
	extern float _uvModPeriod;   // mod() period in the UV warp (maps 0.01–0.5)

	// Rendering
	extern float _renderDistance;

	// per-pixel constants, set once in render() before the march loop
	float _c_distAmt, _c_rFreq, _c_nMix, _c_nModP, _c_nTimeS;
	float _c_mWig, _c_mFreq, _c_mTime;

	float spikyExplosion(vec3 pos, float radius) {
		vec3 dir = pos / (radius + 0.0001);

		float angularNoise =
			sin(dot(mod(dir.xy + _time * _c_nTimeS, _c_nModP), vec2(3.0, 1.3)) * 2.0 + _time * 0.5) +
			sin(dot(dir.yz, vec2(1.5, 2.8)) * 2.5 + _time * 0.35);

		float radialDistortion = sin(radius * _c_rFreq + angularNoise * _c_nMix);
		return radius - (0.1 + _c_distAmt * radialDistortion);
	}

	float map(vec3 pos) {
		pos.xy += _c_mWig * sin(pos.z * _c_mFreq + _time * _c_mTime);
		float radius = length(pos);
		return spikyExplosion(pos, radius);
	}

	vec3 getNormal(vec3 pos, float t) {
		float e = max(0.05, 0.01 * t);
		return normalize(vec3(
			map(pos + vec3(e, 0, 0)) - map(pos - vec3(e, 0, 0)),
			map(pos + vec3(0, e, 0)) - map(pos - vec3(0, e, 0)),
			map(pos + vec3(0, 0, e)) - map(pos - vec3(0, 0, e))
		));
	}

	mat3 rotateY(float a) {
		float c = cos(a), s = sin(a);
		return mat3(c, 0.0, -s, 0.0, 1.0, 0.0, s, 0.0, c);
	}

	mat3 rotateX(float a) {
		float c = cos(a), s = sin(a);
		return mat3(1.0, 0.0, 0.0, 0.0, c, -s, 0.0, s, c);
	}

	vec3 lighting(vec3 p, vec3 n, vec3 rd) {
		float specPow = mix(2.0, 64.0, _specular);
		vec3 lightDir = normalize(vec3(1.2, 1.0, 2.5));
		vec3 h = normalize(lightDir - rd);
		float diff = max(dot(n, lightDir), 0.0);
		float spec = pow(max(dot(n, h), 0.0), specPow);
		float fresnel = pow(1.0 - max(dot(n, -rd), 0.0), 2.0);

		float tWave = 0.5 + 0.5 * sin(_time * 0.6);
		vec3 baseCol = vec3(_colorR, _colorG, _colorB);
		vec3 dynamicCol = mix(baseCol, baseCol + 0.2, tWave);
		vec3 base = mix(dynamicCol, vec3(1.0), diff);
		vec3 highlight = mix(vec3(0.7, 0.85, 1.0), vec3(1.0), spec) * (spec + fresnel);
		return base + highlight;
	}

	vec3 render(vec2 uv) {
		float camDist = mix(1.5, 8.0, _zoom);
		float rSpeedY = mix(0.0, 1.5, _rotSpeedY);
		float rSpeedX = mix(0.0, 1.5, _rotSpeedX);

		vec3 ro = vec3(0.0, 0.0, -camDist + sin(_time));
		vec3 rd = normalize(vec3(uv, 1.0));
		mat3 camRot = rotateY(_time * rSpeedY) * rotateX(_time * rSpeedX);
		ro = camRot * ro;
		rd = camRot * rd;

		_c_distAmt = mix(0.0, 5.0, _distortion);
		_c_rFreq   = mix(1.0, 12.0, _radialFreq);
		_c_nMix    = mix(0.0, 4.0, _noiseMix);
		_c_nModP   = mix(0.02, 1.0, _noiseModPeriod);
		_c_nTimeS  = mix(0.0, 0.5, _noiseTimeScale);
		_c_mWig    = mix(0.0, 0.2, _mapWiggle);
		_c_mFreq   = mix(1.0, 12.0, _mapFreq);
		_c_mTime   = mix(0.0, 6.0, _mapTimeScale);

		float t = 0.0;
		bool hit = false;
		vec3 p;
		float d;
		int cycles = int(500.0 * _renderDistance);
		float max_dist = 10.0;

		for (int i = 0; i < cycles; i++) {
			p = ro + rd * t;
			d = map(p);
			if (d < 0.001) { hit = true; break; }
			t += min(d * 0.5, 0.025);
			if (t > max_dist) break;
		}

		vec3 col = vec3(0.0);
		if (hit) {
			vec3 n = getNormal(p, t);
			col = lighting(p, n, rd);
		}
		return clamp(col, 0.0, 1.0);
	}

	vec4 effect(vec4 color, Image tex, vec2 texCoord, vec2 screenCoord) {
		float warp  = mix(0.0, 0.5, _uvWarp);
		float uvMod = mix(0.01, 0.5, _uvModPeriod);
		vec2 uv = texCoord - 0.5;
		uv = uv * (1.0 + warp * mod(sin(_time + (uv.x + uv.y * uv.y)), uvMod));
		uv.x *= love_ScreenSize.x / love_ScreenSize.y;
		vec3 colorOut = render(uv);
		return vec4(colorOut, 1.0);
	}
]]

local patch = Patch:new()

local PARAMS = {
	{ name = "zoom",           default = 0.35, min = 0, max = 1 },
	{ name = "rotSpeedY",      default = 0.27, min = 0, max = 1 },
	{ name = "rotSpeedX",      default = 0.13, min = 0, max = 1 },
	{ name = "distortion",     default = 0.40, min = 0, max = 1 },
	{ name = "radialFreq",     default = 0.25, min = 0, max = 1 },
	{ name = "noiseMix",       default = 0.38, min = 0, max = 1 },
	{ name = "noiseModPeriod", default = 0.23, min = 0, max = 1 },
	{ name = "noiseTimeScale", default = 0.20, min = 0, max = 1 },
	{ name = "mapWiggle",      default = 0.25, min = 0, max = 1 },
	{ name = "mapFreq",        default = 0.25, min = 0, max = 1 },
	{ name = "mapTimeScale",   default = 0.42, min = 0, max = 1 },
	{ name = "specular",       default = 0.28, min = 0, max = 1 },
	{ name = "colorR",         default = 0.10, min = 0, max = 1 },
	{ name = "colorG",         default = 0.35, min = 0, max = 1 },
	{ name = "colorB",         default = 0.80, min = 0, max = 1 },
	{ name = "uvWarp",         default = 0.50, min = 0, max = 1 },
	{ name = "uvModPeriod",    default = 0.22, min = 0, max = 1 },
	{ name = "renderDistance",  default = 0.8, min = 0, max = 1 },
}

local function init_params()
	local p = patch.resources.parameters
	for i, def in ipairs(PARAMS) do
		p:define(i, def.name, def.default, { min = def.min, max = def.max, type = "float" })
	end
end


function patch:patchControls()
	local p = patch.resources.parameters
	if kp.isDown("up")    then p:set("zoom", math.min(p:get("zoom") + 0.01, 1)) end
	if kp.isDown("down")  then p:set("zoom", math.max(p:get("zoom") - 0.01, 0)) end
	if kp.isDown("left")  then p:set("distortion", math.max(p:get("distortion") - 0.01, 0)) end
	if kp.isDown("right") then p:set("distortion", math.min(p:get("distortion") + 0.01, 1)) end
end


function patch:init(slot, globals, shaderext)
	Patch.init(self, slot, globals, shaderext)
	PALETTE = palettes.PICO8
	self:setCanvases()
	init_params()
	patch.lfo = Lfo:new(clock.syncRate("1/2bar"), 0)
	patch.compiledShader = love.graphics.newShader(shader_code)
	patch.srcCanvas = love.graphics.newCanvas(screen.InternalRes.W, screen.InternalRes.H)
end


local function draw_stuff()
	local p = patch.resources.parameters
	local t = cfg_timers.globalTimer.T

	love.graphics.setCanvas(patch.srcCanvas)

	if cfg_shaders.enabled and patch.compiledShader then
		local s = patch.compiledShader
		love.graphics.setShader(s)
		s:send("_time", t)
		for _, def in ipairs(PARAMS) do
			s:send("_" .. def.name, p:get(def.name))
		end
	end

	love.graphics.setCanvas(patch.canvases.main)
	love.graphics.draw(patch.srcCanvas)
end


function patch:draw()
	self:drawSetup()
	draw_stuff()
	return self:drawExec()
end


function patch:update()
	local t = cfg_timers.globalTimer.T
	self:mainUpdate()
	patch.lfo:UpdateFreq(clock.syncRate("1/2bar"))
	patch.lfo:UpdateTrigger(t)
end


return patch
