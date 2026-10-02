shader_type spatial;
// Realistic-ish skin for the MakeHuman-based characters.
// Vertex colour carries face paint masks baked by tools/characters/build_characters.py:
//   R lips, G eyebrows, B stubble zone, A eye-socket shading.
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 tone : source_color = vec3(0.8, 0.62, 0.52);
uniform vec3 lip_tint : source_color = vec3(0.62, 0.32, 0.30);
uniform vec3 brow_color : source_color = vec3(0.08, 0.06, 0.05);
uniform float brow_strength : hint_range(0.0, 1.0) = 0.85;
uniform float stubble : hint_range(0.0, 1.0) = 0.0;
uniform float socket_shade : hint_range(0.0, 1.0) = 0.35;
uniform sampler2D pores_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D mottle : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float pore_scale = 14.0;
uniform float pore_strength = 0.35;
uniform float sss = 0.35;

void fragment() {
	vec4 m = COLOR;
	float mot = texture(mottle, UV * 3.0).r;
	vec3 base = tone * mix(0.92, 1.06, mot);
	// Subtle redness in thin-skinned areas: lips, socket rims.
	vec3 c = mix(base, base * lip_tint * 1.35, smoothstep(0.05, 0.7, m.r) * 0.85);
	c = mix(c, c * vec3(0.78, 0.68, 0.68), m.a * socket_shade);
	// Stubble: tiny dark dots in the beard zone.
	float dots = step(0.62, texture(mottle, UV * 140.0).r);
	c = mix(c, c * 0.55, m.b * stubble * (0.5 + 0.5 * dots));
	// Eyebrows with a hair-like streak pattern.
	float streak = 0.6 + 0.4 * texture(mottle, vec2(UV.x * 220.0, UV.y * 30.0)).r;
	c = mix(c, brow_color, clamp(m.g * brow_strength * streak * 1.4, 0.0, 1.0));
	ALBEDO = c;
	ROUGHNESS = mix(0.52, 0.32, smoothstep(0.1, 0.6, m.r));
	SPECULAR = 0.4;
	NORMAL_MAP = texture(pores_normal, UV * pore_scale).rgb;
	NORMAL_MAP_DEPTH = pore_strength;
	SSS_STRENGTH = sss;
	BACKLIGHT = tone * 0.08;
}
