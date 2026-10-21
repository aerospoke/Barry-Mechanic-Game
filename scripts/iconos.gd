extends RefCounted
class_name Iconos

# Iconos simples dibujados por codigo (flechas, estrella) para botones. Se
# usan en vez de simbolos de texto como ◀ ▶ ★ o emojis: la fuente del juego
# no los trae, Android a veces los presta del sistema pero iOS no, y ahi
# quedaban botones vacios. Se generan una vez y se guardan.
#
#   boton.icon = Iconos.flecha("der")
#   boton.icon = Iconos.flecha("izq", true)   # doble (◀◀)

static var _cache: Dictionary = {}

# direccion: "izq", "der", "arriba", "abajo". doble = dos flechas seguidas.
static func flecha(direccion: String, doble: bool = false, lado: int = 32, color: Color = Color.WHITE) -> Texture2D:
	var clave := "flecha_%s_%s_%d_%s" % [direccion, doble, lado, color.to_html()]
	if _cache.has(clave):
		return _cache[clave]

	var ancho := lado * 2 if doble else lado
	var imagen := Image.create(ancho, lado, false, Image.FORMAT_RGBA8)
	var copias := 2 if doble else 1
	for copia in copias:
		var x0 := copia * lado * 0.62
		for y in lado:
			for x in lado:
				# Triangulo apuntando a la derecha en coordenadas 0..1, girado
				# segun la direccion pedida.
				var u := (x + 0.5) / lado
				var v := (y + 0.5) / lado
				match direccion:
					"izq":
						u = 1.0 - u
					"arriba":
						var t := u
						u = 1.0 - v
						v = t
					"abajo":
						var t := u
						u = v
						v = t
				var margen := 0.18
				var dentro := u >= margen and u <= 1.0 - margen and absf(v - 0.5) <= (1.0 - margen - u) * 0.62
				var px := int(x + x0)
				if dentro and px < ancho:
					imagen.set_pixel(px, y, color)
	var textura := ImageTexture.create_from_image(imagen)
	_cache[clave] = textura
	return textura

static func estrella(lado: int = 28, color: Color = Color(1.0, 0.82, 0.3)) -> Texture2D:
	var clave := "estrella_%d_%s" % [lado, color.to_html()]
	if _cache.has(clave):
		return _cache[clave]
	var imagen := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	var puntos := PackedVector2Array()
	for k in 10:
		var radio := lado * (0.48 if k % 2 == 0 else 0.2)
		var angulo := -PI / 2.0 + k * PI / 5.0
		puntos.append(Vector2(lado / 2.0, lado / 2.0) + Vector2.from_angle(angulo) * radio)
	for y in lado:
		for x in lado:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), puntos):
				imagen.set_pixel(x, y, color)
	var textura := ImageTexture.create_from_image(imagen)
	_cache[clave] = textura
	return textura
