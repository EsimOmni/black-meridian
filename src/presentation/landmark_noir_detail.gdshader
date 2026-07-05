shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// P12b noir trim-detail — a triplanar (UV-free) weathering material that REPLACES a hero
// landmark's baked stone/metal slot (its base color/roughness/metallic passed in as uniforms
// from the GLB material). It does not recolor the base tone; it breaks the flat surface the
// way the master's aged stone + oxidized metal reads:
//   - stone grain -> roughness break-up (dull vs slick patches catch the wet key light)
//   - vertical oxidation streaks running DOWN the faces (rain-run staining)
//   - a wet band low on the building (water-line darkening, brighter spec) rising into dry
// Triplanar/world-space so nothing stretches on the smart-projected UVs. Emissive slots keep
// their own baked material (this shader is never applied to the glow).

uniform vec3 base_color : source_color = vec3(0.74, 0.72, 0.66);
uniform float base_roughness : hint_range(0.0, 1.0) = 0.8;
uniform float base_metallic : hint_range(0.0, 1.0) = 0.0;

uniform vec3 stain_color : source_color = vec3(0.06, 0.09, 0.07);  // cold verdigris/algae stain
uniform float stain_amount : hint_range(0.0, 1.0) = 0.6;
uniform float grain_scale = 3.0;      // stone-grain frequency (world meters)
uniform float streak_scale = 1.6;     // horizontal spacing of the vertical runs (higher = more, thinner runs)
uniform float wet_line_m = 7.0;       // height (m) up to which the wet/darker band reaches
uniform float wet_strength : hint_range(0.0, 1.0) = 0.6;
uniform float rough_break : hint_range(0.0, 1.0) = 0.35;

// cheap value-noise (no texture) ------------------------------------------------
float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0,0,0)), hash(i + vec3(1,0,0)), f.x),
			mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
			mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 w = v_world;

	// stone grain: 3D value noise -> roughness break-up
	float grain = vnoise(w * grain_scale);

	// vertical oxidation streaks: noise varies fast across x/z (which run) but is stretched
	// LONG in y (0.03) so each run is a continuous top-to-bottom rain-stain line, not a blob.
	float streak = vnoise(vec3(w.x * streak_scale, w.y * 0.03, w.z * streak_scale));
	streak = smoothstep(0.5, 0.85, streak);   // distinct runs
	// runs fade in from the top and are strongest lower down (rain runs downward)
	streak *= smoothstep(0.0, wet_line_m * 1.6, wet_line_m * 1.6 - min(w.y, wet_line_m * 1.6)) * 0.5 + 0.5;

	// wet band low on the building: darker + slicker near the base, drying with height
	float wet = 1.0 - smoothstep(0.0, wet_line_m, w.y);

	// albedo: base tone stained toward the cold stain color in streaks + the wet band
	float stain_mask = clamp(streak * stain_amount + wet * wet_strength * 0.7, 0.0, 1.0);
	ALBEDO = mix(base_color, stain_color, stain_mask);

	// roughness: grain dulls dry patches, the wet band slicks (catches the key as wet sheen)
	float r = base_roughness;
	r = mix(r, 1.0, grain * rough_break);
	r = mix(r, 0.12, wet * wet_strength);
	ROUGHNESS = clamp(r, 0.05, 1.0);

	// a hint of metallic in the wet band so the reflection reads (rain-lacquered stone)
	METALLIC = clamp(base_metallic + wet * wet_strength * 0.3, 0.0, 1.0);
}
