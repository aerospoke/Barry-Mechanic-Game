extends RefCounted
class_name RoomStyles

# Catálogo de salas que se pueden crear desde la PC. Vive aparte del menú y de
# la escena de la sala porque las dos necesitan los mismos datos: el menú para
# pintar las opciones y la sala para construir el suelo y las paredes.
#
# Las salas son isométricas (estilo Habbo) y se generan por código, así que un
# estilo es solo tamaño de rejilla + paleta: no hay tilemap que mantener.

# Tamaño de una baldosa, igual en toda sala sin importar el estilo — lo único
# que varía entre estilos es cuántas baldosas tiene la grilla (ancho/alto más
# abajo), nunca el tamaño de cada una. Vive acá (y no repetida en room.gd)
# para que room_object_catalog.gd pueda expresar el tamaño de un objeto en
# "cuantas baldosas ocupa" y que eso mida lo mismo en cualquier sala.
const TILE_W := 128.0
const TILE_H := 64.0

const ESTILOS := {
	"basica": {
		"nombre": "Sala Basica",
		"descripcion": "Un cuadrado amplio para empezar. 50x50 baldosas.",
		"ancho": 50,
		"alto": 50,
		"suelo_a": Color(0.85, 0.80, 0.70),
		"suelo_b": Color(0.76, 0.71, 0.61),
		"pared_izq": Color(0.62, 0.66, 0.75),
		"pared_der": Color(0.72, 0.76, 0.85),
		"borde": Color(0.35, 0.33, 0.30, 0.35),
		"fondo": Color(0.10, 0.11, 0.16),
	},
	"loft": {
		"nombre": "Loft Moderno",
		"descripcion": "Alargado y oscuro, con paredes altas. 80x40 baldosas.",
		"ancho": 80,
		"alto": 40,
		"suelo_a": Color(0.30, 0.32, 0.38),
		"suelo_b": Color(0.24, 0.26, 0.32),
		"pared_izq": Color(0.16, 0.17, 0.22),
		"pared_der": Color(0.21, 0.23, 0.29),
		"borde": Color(0.10, 0.10, 0.14, 0.5),
		"fondo": Color(0.06, 0.06, 0.09),
		"alto_pared": 190,
	},
	"terraza": {
		"nombre": "Terraza",
		"descripcion": "Suelo de cesped y muros bajos, al aire libre. 60x60.",
		"ancho": 60,
		"alto": 60,
		"suelo_a": Color(0.40, 0.66, 0.35),
		"suelo_b": Color(0.34, 0.58, 0.30),
		"pared_izq": Color(0.55, 0.45, 0.35),
		"pared_der": Color(0.65, 0.54, 0.42),
		"borde": Color(0.20, 0.30, 0.18, 0.35),
		"fondo": Color(0.35, 0.62, 0.82),
		"alto_pared": 80,
	},
}

# Orden fijo de las opciones en el menú: los diccionarios de GDScript conservan
# el orden de inserción, pero depender de eso para la UI es frágil.
const ORDEN := ["basica", "loft", "terraza"]

const ALTO_PARED_POR_DEFECTO := 140

static func get_estilo(id: String) -> Dictionary:
	return ESTILOS.get(id, ESTILOS["basica"])

static func alto_pared(estilo: Dictionary) -> int:
	return int(estilo.get("alto_pared", ALTO_PARED_POR_DEFECTO))
