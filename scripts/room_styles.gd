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
		"nombre": "Taller Basico",
		"descripcion": "El lugar ideal para empezar. 20x20 baldosas.",
		"ancho": 20,
		"alto": 20,
		"suelo_a": Color(0.85, 0.80, 0.70),
		"suelo_b": Color(0.76, 0.71, 0.61),
		"pared_izq": Color(0.62, 0.66, 0.75),
		"pared_der": Color(0.72, 0.76, 0.85),
		"borde": Color(0.35, 0.33, 0.30, 0.35),
		"fondo": Color(0.00, 0.00, 0.00),
		"alto_pared": 240,

	},
	"loft": {
		"nombre": "Taller Avanzado",
		"descripcion": "El siguiente nivel, para nuevas experiencias y mas capacidad de trabajo 40x40 baldosa.",
		"ancho": 30,
		"alto": 30,
		"suelo_a": Color(0.85, 0.80, 0.70),
		"suelo_b": Color(0.76, 0.71, 0.61),
		"pared_izq": Color(0.62, 0.66, 0.75),
		"pared_der": Color(0.72, 0.76, 0.85),
		"borde": Color(0.35, 0.33, 0.30, 0.35),
		"fondo": Color(0.00, 0.00, 0.00),
		"alto_pared": 240,
	},
	"terraza": {
		"nombre": "Terraza",
		"descripcion": "Suelo de cesped y muros bajos, al aire libre.  ideal para exponer tus proyectos al publico 60x60. baldosas",
		"ancho": 40,
		"alto": 40,
		"suelo_a": Color(0.40, 0.66, 0.35),
		"suelo_b": Color(0.34, 0.58, 0.30),
		"pared_izq": Color(0.55, 0.45, 0.35),
		"pared_der": Color(0.65, 0.54, 0.42),
		"borde": Color(0.20, 0.30, 0.18, 0.35),
		"fondo": Color(0.35, 0.62, 0.82),
		"alto_pared": 20,
	},
	"taller": {
		"nombre": "Taller Mecanico",
		"descripcion": "Piso de cemento y paredes altas, como un taller de verdad. 55x55.",
		"ancho": 50,
		"alto": 30,
		"suelo_a": Color(0.85, 0.80, 0.70),
		"suelo_b": Color(0.76, 0.71, 0.61),
		"pared_izq": Color(0.62, 0.66, 0.75),
		"pared_der": Color(0.72, 0.76, 0.85),
		"borde": Color(0.35, 0.33, 0.30, 0.35),
		"fondo": Color(0.00, 0.00, 0.00),
		"alto_pared": 240,
	},
}

# Orden fijo de las opciones en el menú: los diccionarios de GDScript conservan
# el orden de inserción, pero depender de eso para la UI es frágil.
const ORDEN := ["basica", "loft", "terraza", "taller"]

const ALTO_PARED_POR_DEFECTO := 140

static func get_estilo(id: String) -> Dictionary:
	return ESTILOS.get(id, ESTILOS["basica"])

static func alto_pared(estilo: Dictionary) -> int:
	return int(estilo.get("alto_pared", ALTO_PARED_POR_DEFECTO))
