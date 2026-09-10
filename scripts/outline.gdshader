shader_type canvas_item;

// Contorno para marcar el objeto seleccionado en el modo de edicion de sala
// (ver WorldObject.set_seleccionado en scripts/world_object.gd). "activo" en
// vez de aplicar/quitar el material a mano: asi se puede animar con un tween
// (ver _pulso_seleccion) sin tocar el material desde fuera.
uniform vec4 color_contorno : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// En texeles de la textura fuente, no en pixeles de pantalla: un objeto
// escalado chico (ver escala_sprite en WorldObject) necesita mas texeles
// para el mismo grosor visible. world_object.gd calcula este valor segun la
// escala de cada instancia, ver _grosor_contorno().
uniform float ancho : hint_range(1.0, 14.0) = 3.0;
uniform float activo : hint_range(0.0, 1.0) = 0.0;

// Tope fijo de iteraciones (los shaders no aceptan un limite de loop
// variable): con ancho por encima de esto simplemente no suma grosor extra.
const int ANCHO_MAX = 14;

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	if (activo > 0.0 && col.a < 0.5) {
		float vecinos = 0.0;
		// Barre varios radios (no solo uno) para que el contorno sea una
		// franja de "ancho" texeles y no un anillo fino corrido hacia afuera.
		for (int i = 1; i <= ANCHO_MAX; i++) {
			if (float(i) > ancho) {
				break;
			}
			vec2 texel = TEXTURE_PIXEL_SIZE * float(i);
			vecinos +=
				texture(TEXTURE, UV + vec2(texel.x, 0.0)).a +
				texture(TEXTURE, UV + vec2(-texel.x, 0.0)).a +
				texture(TEXTURE, UV + vec2(0.0, texel.y)).a +
				texture(TEXTURE, UV + vec2(0.0, -texel.y)).a +
				texture(TEXTURE, UV + vec2(texel.x, texel.y)).a +
				texture(TEXTURE, UV + vec2(-texel.x, texel.y)).a +
				texture(TEXTURE, UV + vec2(texel.x, -texel.y)).a +
				texture(TEXTURE, UV + vec2(-texel.x, -texel.y)).a;
		}
		col = mix(col, color_contorno, min(vecinos, 1.0) * activo);
	}

	COLOR = col;
}
