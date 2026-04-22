local Patch = lovjRequire("lib/patch")
local palettes = lovjRequire("lib/utils/palettes")
local kp = lovjRequire("lib/utils/keypress")
local Envelope = lovjRequire("lib/signals/envelope")
local Lfo = lovjRequire("lib/signals/lfo")
local Timer = lovjRequire("lib/timer")
local cfg_timers = lovjRequire("cfg/cfg_timers")
local cfg_shaders  = lovjRequire("cfg/cfg_shaders")

-- declare palette
local PALETTE

local shader_code = [[
	#pragma language glsl3
	uniform float _time;
	uniform float _osc;
	uniform float _ballSize;
	extern float _colorInversion;

	// Constants
	#define PI 3.1415925359
	#define TWO_PI 6.2831852
	#define MAX_STEPS 200
	#define MAX_DIST 500.
	#define SURFACE_DIST .01

	vec3 pMod2(inout vec3 p, float size){
		float halfsize = size*0.5;
		vec3 c = floor((p+halfsize)/size);
		p = mod(p+halfsize,size)-halfsize;
		return c;
	}

	float sdCone( vec3 p, vec2 c, float h )
	{
	  float q = length(p.xz);
	  return max(dot(c.xy,vec2(q,p.y)),-h-p.y);
	}

	float GetDist_Weird(vec3 p)
	{
		float modSize = 5.;
		vec3 coords = vec3(modSize/2 + .7 * sin(sin(p.z/100)+abs(p.y-.5)), modSize/2 + .1 * cos(p.z) , modSize/2);
		vec4 s = vec4(coords, _ballSize + .5 * cos(p.z/10) + .5*sin(p.z/100 + abs(p.y/10)));
		float sphereDist = length(mod(p.xy, modSize)-s.xz) + .12 * sin(_osc*5+.1*p.z+p.x*10.+p.y*5.) - s.w;
		return sphereDist;
	}

	float GetDist_Weirder(vec3 p)
	{
		vec3 coords = vec3(1. , 1. , 2.);
		float modSize = 1.0;

		vec4 s = vec4(coords, .5); //Sphere. xyz is position w is radius
		float sphereDist = length(mod(0.1*p.xyz, 2.5)); // + mod(p.x, 2.5) * .1 * mod(p.y, 2.5));
		return sphereDist;
	}

	float RayMarch(vec3 ro, vec3 rd)
	{
		float dO = 0.; // Distance Origin
		for(int i=0;i<MAX_STEPS;i++)
		{
			vec3 p = ro + rd * dO;
			float ds = GetDist_Weird(p); // ds is Distance Scene
			dO += ds;
			if(dO > MAX_DIST || ds < SURFACE_DIST) break;
		}
		return dO;
	}

	vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
	{
    vec2 uv = (texture_coords - .5);

		vec3 ro = vec3(.2, 2 + _time, 10 + 2*_time);

    vec3 rd = normalize(vec3(uv.x, uv.y, .5));
    // Rotation
    //rd.x = rd.x*cos(_time) - rd.y*sin(_time);
    //rd.y = rd.x*sin(_time) + rd.y*cos(_time);
    //rd.z = rd.z;
    
    float d = RayMarch(ro, rd);
    d = sqrt(d/100);
    vec3 output_color = vec3(d + (1. - 2*d)*_colorInversion);

    return vec4(output_color, 1.);
	}
]]

local patch = Patch:new()

--- @private init_params initialize patch parameters
local function init_params()
	local g = patch.resources.graphics
	local p = patch.resources.parameters

	p:define(1, "colorInversion", 0,    { min = 0, max = 1,   type = "float" })
	p:define(2, "ballSize",      0.1,  { min = 0, max = 0.7, type = "float" })
	p:define(3, "lfoFreq",       0.5,  { min = 0.0625, max = 2, type = "float" })

	patch.resources.parameters = p
end

--- @public patchControls evaluate user keyboard controls
function patch:patchControls()
	local p = patch.resources.parameters
	if kp.isDown("up") then p:set("colorInversion", math.min(p:get("colorInversion") + .1, 1)) end
	if kp.isDown("down") then p:set("colorInversion", math.max(p:get("colorInversion") - .1, 0)) end

	if kp.isDown("left") then p:set("ballSize", math.max(p:get("ballSize") - .01, 0)) end
	if kp.isDown("right") then p:set("ballSize", math.min(p:get("ballSize") + .01, .7)) end
end


--- @public init init routine
function patch:init(slot, globals, shaderext)
	Patch.init(self, slot, globals, shaderext)
	PALETTE = palettes.PICO8
	self:setCanvases()

	init_params()

	patch.lfo = Lfo:new(clock.beatsToHz(patch.resources.parameters:get("lfoFreq")), 0)
	patch.compiledShader = love.graphics.newShader(shader_code)
	patch.srcCanvas = love.graphics.newCanvas(screen.InternalRes.W, screen.InternalRes.H)
end

local function draw_stuff()
	local p = patch.resources.parameters
	local t = cfg_timers.globalTimer.T

	love.graphics.setCanvas(patch.srcCanvas)

	if cfg_shaders.enabled and patch.compiledShader then
		love.graphics.setShader(patch.compiledShader)
		patch.compiledShader:send("_time", t)
		patch.compiledShader:send("_osc", t + .1 * patch.lfo:Sine(t))
		patch.compiledShader:send("_colorInversion", p:get("colorInversion"))
		patch.compiledShader:send("_ballSize", p:get("ballSize"))
	end

	love.graphics.setCanvas(patch.canvases.main)
	love.graphics.draw(patch.srcCanvas)

end

--- @public patch.draw draw routine
function patch:draw()
	self:drawSetup()

	-- draw picture
	draw_stuff()

	return self:drawExec()
end


function patch:update()
	local t = cfg_timers.globalTimer.T

	self:mainUpdate()
	patch.lfo:UpdateFreq(clock.beatsToHz(patch.resources.parameters:get("lfoFreq")))
	patch.lfo:UpdateTrigger(t)
end


function patch:commands(s)

end

return patch