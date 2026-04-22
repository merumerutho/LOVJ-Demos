local Patch = lovjRequire("lib/patch")
local cfg_timers = lovjRequire("cfg/cfg_timers")

local patch = Patch:new()

local shader_code = [[
	#pragma language glsl3

	extern float _beat;
	extern float _subBeat;

	extern float _camOrbitSpeed;
	extern float _camOrbitRadius;
	extern float _camDriftX;
	extern float _camDriftY;
	extern float _camDriftZ;
	extern float _camJumpRate;
	extern float _camJumpSpread;
	extern float _camRoll;

	extern float _tunnelSize;
	extern float _tubeWave;
	extern float _boxScale;
	extern float _glowIntensity;
	extern float _modRate;
	extern float _modDepth;
	extern float _fogDensity;
	extern float _contrast;

	#define PI  3.14159265
	#define TAU 6.28318530
	#define MAX_STEPS 120
	#define MAX_DIST  400.0

	// --- hash ---
	float hash(float p) {
		p = fract(p * 0.1031);
		p *= p + 33.33;
		p *= p + p;
		return fract(p);
	}
	vec3 hash3(float n) {
		return vec3(hash(n), hash(n + 17.37), hash(n + 43.73));
	}

	// --- rotation ---
	mat2 rot(float a) {
		float c = cos(a), s = sin(a);
		return mat2(c, -s, s, c);
	}

	// --- tunnel spine path: smooth winding curve ---
	vec3 tunnelPath(float z) {
		float breathe = sin(_beat * _modRate * TAU) * _modDepth;
		return vec3(
			cos(z * 0.011) * 16.0 + cos(z * 0.012) * (24.0 + breathe * 4.0),
			cos(z * 0.01) * 4.0 + breathe * 2.0,
			z
		);
	}

	// --- box lattice ---
	float boxen(vec3 p) {
		float s = _boxScale;
		p = abs(fract(p / s) * s - s * 0.5) - 1.0;
		return min(p.x, min(p.y, p.z));
	}

	// --- scene with glow accumulation ---
	vec4 glow;

	float map(vec3 p) {
		vec3 q = tunnelPath(p.z);
		float pulse = 0.5 + 0.5 * sin(TAU * _subBeat);

		// ground plane
		float ground = q.y - p.y + 6.0;

		// box lattice
		float boxes = boxen(p);

		// center on tunnel path
		p.xy -= q.xy;

		// two glowing tubes snaking along Z
		float tubeWave = _tubeWave * (0.8 + 0.2 * pulse * _modDepth);
		float red  = length(p.xy - sin(p.z / 12.0 + vec2(0.0, 1.3)) * tubeWave) - (1.0 + 0.3 * pulse * _modDepth);
		float blue = length(p.xy - sin(p.z / 16.0 + vec2(0.0, 0.7)) * tubeWave * 1.3) - (2.0 + 0.5 * pulse * _modDepth);
		float tubes = min(red, blue);

		// glow accumulation from tubes
		float gi = _glowIntensity;
		glow += vec4(gi, 2.0, 1.0, 0.0) / (0.1 + abs(red));
		glow += vec4(1.0, 2.0, gi, 0.0) / (0.1 + abs(blue) * 0.1);

		// subtle wall texture
		vec3 ap = abs(p);
		float tex = length(sin(ap * 0.8 + cos(ap.yzx * 0.3) * 2.0)) * 0.15;

		// tunnel carve-out
		float ts = _tunnelSize;
		float tun = min(ts - ap.x - ap.y, (ts * 0.75) - ap.y);

		float d = max(min(boxes, ground), tun) - tex;
		return min(tubes, d);
	}

	// --- camera jump ---
	vec3 jumpPosition(float beat, float rate, float spread) {
		float idx = floor(beat * rate);
		vec2 a = (hash3(idx).xy * 2.0 - 1.0) * spread;
		vec2 b = (hash3(idx + 1.0).xy * 2.0 - 1.0) * spread;
		float t = fract(beat * rate);
		float snap = smoothstep(0.7, 1.0, t);
		return vec3(mix(a, b, snap), 0.0);
	}

	vec4 effect(vec4 color, Image tex, vec2 texCoord, vec2 screenCoord) {
		vec2 uv = (texCoord - 0.5);
		uv.x *= love_ScreenSize.x / love_ScreenSize.y;
		uv.y -= 0.15;

		// --- time drives the Z position along the tunnel ---
		float baseZ = _beat * _camDriftZ * 100.0;

		// camera on the tunnel path
		vec3 pathPos = tunnelPath(baseZ);

		// orbit around the path center
		float orbitAngle = _beat * _camOrbitSpeed * TAU;
		vec3 orbitOff = vec3(
			_camOrbitRadius * cos(orbitAngle),
			_camOrbitRadius * sin(orbitAngle),
			0.0
		);

		// linear XY drift
		vec3 drift = vec3(
			_beat * _camDriftX * 10.0,
			_beat * _camDriftY * 10.0,
			0.0
		);

		// jump
		vec3 jump = jumpPosition(_beat, _camJumpRate, _camJumpSpread * 8.0);

		vec3 ro = pathPos + orbitOff + drift + jump;

		// look-at: ahead along the tunnel path
		vec3 ahead = tunnelPath(baseZ + 2.0);
		vec3 Z = normalize(ahead - pathPos);
		vec3 X = normalize(vec3(Z.z, 0.0, -Z.x));
		vec3 Y = cross(X, Z);

		// camera roll
		float roll = _beat * _camOrbitSpeed * _camRoll * TAU;
		uv *= rot(roll);

		vec3 rd = normalize(uv.x * X + uv.y * Y + Z);

		// --- raymarch with glow accumulation ---
		glow = vec4(0.0);
		vec4 col = vec4(0.0);
		float d = 0.0;
		float s;
		vec3 p;

		for (int i = 0; i < MAX_STEPS; i++) {
			p = ro + rd * d;
			s = map(p) * 0.8;
			d += s;
			col += glow + 1.0 / max(s, 0.01);
			if (d > MAX_DIST) break;
		}

		// normal via tetrahedron technique
		const float h = 0.005;
		const vec2 k = vec2(1.0, -1.0);
		glow = vec4(0.0);
		vec3 n = normalize(
			k.xyy * map(p + k.xyy * h) +
			k.yyx * map(p + k.yyx * h) +
			k.yxy * map(p + k.yxy * h) +
			k.xxx * map(p + k.xxx * h)
		);

		// diffuse lighting
		col *= 0.1 + max(dot(n, -rd), 0.0);

		// reflection pass (shorter march for perf)
		vec4 ref = vec4(0.0);
		glow = vec4(0.0);
		p += n * 0.05;
		rd = reflect(rd, n);
		s = 0.0;
		for (int i = 0; i < 40; i++) {
			p += rd * s;
			s = map(p) * 0.8;
			ref += glow + 1.0 / max(s, 0.01);
		}
		col += col * ref;

		// tone mapping with warm/cool color channels + fog
		float fog = exp(-d * _fogDensity * 0.003);
		col *= fog;
		col = tanh(col / 1e9 * exp(vec4(10.0, 2.0, 1.0, 0.0) * d / 500.0));
		col = pow(col, vec4(_contrast));

		return vec4(col.rgb, 1.0);
	}
]]

