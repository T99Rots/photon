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
    case 0u: // Default
      #ifdef HARDCODED_SPECULAR
      {
        float smoothness = 0.33 * smoothstep(0.2, 0.6, hsl.z);
        material.roughness = sqr(1.0 - smoothness);
        material.f0 = vec3(0.02);
      }
      #endif
      break;
    case 2u: // Small plants
      #ifdef HARDCODED_SSS
      {
        material.sss_amount = 0.5;
        material.sheen_amount = 1.0;
      }
      #endif
      break;
    case 3u: // Tall plants (lower half)
      #ifdef HARDCODED_SSS
      {
        material.sss_amount = 0.5;
        material.sheen_amount = 1.0;
      }
      #endif
      break;
    case 4u: // Tall plants (upper half)
      #ifdef HARDCODED_SSS
      {
        material.sss_amount = 0.5;
        material.sheen_amount = 1.0;
      }
      #endif
      break;
    case 5u: // Leaves
      #ifdef HARDCODED_SPECULAR
      {
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
    case 6: // Sand
      #ifdef HARDCODED_SPECULAR
      {
        float smoothness = 0.8 * linear_step(0.81, 0.96, hsl.z);
        material.roughness = sqr(1.0 - smoothness);
        material.f0 = vec3(0.02);
      }
      #endif
      break;
    case 7: // Ice
      #ifdef HARDCODED_SPECULAR
      {
        float smoothness = pow4(linear_step(0.4, 0.8, hsl.z)) * 0.6;
        material.roughness = sqr(1.0 - smoothness);
        material.f0 = vec3(0.02);
        material.ssr_multiplier = 1.0;
      }
      #endif // Strong SSS
      #ifdef HARDCODED_SSS
      {
        material.sss_amount = 0.75;
      }
      #endif
      break;
    case 8: // Red sand, birch planks
      #ifdef HARDCODED_SPECULAR
      {
        float smoothness = 0.4 * linear_step(0.61, 0.85, hsl.z);
        material.roughness = sqr(1.0 - smoothness);
        material.f0 = vec3(0.02);
      }
      #endif
      break;
    case 9u: // Oak, jungle and acacia planks, granite and diorite
      #ifdef HARDCODED_SPECULAR
      {
        float smoothness = 0.5 * linear_step(0.4, 0.8, hsl.z);
        material.roughness = sqr(1.0 - smoothness);
        material.f0 = vec3(0.02);
      }
      #endif
      break;
    case 10u: // Obsidian, nether bricks
      #ifdef HARDCODED_SPECULAR
      {
        float smoothness = linear_step(0.02, 0.4, hsl.z);
        material.roughness = sqr(1.0 - smoothness);
        material.f0 = vec3(0.02);
        material.ssr_multiplier = 1.0;
      }
      #endif
      break;
    case 11u: // Metals
      #ifdef HARDCODED_SPECULAR
      {
        float smoothness = sqrt(linear_step(0.1, 0.9, hsl.z));
        material.roughness = max(sqr(1.0 - smoothness), 0.04);
        material.f0 = material.albedo;
        material.is_metal = true;
        material.ssr_multiplier = 1.0;
      }
      #endif
      break;
    case 12u: // Gems
      #ifdef HARDCODED_SPECULAR
      {
        float smoothness = sqrt(linear_step(0.1, 0.9, hsl.z));
        material.roughness = max(sqr(1.0 - smoothness), 0.04);
        material.f0 = vec3(0.25);
        material.ssr_multiplier = 1.0;
      }
      #endif
      break;
    case 13u: // Strong SSS
      #ifdef HARDCODED_SSS
      {
        material.sss_amount = 0.6;
      }
      #endif
      break;
    case 14u: // Weak SSS
      #ifdef HARDCODED_SSS
      {
        material.sss_amount = 0.1;
      }
      #endif
      break;
    case 15u: // Chorus plant
      #ifdef HARDCODED_EMISSION
      {
        material.emission  = 0.25 * albedo_sqrt * pow4(hsl.z);
      }
      #endif
      break;
    case 16u: // End stone
      #ifdef HARDCODED_SPECULAR
      {
        float smoothness = 0.4 * linear_step(0.61, 0.85, hsl.z);
        material.roughness = sqr(1.0 - smoothness);
        material.f0 = vec3(0.02);
        material.ssr_multiplier = 1.0;
      }
      #endif
      break;
    case 17u: // Metals
      #ifdef HARDCODED_SPECULAR
      {
        float smoothness = sqrt(linear_step(0.1, 0.9, hsl.z));
        material.roughness = max(sqr(1.0 - smoothness), 0.04);
        material.f0 = material.albedo;
        material.is_metal = true;
        material.ssr_multiplier = 1.0;
      }
      #endif
      break;
    case 18u: // Warped stem
      #ifdef HARDCODED_EMISSION
      {
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
    case 19u: // Warped stem
      #ifdef HARDCODED_EMISSION
      {
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
    case 20u: // Warped stem
      #ifdef HARDCODED_EMISSION
      {
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
    case 21u: // Warped hyphae
      #ifdef HARDCODED_EMISSION
      {
        float blue = isolate_hue(hsl, 200.0, 60.0);
        material.emission = albedo_sqrt * hsl.y * blue;
      }
      #endif
      break;
    case 22u: // Crimson stem
      #ifdef HARDCODED_EMISSION
      {
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
    case 23u: // Crimson stem
      #ifdef HARDCODED_EMISSION
      {
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
    case 24u: // Crimson stem
      #ifdef HARDCODED_EMISSION
      {
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
    case 25u: // Crimson hyphae
      #ifdef HARDCODED_EMISSION
      {
        material.emission = albedo_sqrt * linear_step(0.33, 0.5, hsl.z);
      }
      #endif
      break;
    case 26u: // Strong white light
      #ifdef HARDCODED_EMISSION
      {
        material.emission = 1.00 * albedo_sqrt * (0.1 + 0.9 * cube(hsl.z));
      }
      #endif
      break;
    case 27u: // Medium white light
      #ifdef HARDCODED_EMISSION
      {
        material.emission = 0.66 * albedo_sqrt * linear_step(0.75, 0.9, hsl.z);
      }
      #endif
      break;
    case 28u: // Weak white light
      #ifdef HARDCODED_EMISSION
      {
        material.emission = 0.2 * albedo_sqrt * (0.1 + 0.9 * pow4(hsl.z));
      }
      #endif
      break;
    case 29u: // Strong golden light
      #ifdef HARDCODED_EMISSION
      {
        material.emission  = 0.85 * albedo_sqrt * linear_step(0.4, 0.6, 0.2 * hsl.y + 0.55 * hsl.z);
        light_levels.x *= 0.85;
      }
      #endif
      break;
    case 30u: // Medium golden light
      #ifdef HARDCODED_EMISSION
      {
        material.emission  = 0.85 * albedo_sqrt * linear_step(0.78, 0.85, hsl.z);
        light_levels.x *= 0.85;
      }
      #endif
      break;
    case 31u: // Weak golden light
      #ifdef HARDCODED_EMISSION
      {
        float blue = isolate_hue(hsl, 200.0, 30.0);
        material.emission = 0.8 * albedo_sqrt * linear_step(0.47, 0.50, 0.2 * hsl.y + 0.5 * hsl.z + 0.1 * blue);
      }
      #endif
      break;
    case 32u: // Redstone components
      #ifdef HARDCODED_EMISSION
      {
        vec3 ap1 = material.albedo * rec2020_to_ap1_unlit;
        float l = 0.5 * (min_of(ap1) + max_of(ap1));
        float redness = ap1.r * rcp(ap1.g + ap1.b);
        material.emission = 0.33 * material.albedo * step(0.45, redness * l);
      }
      #endif
      break;
    case 33u: // Lava
      #ifdef HARDCODED_EMISSION
      {
        material.emission = 4.0 * albedo_sqrt * (0.2 + 0.8 * isolate_hue(hsl, 30.0, 15.0)) * step(0.4, hsl.y);
      }
      #endif
      break;
    case 34u: // Medium orange emissives
      #ifdef HARDCODED_EMISSION
      {
        material.emission = 0.60 * albedo_sqrt * (0.1 + 0.9 * cube(hsl.z));
      }
      #endif
      break;
    case 35u: // Brewing stand
      #ifdef HARDCODED_EMISSION
      {
        material.emission  = 0.85 * albedo_sqrt * linear_step(0.77, 0.85, hsl.z);
      }
      #endif
      break;
    case 36u: // Jack o' Lantern
      #ifdef HARDCODED_EMISSION
      {
        material.emission = 0.80 * albedo_sqrt * step(0.73, 0.8 * hsl.z);
        light_levels.x *= 0.85;
      }
      #endif
      break;
    case 37u: // Soul lights
      #ifdef HARDCODED_EMISSION
      {
        float blue = isolate_hue(hsl, 200.0, 30.0);
        material.emission = 0.66 * albedo_sqrt * linear_step(0.8, 1.0, blue + hsl.z);
      }
      #endif
      break;
    case 38u: // Beacon
      #ifdef HARDCODED_EMISSION
      {
        material.emission = step(0.2, hsl.z) * albedo_sqrt * step(max_of(abs(block_pos - 0.5)), 0.4);
      }
      #endif
      break;
    case 39u: // End portal frame
      #ifdef HARDCODED_EMISSION
      {
        material.emission = 0.33 * material.albedo * isolate_hue(hsl, 120.0, 50.0);
      }
      #endif
      break;
    case 40u: // Sculk
      #ifdef HARDCODED_EMISSION
      {
        material.emission = 0.2 * material.albedo * isolate_hue(hsl, 200.0, 40.0) * smoothstep(0.5, 0.7, hsl.z) * (1.0 - linear_step(0.0, 20.0, distance(world_pos, cameraPosition)));
      }
      #endif
      break;
    case 41u: // Pink glow
      #ifdef HARDCODED_EMISSION
      {
        material.emission = vec3(0.75) * isolate_hue(hsl, 310.0, 50.0);
      }
      #endif
      break;
    case 42u:
      {
        material.emission = 0.5 * albedo_sqrt * linear_step(0.5, 0.6, hsl.z);
      }
      break;
    case 43u: // Nether mushrooms
      #ifdef HARDCODED_EMISSION
      {
        material.emission = 0.80 * albedo_sqrt * step(0.73, 0.1 * hsl.y + 0.7 * hsl.z);
      }
      #endif
      break;
    case 44u: // Candles
      #ifdef HARDCODED_EMISSION
      {
        material.emission = vec3(0.2) * pow4(clamp01(block_pos.y * 2.0));
      }
      #endif
      break;
    case 45u: // Ochre froglight
      #ifdef HARDCODED_EMISSION
      {
        material.emission = 0.40 * albedo_sqrt * (0.1 + 0.9 * cube(hsl.z));
      }
      #endif
      break;
    case 46u: // Verdant froglight
      #ifdef HARDCODED_EMISSION
      {
        material.emission = 0.40 * albedo_sqrt * (0.1 + 0.9 * cube(hsl.z));
      }
      #endif
      break;
    case 47u: // Pearlescent froglight
      #ifdef HARDCODED_EMISSION
      {
        material.emission = 0.40 * albedo_sqrt * (0.1 + 0.9 * cube(hsl.z));
      }
      #endif
      break;
    case 48u: // Echantment table
      break;
    case 49u: // Amethyst cluster
      #ifdef HARDCODED_EMISSION
      {
        material.emission = vec3(0.20) * (0.1 + 0.9 * hsl.z);
      }
      #endif
      break;
    case 50u: // Calibrated sculk sensor
      #ifdef HARDCODED_EMISSION
      {
        material.emission  = 0.2 * material.albedo * isolate_hue(hsl, 200.0, 40.0) * smoothstep(0.5, 0.7, hsl.z) * (1.0 - linear_step(0.0, 20.0, distance(world_pos, cameraPosition)));
        material.emission += vec3(0.20) * (0.1 + 0.9 * hsl.z) * step(0.5, isolate_hue(hsl, 270.0, 50.0) + 0.55 * hsl.z);
      }
      #endif
      break;
    case 51u: // Active sculk sensor
      #ifdef HARDCODED_EMISSION
      {
        material.emission = vec3(0.20) * (0.1 + 0.9 * hsl.z);
      }
      #endif
      break;
    case 52u: // Redstone block
      #ifdef HARDCODED_EMISSION
      {
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
        material.emission = vec3(1.0);
      }

    // Stained glass, honey and slime
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
