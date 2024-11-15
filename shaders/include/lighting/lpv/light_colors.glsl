#if !defined INCLUDE_LIGHTING_LPV_LIGHT_COLORS
#define INCLUDE_LIGHTING_LPV_LIGHT_COLORS

const vec3[81] light_color = vec3[81](
	vec3(1.00, 1.00, 1.00) * 12.0, // 26: Strong white light
	vec3(1.00, 1.00, 1.00) *  6.0, // 27: Medium white light
	vec3(1.00, 1.00, 1.00) *  1.0, // 28: Weak white light
	vec3(1.00, 0.55, 0.27) * 12.0, // 29: Strong golden light
	vec3(1.00, 0.57, 0.30) *  8.0, // 30: Medium golden light
	vec3(1.00, 0.57, 0.30) *  4.0, // 31: Weak golden light
	vec3(1.00, 0.18, 0.10) *  5.0, // 32: Redstone components
	vec3(1.00, 0.30, 0.10) * 24.0, // 33: Lava
	vec3(1.00, 0.45, 0.10) *  9.0, // 34: Medium orange light
	vec3(1.00, 0.63, 0.15) *  4.0, // 35: Brewing stand
	vec3(1.00, 0.57, 0.30) * 12.0, // 36: Medium golden light
	vec3(0.45, 0.73, 1.00) *  6.0, // 37: Soul lights
	vec3(0.45, 0.73, 1.00) * 14.0, // 38: Beacon
	vec3(0.75, 1.00, 0.83) *  3.0, // 39: Sculk
	vec3(0.75, 1.00, 0.83) *  1.0, // 40: End portal frame
	vec3(0.60, 0.10, 1.00) *  4.0, // 41: Pink glow
	vec3(0.75, 1.00, 0.50) *  1.0, // 42: Sea pickle
	vec3(1.00, 0.50, 0.25) *  4.0, // 43: Nether plants
	vec3(1.00, 0.57, 0.30) *  8.0, // 44: Medium golden light
	vec3(1.00, 0.65, 0.30) *  8.0, // 45: Ochre froglight
	vec3(0.86, 1.00, 0.44) *  8.0, // 46: Verdant froglight
	vec3(0.75, 0.44, 1.00) *  8.0, // 47: Pearlescent froglight
	vec3(0.60, 0.10, 1.00) *  2.0, // 48: Enchanting table
	vec3(0.75, 0.44, 1.00) *  4.0, // 49: Amethyst cluster
	vec3(0.75, 0.44, 1.00) *  4.0, // 50: Calibrated sculk sensor
	vec3(0.75, 1.00, 0.83) *  6.0, // 51: Active sculk sensor
	vec3(1.00, 0.18, 0.10) *  3.3, // 52: Redstone block

  // Plants
	vec3(0.90, 0.30, 1.00) *  9.0, // 53: Magenta plants
	vec3(0.49, 1.00, 0.85) *  9.0, // 54: Cyan plants
	vec3(0.10, 1.00, 1.00) *  9.0, // 55: Blue plants
	vec3(1.00, 0.40, 0.10) *  9.0, // 56: Red orange plants
	vec3(1.00, 0.10, 0.50) *  9.0, // 57: Purple plants
	vec3(1.00, 0.10, 0.10) *  9.0, // 58: Unused
	vec3(0.00, 0.00, 0.00), // 59: Unused
	vec3(0.00, 0.00, 0.00), // 60: Unused
	vec3(0.00, 0.00, 0.00), // 61: Unused
	vec3(0.00, 0.00, 0.00), // 62: Unused
	vec3(0.00, 0.00, 0.00), // 63: Unused
	vec3(0.00, 0.00, 0.00), // 64: Unused 
	vec3(0.00, 0.00, 0.00), // 65: Unused
	vec3(0.00, 0.00, 0.00), // 66: Unused
	vec3(0.00, 0.00, 0.00), // 67: Unused
	vec3(0.00, 0.00, 0.00), // 68: Unused
	vec3(0.00, 0.00, 0.00), // 69: Unused
	vec3(0.00, 0.00, 0.00), // 70: Unused
	vec3(0.00, 0.00, 0.00), // 71: Unused
	vec3(0.00, 0.00, 0.00), // 72: Unused
	vec3(0.00, 0.00, 0.00), // 73: Unused
	vec3(0.00, 0.00, 0.00), // 74: Unused
	vec3(0.00, 0.00, 0.00), // 75: Unused
	vec3(0.00, 0.00, 0.00), // 76: Unused
	vec3(0.00, 0.00, 0.00), // 77: Unused
	vec3(0.00, 0.00, 0.00), // 78: Unused
	vec3(0.00, 0.00, 0.00), // 79: Unused
	vec3(0.00, 0.00, 0.00), // 80: Unused
	vec3(0.00, 0.00, 0.00), // 81: Unused
	vec3(0.00, 0.00, 0.00), // 82: Unused
	vec3(0.00, 0.00, 0.00), // 83: Unused
	vec3(0.00, 0.00, 0.00), // 84: Unused
	vec3(0.00, 0.00, 0.00), // 85: Unused
	vec3(0.00, 0.00, 0.00), // 86: Unused
	vec3(0.00, 0.00, 0.00), // 87: Unused
	vec3(0.00, 0.00, 0.00), // 88: Unused
	vec3(0.10, 1.00, 0.80) * 4.0, // 89: Unused
	vec3(0.00, 0.00, 0.00), // 90: End portal
  vec3(1.00, 0.10, 0.10) * 12.0, // 91: Red portal
  vec3(1.00, 0.50, 0.10) * 12.0, // 92: Orange portal
  vec3(1.00, 1.00, 0.10) * 12.0, // 93: Yellow portal
  vec3(0.70, 0.70, 0.00) * 12.0, // 94: Brown portal
  vec3(0.10, 1.00, 0.10) * 12.0, // 95: Green portal
  vec3(0.50, 1.00, 0.50) * 12.0, // 96: Lime portal
  vec3(0.10, 0.10, 1.00) * 12.0, // 97: Blue portal
  vec3(0.50, 0.50, 1.00) * 12.0, // 98: Light blue portal
  vec3(0.10, 1.00, 1.00) * 12.0, // 99: Cyan portal
  vec3(0.70, 0.10, 1.00) * 12.0, // 100: Purple portal
  vec3(1.00, 0.10, 1.00) * 12.0, // 101: Magenta portal
  vec3(1.00, 0.50, 1.00) * 12.0, // 102: Pink portal
  vec3(0.10, 0.10, 0.10) * 12.0, // 103: Black portal
  vec3(0.90, 0.90, 0.90) * 12.0, // 104: White portal
  vec3(0.30, 0.30, 0.30) * 12.0, // 105: Gray portal
  vec3(0.70, 0.70, 0.70) * 12.0  // 106: Light gray portal
);

const vec3[16] tint_color = vec3[16](
	vec3(1.0, 0.1, 0.1), // Red
	vec3(1.0, 0.5, 0.1), // Orange
	vec3(1.0, 1.0, 0.1), // Yellow
	vec3(0.7, 0.7, 0.0), // Brown
	vec3(0.1, 1.0, 0.1), // Green
	vec3(0.5, 1.0, 0.5), // Lime
	vec3(0.1, 0.1, 1.0), // Blue
	vec3(0.5, 0.5, 1.0), // Light blue
	vec3(0.1, 1.0, 1.0), // Cyan
	vec3(0.7, 0.1, 1.0), // Purple
	vec3(1.0, 0.1, 1.0), // Magenta
	vec3(1.0, 0.5, 1.0), // Pink
	vec3(0.1, 0.1, 0.1), // Black
	vec3(0.9, 0.9, 0.9), // White
	vec3(0.3, 0.3, 0.3), // Gray
	vec3(0.7, 0.7, 0.7)  // Light gray
);

#endif // INCLUDE_LIGHTING_LPV_LIGHT_COLORS