local function init_params()
	local p = patch.resources.parameters
	p:define(1,  "camOrbitSpeed",  0.0625,{ min = 0,    max = 0.5,  type = "float" })
	p:define(2,  "camOrbitRadius", 2.0,   { min = 0.0,  max = 8.0,  type = "float" })
	p:define(3,  "camDriftX",      0.0,   { min = -2.0, max = 2.0,  type = "float" })
	p:define(4,  "camDriftY",      0.0,   { min = -2.0, max = 2.0,  type = "float" })
	p:define(5,  "camDriftZ",      0.25,  { min = -2.0, max = 2.0,  type = "float" })
	p:define(6,  "camJumpRate",    0.25,  { min = 0,    max = 2.0,  type = "float" })
	p:define(7,  "camJumpSpread",  1.0,   { min = 0,    max = 3.0,  type = "float" })
	p:define(8,  "camRoll",        0.0,   { min = 0,    max = 1.0,  type = "float" })
	p:define(9,  "tunnelSize",    32.0,   { min = 8.0,  max = 64.0, type = "float" })
	p:define(10, "tubeWave",      12.0,   { min = 2.0,  max = 24.0, type = "float" })
	p:define(11, "boxScale",      20.0,   { min = 5.0,  max = 80.0, type = "float" })
	p:define(12, "glowIntensity", 10.0,   { min = 1.0,  max = 30.0, type = "float" })
	p:define(13, "modRate",        0.25,  { min = 0.0625,max = 2.0, type = "float" })
	p:define(14, "modDepth",       0.6,   { min = 0,    max = 1.0,  type = "float" })
	p:define(15, "fogDensity",     1.0,   { min = 0,    max = 5.0,  type = "float" })
	p:define(16, "contrast",       1.0,   { min = 0.3,  max = 2.5,  type = "float" })
end

function patch:patchControls() end

function patch:init(slot, globals, shaderext)
	Patch.init(self, slot, globals, shaderext)
	self:setCanvases()
	init_params()
	patch.shader = love.graphics.newShader(shader_code)
	patch.srcCanvas = love.graphics.newCanvas(screen.InternalRes.W, screen.InternalRes.H)
end

function patch:draw()
	local p = patch.resources.parameters
	self:drawSetup()

	patch.shader:send("_beat", clock.beat)
	patch.shader:send("_subBeat", clock.subBeat)
	patch.shader:send("_camOrbitSpeed", p:get("camOrbitSpeed"))
	patch.shader:send("_camOrbitRadius", p:get("camOrbitRadius"))
	patch.shader:send("_camDriftX", p:get("camDriftX"))
	patch.shader:send("_camDriftY", p:get("camDriftY"))
	patch.shader:send("_camDriftZ", p:get("camDriftZ"))
	patch.shader:send("_camJumpRate", p:get("camJumpRate"))
	patch.shader:send("_camJumpSpread", p:get("camJumpSpread"))
	patch.shader:send("_camRoll", p:get("camRoll"))
	patch.shader:send("_tunnelSize", p:get("tunnelSize"))
	patch.shader:send("_tubeWave", p:get("tubeWave"))
	patch.shader:send("_boxScale", p:get("boxScale"))
	patch.shader:send("_glowIntensity", p:get("glowIntensity"))
	patch.shader:send("_modRate", p:get("modRate"))
	patch.shader:send("_modDepth", p:get("modDepth"))
	patch.shader:send("_fogDensity", p:get("fogDensity"))
	patch.shader:send("_contrast", p:get("contrast"))

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
