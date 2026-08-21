extends RefCounted
class_name RoomObjectCatalog

# Catálogo de objetos que se pueden colocar en una sala. Vive aparte de
# room.gd porque es puro dato (mismo patrón que RoomStyles y ShopCatalog):
# room.gd solo sabe instanciar un WorldObject y pedirle a este diccionario
# qué textura/escala usar según el "kind" que trae la fila de la base de
# datos (ver sql/room_objects.sql).
const OBJETOS := {
	"pc": {
		"textura": preload("res://objetos/Desktop.png"),
		"escala": Vector2(0.3, 0.3),
		# Nombre de nodo que espera movement_script.gd para reconocer el
		# objeto como interactivo (ver conectar_objeto() ahi). Un "kind" sin
		# esta entrada es puramente decorativo: se ve y choca, pero no hace
		# nada al tocarlo.
		"nombre_nodo": "SearchWork",
		# Forma calcada del escritorio (ajustada a mano en el editor sobre
		# world_object.tscn y llevada a numeros limpios). Pisa el rectangulo
		# comun para este kind en particular.
		"poligono_colision": [
			Vector2(-137, 88), Vector2(-60, 129), Vector2(124, 38),
			Vector2(127, -69), Vector2(36, -116), Vector2(-149, -20),
			Vector2(-149, 75),
		],
	},
	"car": {
		"textura": preload("res://objetos/a3.png"),
		"escala": Vector2(0.5, 0.5),
		# Nombre reservado: aca es donde movement_script.gd conecta el
		# minijuego de completar el trabajo.
		"nombre_nodo": "WorkZone",
	},
	"trash": {
		"textura": preload("res://objetos/trash2.png"),
		"escala": Vector2(0.3, 0.3),
		# Sin nombre_nodo: decorativo, nunca tuvo comportamiento propio.
	},
	"estante_aceite": {
		"textura": preload("res://objetos/aceites1.png"),
		"escala": Vector2(0.3, 0.3),
		# Al interactuar con la mano vacia, da esta pieza gratis (ya se pago
		# al comprar el estante en la tienda). No usa nombre_nodo porque
		# puede haber mas de uno por sala (a diferencia de la PC/el auto) y
		# los nombres de nodo tienen que ser unicos entre hermanos.
		"pieza_gratis": "oils",
	},
}

# Tamaño de colisión física (el "pie" que bloquea a Barry): el mismo para
# todos los objetos, 1 baldosa (128x64), para no tener que ajustar cada
# figura por separado. Si mas adelante hace falta que alguno sea distinto,
# se le agrega "tamano_colision" a su entrada en OBJETOS y tamano_colision()
# de mas abajo lo respeta en vez de este valor comun.
const TAMANO_COLISION_COMUN := Vector2(1, 1)

# Inclinacion comun de esa caja, en grados: acomoda el rectangulo al angulo
# de las baldosas isometricas (atan(TILE_H/TILE_W), la pendiente del borde
# de un rombo del piso) en vez de dejarlo derecho. No calza pixel-perfecto
# con el rombo (un rectangulo rotado nunca deja de tener 90° en las
# esquinas), pero queda bastante mejor alineado a ojo que sin rotar.
const ROTACION_COLISION_COMUN := -26.57

static func textura(kind: String) -> Texture2D:
	return OBJETOS.get(kind, {}).get("textura")

static func escala(kind: String) -> Vector2:
	return OBJETOS.get(kind, {}).get("escala", Vector2(0.35, 0.35))

static func nombre_nodo(kind: String) -> String:
	return OBJETOS.get(kind, {}).get("nombre_nodo", "")

static func pieza_gratis(kind: String) -> String:
	return OBJETOS.get(kind, {}).get("pieza_gratis", "")

# Si el "kind" trae "tamano_colision" explicito (numero de pixeles ajustado
# a ojo en el editor) se usa ese tal cual. Si no, todos comparten
# TAMANO_COLISION_COMUN traducido a pixeles (multiplicado por
# RoomStyles.TILE_W/TILE_H), asi mide lo mismo en cualquier sala.
static func tamano_colision(kind: String) -> Vector2:
	var datos: Dictionary = OBJETOS.get(kind, {})
	if datos.has("tamano_colision"):
		return datos["tamano_colision"]
	return Vector2(TAMANO_COLISION_COMUN.x * RoomStyles.TILE_W, TAMANO_COLISION_COMUN.y * RoomStyles.TILE_H)

# Mismo patron que tamano_colision(): comun para todos salvo que el "kind"
# traiga su propio "rotacion_colision".
static func rotacion_colision(kind: String) -> float:
	return OBJETOS.get(kind, {}).get("rotacion_colision", ROTACION_COLISION_COMUN)

# Vacio para casi todos (usan el rectangulo comun). Si el "kind" trae
# "poligono_colision", ese pisa por completo al rectangulo — ver
# world_object.gd _aplicar_forma_colision().
static func poligono_colision(kind: String) -> PackedVector2Array:
	var puntos: Array = OBJETOS.get(kind, {}).get("poligono_colision", [])
	return PackedVector2Array(puntos)
