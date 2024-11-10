#if !defined INCLUDE_MISC_MATERIAL
#define INCLUDE_MISC_MATERIAL

#include "/include/aces/matrices.glsl"
#include "/include/utility/color.glsl"

const float air_n   = 1.000293; // for 0°C and 1 atm
const float water_n = 1.333;    // for 20°C

struct Material {
	vec3 albedo;
	vec3 emission;
	vec3 f0;
	vec3 f82; // hardcoded metals only
	float roughness;
	float sss_amount;
	float sheen_amount; // SSS "sheen" for tall grass
	float porosity;
	float ssr_multiplier;
	bool is_metal;
	bool is_hardcoded_metal;
};

const Material water_material = Material(vec3(0.0), vec3(0.0), vec3(0.02), vec3(0.0), 0.002, 1.0, 0.0, 0.0, 1.0, false, false);

#if TEXTURE_FORMAT == TEXTURE_FORMAT_LAB
void decode_specular_map(vec4 specular_map, inout Material material) {
	// f0 and f82 values for hardcoded metals from Jessie LC (https://github.com/Jessie-LC)
	const vec3[] metal_f0 = vec3[](
		vec3(0.78, 0.77, 0.74), // Iron
		vec3(1.00, 0.90, 0.61), // Gold
		vec3(1.00, 0.98, 1.00), // Aluminum
		vec3(0.77, 0.80, 0.79), // Chrome
		vec3(1.00, 0.89, 0.73), // Copper
		vec3(0.79, 0.87, 0.85), // Lead
		vec3(0.92, 0.90, 0.83), // Platinum
		vec3(1.00, 1.00, 0.91)  // Silver
	);
	const vec3[] metal_f82 = vec3[](
		vec3(0.74, 0.76, 0.76),
		vec3(1.00, 0.93, 0.73),
		vec3(0.96, 0.97, 0.98),
		vec3(0.74, 0.79, 0.78),
		vec3(1.00, 0.90, 0.80),
		vec3(0.83, 0.80, 0.83),
		vec3(0.89, 0.87, 0.81),
		vec3(1.00, 1.00, 0.95)
	);

	material.roughness = sqr(1.0 - specular_map.r);
	material.emission = max(material.emission, material.albedo * specular_map.a * float(specular_map.a != 1.0));

	if (specular_map.g < 229.5 / 255.0) {
		// Dielectrics
		material.f0 = max(material.f0, specular_map.g);

		float has_sss = step(64.5 / 255.0, specular_map.b);
		material.sss_amount = max(material.sss_amount, linear_step(64.0 / 255.0, 1.0, specular_map.b * has_sss));
		material.porosity = linear_step(0.0, 64.0 / 255.0, max0(specular_map.b - specular_map.b * has_sss));
	} else if (specular_map.g < 237.5 / 255.0) {
		// Hardcoded metals
		uint metal_id = clamp(uint(255.0 * specular_map.g) - 230u, 0u, 7u);

		material.f0 = metal_f0[metal_id];
		material.f82 = metal_f82[metal_id];
		material.is_metal = true;
		material.is_hardcoded_metal = true;
	} else {
		// Albedo metal
		material.f0 = material.albedo;
		material.is_metal = true;
	}

	material.ssr_multiplier = step(0.01, (material.f0.x - material.f0.x * material.roughness * SSR_ROUGHNESS_THRESHOLD)); // based on Kneemund's method
}
#elif TEXTURE_FORMAT == TEXTURE_FORMAT_OLD
void decode_specular_map(vec4 specular_map, inout Material material) {
	material.roughness = sqr(1.0 - specular_map.r);
	material.is_metal  = specular_map.g > 0.5;
	material.f0        = material.is_metal ? material.albedo : material.f0;
	material.emission  = max(material.emission, material.albedo * specular_map.b);

	material.ssr_multiplier = step(0.01, (material.f0.x - material.f0.x * material.roughness * SSR_ROUGHNESS_THRESHOLD)); // based on Kneemund's method
}
#endif

void decode_specular_map(vec4 specular_map, inout Material material, out bool parallax_shadow) {
#if defined POM && defined POM_SHADOW
		// Specular map alpha >= 0.5 => parallax shadow
		parallax_shadow = specular_map.a >= 0.5;
		specular_map.a = fract(specular_map.a * 2.0);
#endif

		decode_specular_map(specular_map, material);
}

