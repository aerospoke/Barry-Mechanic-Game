shader_type canvas_item;

// Recolorea la ropa de Barry: los pixeles del azul del overol y la gorra
// (tono 0.53-0.64, bien saturados) pasan al color del traje conservando su
// luz y sombra. La piel, la barba, las botas y el contorno no se tocan.
// Ver scripts/vestuario.gd.

uniform vec4 color_traje : source_color = vec4(0.8, 0.16, 0.14, 1.0);
// Brillo de referencia del azul original: lo mas claro de la tela.
uniform float brillo_base = 0.58;

vec3 a_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec3 hsv = a_hsv(col.rgb);
	bool es_tela = hsv.x > 0.53 && hsv.x < 0.64 && hsv.y > 0.40 && hsv.z > 0.2;
	if (es_tela) {
		// Misma luz relativa que tenia el azul, aplicada al color nuevo.
		float luz = hsv.z / brillo_base;
		col.rgb = clamp(color_traje.rgb * luz, 0.0, 1.0);
	}
	COLOR = col;
}
