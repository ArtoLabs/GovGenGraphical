shader_type canvas_item;
// The ground of the whole world in one pass: which terrain every tile is comes from a small texture
// (one texel per tile), and the picture of each terrain from an array of tiling textures. Borders
// between terrains are bent by noise and blended, so there are no square tile edges; water moves,
// shores get foam, the worn earth of the camp shows through, and the seasons tint the land.

uniform sampler2D terrain_map : filter_nearest, repeat_disable;
uniform sampler2DArray ground : filter_nearest_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec2 map_size = vec2(200.0, 120.0);
uniform float tile_px = 32.0;
uniform vec2 camp = vec2(100.0, 60.0);     // the fire, in tiles
uniform float camp_radius = 3.6;
uniform vec3 leaf_tint = vec3(1.0);        // the season's colour on everything that grows
uniform float snow = 0.0;                  // 0: none, 1: deep winter

varying vec2 tile_pos;

void vertex() {
	tile_pos = UV * map_size;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float terrain_at(vec2 cell) {
	cell = clamp(cell, vec2(0.0), map_size - vec2(1.0));
	return floor(texelFetch(terrain_map, ivec2(cell), 0).r * 255.0 + 0.5);
}

vec3 tile(float kind, vec2 p, vec2 dx, vec2 dy) {
	vec2 cell = floor(p);
	float v = hash(cell + kind * 17.0);
	float variant = v < 0.52 ? 0.0 : (v < 0.68 ? 1.0 : (v < 0.84 ? 2.0 : 3.0));
	return textureGrad(ground, vec3(fract(p), kind * 4.0 + variant), dx, dy).rgb;
}

vec3 water(vec2 p, vec2 flow, vec2 dx, vec2 dy) {
	vec2 q = p + flow * TIME + vec2(sin(TIME * 0.55 + p.y * 1.7) * 0.07, cos(TIME * 0.45 + p.x * 1.3) * 0.05);
	q = floor(q * tile_px) / tile_px;
	return tile(0.0, q, dx, dy);
}

vec3 growing(vec3 c, float amount) {
	// What grows takes the season's colour, and in winter lies partly under snow.
	return mix(c, c * leaf_tint, amount);
}

vec3 shade(float id, vec2 p, vec3 n, vec2 dx, vec2 dy) {
	if (id < 0.5) {            // deep water
		return water(p, vec2(0.012, 0.02), dx, dy) * vec3(0.50, 0.62, 0.86);
	} else if (id < 1.5) {     // shallows
		return mix(water(p, vec2(0.015, 0.025), dx, dy), vec3(0.30, 0.66, 0.74), 0.28);
	} else if (id < 2.5) {     // river
		return mix(water(p, vec2(0.05, 0.16), dx, dy), vec3(0.45, 0.74, 0.95), 0.22) * 1.08;
	} else if (id < 3.5) {     // beach
		return tile(4.0, p, dx, dy);
	} else if (id < 4.5) {     // plains: grass, with meadows of flowers here and there
		vec3 g = tile(1.0, p, dx, dy);
		vec3 m = tile(2.0, p, dx, dy);
		return growing(mix(g, m, smoothstep(0.60, 0.66, n.r)), 0.9);
	} else if (id < 5.5) {     // marsh: sodden ground and standing water
		vec3 g = tile(3.0, p, dx, dy) * vec3(1.25, 1.25, 0.95);
		vec3 w = water(p, vec2(0.0), dx, dy) * vec3(0.55, 0.75, 0.62);
		return mix(growing(g, 0.6), w, smoothstep(0.50, 0.58, n.g));
	} else if (id < 6.5) {     // forest floor
		return growing(mix(tile(1.0, p, dx, dy), tile(3.0, p, dx, dy), 0.55), 0.9);
	} else if (id < 7.5) {     // deep forest floor
		return growing(tile(3.0, p, dx, dy) * 0.92, 0.9);
	} else if (id < 8.5) {     // hills: thin dry grass over stony earth
		vec3 g = growing(tile(1.0, p, dx, dy) * vec3(1.18, 1.05, 0.72), 0.7);
		return mix(g, tile(5.0, p, dx, dy), smoothstep(0.42, 0.56, n.b));
	} else if (id < 9.5) {     // mountains: bare rock
		return mix(tile(6.0, p, dx, dy) * 1.12, tile(5.0, p, dx, dy) * 0.75, smoothstep(0.62, 0.74, n.r) * 0.6);
	}
	return mix(tile(7.0, p, dx, dy), tile(6.0, p, dx, dy) * 1.2, smoothstep(0.70, 0.80, n.g) * 0.5);  // peaks
}

float is_water(float id) {
	return id < 2.5 ? 1.0 : 0.0;
}

float takes_snow(float id) {
	return (id > 2.5 && id < 9.5) ? 1.0 : 0.0;
}

void fragment() {
	vec2 dx = dFdx(tile_pos);
	vec2 dy = dFdy(tile_pos);
	// Everything is worked out per art pixel, so the blended borders stay crisp pixel art.
	vec2 p = (floor(tile_pos * tile_px) + 0.5) / tile_px;
	vec3 n = texture(noise_tex, p * 0.047).rgb;
	vec3 n2 = texture(noise_tex, p * 0.21 + vec2(0.37, 0.11)).rgb;
	vec2 q = p + (n2.rg - 0.5) * 0.95 + (n.gb - 0.5) * 0.6;
	vec2 f = q - 0.5;
	vec2 base = floor(f);
	vec2 w = smoothstep(0.34, 0.66, fract(f));
	float a = terrain_at(base);
	float b = terrain_at(base + vec2(1.0, 0.0));
	float c = terrain_at(base + vec2(0.0, 1.0));
	float d = terrain_at(base + vec2(1.0, 1.0));
	vec3 col;
	float wet;
	float snowy;
	if (a == b && a == c && a == d) {
		col = shade(a, p, n, dx, dy);
		wet = is_water(a);
		snowy = takes_snow(a);
	} else {
		col = mix(mix(shade(a, p, n, dx, dy), shade(b, p, n, dx, dy), w.x),
				mix(shade(c, p, n, dx, dy), shade(d, p, n, dx, dy), w.x), w.y);
		wet = mix(mix(is_water(a), is_water(b), w.x), mix(is_water(c), is_water(d), w.x), w.y);
		snowy = mix(mix(takes_snow(a), takes_snow(b), w.x), mix(takes_snow(c), takes_snow(d), w.x), w.y);
	}
	// The trodden earth of the camp.
	float trodden = 1.0 - smoothstep(camp_radius - 1.2, camp_radius + 0.4, distance(p, camp + vec2(0.5)) + (n2.b - 0.5) * 1.6);
	col = mix(col, tile(5.0, p, dx, dy) * vec3(0.92, 0.86, 0.78), trodden * 0.82 * (1.0 - wet));
	// Winter: snow lies in drifts on the land.
	float drift = smoothstep(0.92 - snow * 0.9, 1.0 - snow * 0.62, n.b * 0.8 + n2.r * 0.2 + hash(floor(p * tile_px)) * 0.08);
	col = mix(col, tile(7.0, p, dx, dy), drift * snowy * (1.0 - trodden * 0.7));
	// Where land meets water: damp ground, then a line of foam that comes and goes.
	float damp = smoothstep(0.08, 0.48, wet) * (1.0 - step(0.5, wet));
	col *= 1.0 - damp * 0.22;
	float foam = smoothstep(0.50, 0.56, wet) * (1.0 - smoothstep(0.62, 0.80, wet));
	foam *= 0.55 + 0.45 * sin(TIME * 1.4 + p.x * 2.3 + p.y * 1.9);
	col = mix(col, vec3(0.86, 0.95, 1.0), foam * 0.6);
	COLOR = vec4(col, 1.0);
}