Material material_from(vec3 albedo_srgb, uint material_mask, vec3 world_pos, vec3 normal, inout vec2 light_levels) {
	vec3 block_pos = fract(world_pos);

	// Create material with default values

	Material material;
	material.albedo             = srgb_eotf_inv(albedo_srgb) * rec709_to_rec2020;
	material.emission           = vec3(0.0);
	material.f0                 = vec3(0.02);
	material.f82                = vec3(0.0);
	material.roughness          = 1.0;
	material.sss_amount         = 0.0;
	material.sheen_amount       = 0.0;
	material.porosity           = 0.0;
	material.ssr_multiplier     = 0.0;
	material.is_metal           = false;
	material.is_hardcoded_metal = false;

	// Hardcoded materials for specific blocks
	// Using binary split search to minimise branches per fragment (TODO: measure impact)

	vec3 hsl = rgb_to_hsl(albedo_srgb);
	vec3 albedo_sqrt = sqrt(material.albedo);

  switch (material_mask) {
    case 0u:
      #ifdef HARDCODED_SPECULAR
      {
        // Default
        float smoothness = 0.33 * smoothstep(0.2, 0.6, hsl.z);
        material.roughness = sqr(1.0 - smoothness);
        material.f0 = vec3(0.02);
      }
      #endif
      break;
    case 2u:
      #ifdef HARDCODED_SSS
      {
        // Small plants
        material.sss_amount = 0.5;
        material.sheen_amount = 1.0;
      }
      #endif
      break;
    case 3u:
      #ifdef HARDCODED_SSS
      {
        // Tall plants (lower half)
        material.sss_amount = 0.5;
        material.sheen_amount = 1.0;
      }
      #endif
      break;
    case 4u:
      #ifdef HARDCODED_SSS
      {
        // Tall plants (upper half)
        material.sss_amount = 0.5;
        material.sheen_amount = 1.0;
      }
      #endif
      break;
    case 5u:
      #ifdef HARDCODED_SPECULAR
      {
        // Leaves
        float smoothness = 0.5 * smoothstep(0.16, 0.5, hsl.z);
        material.roughness = sqr(1.0 - smoothness);
        material.f0 = vec3(0.02);
        material.sheen_amount = 0.5;
      }
      #endif
      #ifdef HARDCODED_SSS
      {
        material.sss_amount = 1.0;
      }
      #endif
      break;
    case 7u:
      #ifdef HARDCODED_SPECULAR
      {
        // Sand
        float smoothness = 0.8 * linear_step(0.81, 0.96, hsl.z);
        material.roughness = sqr(1.0 - smoothness);
        material.f0 = vec3(0.02);
      }
      #endif
      break;
    case 8u:
      #ifdef HARDCODED_SPECULAR
      {
        // Ice
        float smoothness = pow4(linear_step(0.4, 0.8, hsl.z)) * 0.6;
        material.roughness = sqr(1.0 - smoothness);
        material.f0 = vec3(0.02);
        material.ssr_multiplier = 1.0;
      }
      #endif
      #ifdef HARDCODED_SSS
      {
        // Strong SSS
        material.sss_amount = 0.75;
      }
      #endif
      break;
    case 9u:
      #ifdef HARDCODED_SPECULAR
      {
        // Red sand, birch planks
        float smoothness = 0.4 * linear_step(0.61, 0.85, hsl.z);
        material.roughness = sqr(1.0 - smoothness);
        material.f0 = vec3(0.02);
      }
      #endif
      break;
    case 10u:
      #ifdef HARDCODED_SPECULAR
      {
        // Oak, jungle and acacia planks, granite and diorite
        float smoothness = 0.5 * linear_step(0.4, 0.8, hsl.z);
        material.roughness = sqr(1.0 - smoothness);
        material.f0 = vec3(0.02);
      }
      #endif
      break;
    case 11u:
      #ifdef HARDCODED_SPECULAR
      {
        // Obsidian, nether bricks
        float smoothness = linear_step(0.02, 0.4, hsl.z);
        material.roughness = sqr(1.0 - smoothness);
        material.f0 = vec3(0.02);
        material.ssr_multiplier = 1.0;
      }
      #endif
      break;
    case 12u:
      #ifdef HARDCODED_SPECULAR
      {
        // Metals
        float smoothness = sqrt(linear_step(0.1, 0.9, hsl.z));
        material.roughness = max(sqr(1.0 - smoothness), 0.04);
        material.f0 = material.albedo;
        material.is_metal = true;
        material.ssr_multiplier = 1.0;
      }
      #endif
      break;
    case 13u:
      #ifdef HARDCODED_SPECULAR
      {
        // Gems
        float smoothness = sqrt(linear_step(0.1, 0.9, hsl.z));
        material.roughness = max(sqr(1.0 - smoothness), 0.04);
        material.f0 = vec3(0.25);
        material.ssr_multiplier = 1.0;
      }
      #endif
      break;
    case 14u:
      #ifdef HARDCODED_SSS
      {
        // Strong SSS
        material.sss_amount = 0.6;
      }
      #endif
      break;
    case 15u:
      #ifdef HARDCODED_SSS
      {
        // Weak SSS
        material.sss_amount = 0.1;
      }
      #endif
      break;
    case 16u:
      #ifdef HARDCODED_EMISSION
      {
        // Chorus plant
        material.emission  = 0.25 * albedo_sqrt * pow4(hsl.z);
      }
      #endif
      break;
    case 17u:
      #ifdef HARDCODED_SPECULAR
      {
        // End stone
        float smoothness = 0.4 * linear_step(0.61, 0.85, hsl.z);
        material.roughness = sqr(1.0 - smoothness);
        material.f0 = vec3(0.02);
        material.ssr_multiplier = 1.0;
      }
      #endif
      break;
    case 18u:
      #ifdef HARDCODED_SPECULAR
      {
        // Metals
        float smoothness = sqrt(linear_step(0.1, 0.9, hsl.z));
        material.roughness = max(sqr(1.0 - smoothness), 0.04);
        material.f0 = material.albedo;
        material.is_metal = true;
        material.ssr_multiplier = 1.0;
      }
      #endif
      break;
    case 19u:
      #ifdef HARDCODED_EMISSION
      {
        // Warped stem
        float emission_amount = mix(
          1.0,
          float(any(lessThan(
            vec4(block_pos.yz, 1.0 - block_pos.yz),
            vec4(rcp(16.0) - 1e-3)
          ))),
          step(0.5, abs(normal.x))
        );
        float blue = isolate_hue(hsl, 200.0, 60.0);
        material.emission = albedo_sqrt * hsl.y * blue * emission_amount;
      }
      #endif
      break;
    case 20u:
      #ifdef HARDCODED_EMISSION
      {
        // Warped stem
        float emission_amount = mix(
          1.0,
          float(any(lessThan(
            vec4(block_pos.xz, 1.0 - block_pos.xz),
            vec4(rcp(16.0) - 1e-3)
          ))),
          step(0.5, abs(normal.y))
        );
        float blue = isolate_hue(hsl, 200.0, 60.0);
        material.emission = albedo_sqrt * hsl.y * blue * emission_amount;
      }
      #endif
      break;
    case 21u:
      #ifdef HARDCODED_EMISSION
      {
        // Warped stem
        float emission_amount = mix(
          1.0,
          float(any(lessThan(
            vec4(block_pos.xy, 1.0 - block_pos.xy),
            vec4(rcp(16.0) - 1e-3)
          ))),
          step(0.5, abs(normal.z))
        );
        float blue = isolate_hue(hsl, 200.0, 60.0);
        material.emission = albedo_sqrt * hsl.y * blue * emission_amount;
      }
      #endif
      break;
    case 22u:
      #ifdef HARDCODED_EMISSION
      {
        // Warped hyphae
        float blue = isolate_hue(hsl, 200.0, 60.0);
        material.emission = albedo_sqrt * hsl.y * blue;
      }
      #endif
      break;
    case 23u:
      #ifdef HARDCODED_EMISSION
      {
        // Crimson stem
        float emission_amount = mix(
          1.0,
          float(any(lessThan(
            vec4(block_pos.yz, 1.0 - block_pos.yz),
            vec4(rcp(16.0) - 1e-3)
          ))),
          step(0.5, abs(normal.x))
        );
        material.emission = albedo_sqrt * linear_step(0.33, 0.5, hsl.z) * emission_amount;
      }
      #endif
      break;
    case 24u:
      #ifdef HARDCODED_EMISSION
      {
        // Crimson stem
        float emission_amount = mix(
          1.0,
          float(any(lessThan(
            vec4(block_pos.xz, 1.0 - block_pos.xz),
            vec4(rcp(16.0) - 1e-3)
          ))),
          step(0.5, abs(normal.y))
        );
        material.emission = albedo_sqrt * linear_step(0.33, 0.5, hsl.z) * emission_amount;
      }
      #endif
      break;
    case 25u:
      #ifdef HARDCODED_EMISSION
      {
        // Crimson stem
        float emission_amount = mix(
          1.0,
          float(any(lessThan(
            vec4(block_pos.xy, 1.0 - block_pos.xy),
            vec4(rcp(16.0) - 1e-3)
          ))),
          step(0.5, abs(normal.z))
        );
        material.emission = albedo_sqrt * linear_step(0.33, 0.5, hsl.z) * emission_amount;
      }
      #endif
      break;
    case 26u:
      #ifdef HARDCODED_EMISSION
      {
        // Crimson hyphae
        material.emission = albedo_sqrt * linear_step(0.33, 0.5, hsl.z);
      }
      #endif
      break;
    case 32u:
      #ifdef HARDCODED_EMISSION
      {
        // Strong white light
        material.emission = 1.00 * albedo_sqrt * (0.1 + 0.9 * cube(hsl.z));
      }
      #endif
      break;
        case 33u:
      #ifdef HARDCODED_EMISSION
      {
        // Medium white light
        material.emission = 0.66 * albedo_sqrt * linear_step(0.75, 0.9, hsl.z);
      }
      #endif
      break;
    case 34u:
      #ifdef HARDCODED_EMISSION
      {
        // Weak white light
        material.emission = 0.2 * albedo_sqrt * (0.1 + 0.9 * pow4(hsl.z));
      }
      #endif
      break;
    case 35u:
      #ifdef HARDCODED_EMISSION
      {
        // Strong golden light
        material.emission  = 0.85 * albedo_sqrt * linear_step(0.4, 0.6, 0.2 * hsl.y + 0.55 * hsl.z);
        light_levels.x *= 0.85;
      }
      #endif
      break;
    case 36u:
      #ifdef HARDCODED_EMISSION
      {
        // Medium golden light
        material.emission  = 0.85 * albedo_sqrt * linear_step(0.78, 0.85, hsl.z);
        light_levels.x *= 0.85;
      }
      #endif
      break;
    case 37u:
      #ifdef HARDCODED_EMISSION
      {
        // Weak golden light
        float blue = isolate_hue(hsl, 200.0, 30.0);
        material.emission = 0.8 * albedo_sqrt * linear_step(0.47, 0.50, 0.2 * hsl.y + 0.5 * hsl.z + 0.1 * blue);
      }
      #endif
      break;
    case 38u:
      #ifdef HARDCODED_EMISSION
      {
        // Redstone components
        vec3 ap1 = material.albedo * rec2020_to_ap1_unlit;
        float l = 0.5 * (min_of(ap1) + max_of(ap1));
        float redness = ap1.r * rcp(ap1.g + ap1.b);
        material.emission = 0.33 * material.albedo * step(0.45, redness * l);
      }
      #endif
      break;
    case 39u:
      #ifdef HARDCODED_EMISSION
      {
        // Lava
        material.emission = 4.0 * albedo_sqrt * (0.2 + 0.8 * isolate_hue(hsl, 30.0, 15.0)) * step(0.4, hsl.y);
      }
      #endif
      break;
    case 40u:
      #ifdef HARDCODED_EMISSION
      {
        // Medium orange emissives
        material.emission = 0.60 * albedo_sqrt * (0.1 + 0.9 * cube(hsl.z));
      }
      #endif
      break;
    case 41u:
      #ifdef HARDCODED_EMISSION
      {
        // Brewing stand
        material.emission  = 0.85 * albedo_sqrt * linear_step(0.77, 0.85, hsl.z);
      }
      #endif
      break;
    case 42u:
      #ifdef HARDCODED_EMISSION
      {
        // Jack o' Lantern
        material.emission = 0.80 * albedo_sqrt * step(0.73, 0.8 * hsl.z);
        light_levels.x *= 0.85;
      }
      #endif
      break;
    case 43u:
      #ifdef HARDCODED_EMISSION
      {
        // Soul lights
        float blue = isolate_hue(hsl, 200.0, 30.0);
        material.emission = 0.66 * albedo_sqrt * linear_step(0.8, 1.0, blue + hsl.z);
      }
      #endif
      break;
    case 44u:
      #ifdef HARDCODED_EMISSION
      {
        // Beacon
        material.emission = step(0.2, hsl.z) * albedo_sqrt * step(max_of(abs(block_pos - 0.5)), 0.4);
      }
      #endif
      break;
    case 45u:
      #ifdef HARDCODED_EMISSION
      {
        // End portal frame
        material.emission = 0.33 * material.albedo * isolate_hue(hsl, 120.0, 50.0);
      }
      #endif
      break;
    case 46u:
      #ifdef HARDCODED_EMISSION
      {
        // Sculk
        material.emission = 0.2 * material.albedo * isolate_hue(hsl, 200.0, 40.0) * smoothstep(0.5, 0.7, hsl.z) * (1.0 - linear_step(0.0, 20.0, distance(world_pos, cameraPosition)));
      }
      #endif
      break;
    case 47u:
      #ifdef HARDCODED_EMISSION
      {
        // Pink glow
        material.emission = vec3(0.75) * isolate_hue(hsl, 310.0, 50.0);
      }
      #endif
      break;
    case 48u:
      {
        material.emission = 0.5 * albedo_sqrt * linear_step(0.5, 0.6, hsl.z);
      }
      break;
    case 49u:
      #ifdef HARDCODED_EMISSION
      {
        // Nether mushrooms
        material.emission = 0.80 * albedo_sqrt * step(0.73, 0.1 * hsl.y + 0.7 * hsl.z);
      }
      #endif
      break;
    case 50u:
      #ifdef HARDCODED_EMISSION
      {
        // Candles
        material.emission = vec3(0.2) * pow4(clamp01(block_pos.y * 2.0));
      }
      #endif
      break;
    case 51u:
      #ifdef HARDCODED_EMISSION
      {
        // Ochre froglight
        material.emission = 0.40 * albedo_sqrt * (0.1 + 0.9 * cube(hsl.z));
      }
      #endif
      break;
    case 52u:
      #ifdef HARDCODED_EMISSION
      {
        // Verdant froglight
        material.emission = 0.40 * albedo_sqrt * (0.1 + 0.9 * cube(hsl.z));
      }
      #endif
      break;
    case 53u:
      #ifdef HARDCODED_EMISSION
      {
        // Pearlescent froglight
        material.emission = 0.40 * albedo_sqrt * (0.1 + 0.9 * cube(hsl.z));
      }
      #endif
      break;
    case 54u:
      // No specific action
      break;
    case 55u:
      #ifdef HARDCODED_EMISSION
      {
        // Amethyst cluster
        material.emission = vec3(0.20) * (0.1 + 0.9 * hsl.z);
      }
      #endif
      break;
    case 56u:
      #ifdef HARDCODED_EMISSION
      {
        // Calibrated sculk sensor
        material.emission  = 0.2 * material.albedo * isolate_hue(hsl, 200.0, 40.0) * smoothstep(0.5, 0.7, hsl.z) * (1.0 - linear_step(0.0, 20.0, distance(world_pos, cameraPosition)));
        material.emission += vec3(0.20) * (0.1 + 0.9 * hsl.z) * step(0.5, isolate_hue(hsl, 270.0, 50.0) + 0.55 * hsl.z);
      }
      #endif
      break;
    case 57u:
      #ifdef HARDCODED_EMISSION
      {
        // Active sculk sensor
        material.emission = vec3(0.20) * (0.1 + 0.9 * hsl.z);
      }
      #endif
      break;
    case 58u:
      #ifdef HARDCODED_EMISSION
      {
        // Redstone block
        material.emission = 0.33 * albedo_sqrt;
      }
      #endif
      break;


    /// Portals (End, Nether, Custom).
    case 90u:
    case 91u:
    case 92u:
    case 93u:
    case 94u:
    case 95u:
    case 96u:
    case 97u:
    case 98u:
    case 99u:
    case 100u:
    case 101u:
    case 102u:
    case 103u:
    case 104u:
    case 105u:
    case 106u:
      {
        // Nether portal
        material.emission = vec3(1.0);
      }

    // Stained glass
    case 107u:
    case 108u:
    case 109u:
    case 110u:
    case 111u:
    case 112u:
    case 113u:
    case 114u:
    case 115u:
    case 116u:
    case 117u:
    case 118u:
    case 119u:
    case 120u:
    case 121u:
    case 122u:
      // Stained glass, honey and slime
      #ifdef HARDCODED_SPECULAR
      material.f0 = vec3(0.04);
      material.roughness = 0.1;
      material.ssr_multiplier = 1.0;
      #endif

      #ifdef HARDCODED_SSS
      material.sss_amount = 0.5;
      #endif
      break;
  }

	return material;
}

#endif // INCLUDE_MISC_MATERIAL
