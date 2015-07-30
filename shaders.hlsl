cbuffer ConstantBuffer : register(b0)
{
	float4 offset;
};

// GLSL compatible mod()
float  modc(float  a, float  b) { return a - b * floor(a / b); }
float2 modc(float2 a, float2 b) { return a - b * floor(a / b); }
float3 modc(float3 a, float3 b) { return a - b * floor(a / b); }
float4 modc(float4 a, float4 b) { return a - b * floor(a / b); }


float sdBox(float3 p, float3 b)
{
	float3 d = abs(p) - b;
	return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

float sdBox(float2 p, float2 b)
{
	float2 d = abs(p) - b;
	return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float sdCross(in float3 p)
{
	float da = sdBox(p.xy, float2(1.0, 1.0));
	float db = sdBox(p.yz, float2(1.0, 1.0));
	float dc = sdBox(p.zx, float2(1.0, 1.0));
	return min(da, min(db, dc));
}

float sdHexPrism(float2 p, float2 h)
{
	float2 q = abs(p);
	return max(q.x - h.y, max(q.x + q.y*0.57735, q.y*1.1547) - h.x);
}

float3 nrand3(float2 co)
{
	float3 a = frac(cos(co.x*8.3e-3 + co.y)*float3(1.3e5, 4.7e5, 2.9e5));
	float3 b = frac(sin(co.x*0.3e-3 + co.y)*float3(8.1e5, 1.0e5, 0.1e5));
	float3 c = lerp(a, b, 0.5);
	return c;
}


float DE(float3 p)
{
	float h = 1.8;
	float rh = 0.5;
	float grid = 0.4;
	float grid_half = grid*0.5;
	float cube = 0.175;
	float3 orig = p;

	float3 g1 = float3(ceil((orig.x) / grid), ceil((orig.y) / grid), ceil((orig.z) / grid));
	float3 rxz = nrand3(g1.xz);
	float3 ryz = nrand3(g1.yz);

	p = -abs(p);
	float3 di = ceil(p / 4.8);
	p.y += di.x*1.0;
	p.x += di.y*1.2;
	p.xy = modc(p.xy, -4.8);

	float2 gap = float2(rxz.x*rh, ryz.y*rh);
	float d1 = p.y + h + gap.x;
	float d2 = p.x + h + gap.y;

	float2 p1 = modc(p.xz, float2(grid, grid)) - float2(grid_half, grid_half);
	float c1 = sdBox(p1, float2(cube, cube));

	float2 p2 = modc(p.yz, float2(grid, grid)) - float2(grid_half, grid_half);
	float c2 = sdBox(p2, float2(cube, cube));

	return max(max(c1, d1), max(c2, d2));
}

float3 GuessNormal(float3 p)
{
	const float d = 0.01;
	return normalize(float3(
		DE(p + float3(d, 0.0, 0.0)) - DE(p + float3(-d, 0.0, 0.0)),
		DE(p + float3(0.0, d, 0.0)) - DE(p + float3(0.0, -d, 0.0)),
		DE(p + float3(0.0, 0.0, d)) - DE(p + float3(0.0, 0.0, -d))));
}

float4 Scene(float2 pos, float4 params)
{
	float2 _ScreenParams = float2(1280.0, 720.0);
	float time = params.x;
	float aspect = _ScreenParams.x / _ScreenParams.y;
	float2 screen_pos = (pos + float2(1.0, 1.0)) * 0.5 * _ScreenParams.xy;
	pos.x *= aspect;

	float3 camPos = float3(-0.5, 0.0, 3.0);
	float3 camDir = normalize(float3(0.3, 0.0, -1.0));
	camPos -= float3(0.0, 0.0, time*2.0);
	float3 camUp = normalize(float3(0.5, 1.0, 0.0));
	float3 camSide = cross(camDir, camUp);
	float focus = 1.8;

	float3 rayDir = normalize(camSide*pos.x + camUp*pos.y + camDir*focus);
	float3 ray = camPos;
	int march = 0;
	float d = 0.0;

	float total_d = 0.0;
	#define MAX_MARCH 64
	#define MAX_DIST 100.0
	for (int mi = 0; mi<MAX_MARCH; ++mi) {
		d = DE(ray);
		march = mi;
		total_d += d;
		ray += rayDir * d;
		if (d<0.001) { break; }
		if (total_d>MAX_DIST) {
			total_d = MAX_DIST;
			march = MAX_MARCH - 1;
			break;
		}
	}

	float glow = 0.0;
	{
		const float s = 0.0075;
		float3 p = ray;
		float3 n1 = GuessNormal(ray);
		float3 n2 = GuessNormal(ray + float3(s, 0.0, 0.0));
		float3 n3 = GuessNormal(ray + float3(0.0, s, 0.0));
		glow = (1.0 - abs(dot(camDir, n1)))*0.5;
		if (dot(n1, n2)<0.8 || dot(n1, n3)<0.8) {
			glow += 0.6;
		}
	}
	{
		float3 p = ray;
		float grid1 = max(0.0, max((modc((p.x + p.y + p.z*2.0) - time*3.0, 5.0) - 4.0)*1.5, 0.0));
		float grid2 = max(0.0, max((modc((p.x + p.y*2.0 + p.z) - time*2.0, 7.0) - 6.0)*1.2, 0.0));
		float3 gp1 = abs(modc(p, float3(0.24, 0.24, 0.24)));
		float3 gp2 = abs(modc(p, float3(0.32, 0.32, 0.32)));
		if (gp1.x<0.23 && gp1.z<0.23) {
			grid1 = 0.0;
		}
		if (gp2.y<0.31 && gp2.z<0.31) {
			grid2 = 0.0;
		}
		glow += grid1 + grid2;
	}

	float fog = min(1.0, (1.0 / float(MAX_MARCH)) * float(march))*1.0;
	float3  fog2 = 0.01 * float3(1, 1, 1.5) * total_d;
	glow *= min(1.0, 4.0 - (4.0 / float(MAX_MARCH - 1)) * float(march));
	float scanline = modc(screen_pos.y, 4.0) < 2.0 ? 0.7 : 1.0;

	return float4(float3(0.15 + glow*0.75, 0.15 + glow*0.75, 0.2 + glow)*fog + fog2, 1.0) * scanline;
}

struct PSInput
{
	float4 position : SV_POSITION;
	float4 screen_position : TEXCOORD0;
	float4 params : TEXCOORD1;
};

PSInput VSMain(float4 position : POSITION, float4 color : COLOR)
{
	PSInput result;

	result.position = result.screen_position = position;
	result.params = offset;

	return result;
}

float4 PSMain(PSInput input) : SV_TARGET
{
	float2 spos = input.screen_position.xy;
	//return float4(spos,0,0);
	return Scene(spos, input.params);
}
