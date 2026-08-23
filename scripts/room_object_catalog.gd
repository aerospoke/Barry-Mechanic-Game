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
		# world_object.tscn y llevada a numeros limpios). Pisa el rombo comun
		# para este kind en particular: la PC es mas ancha que una baldosa.
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

static func textura(kind: String) -> Texture2D:
	return OBJETOS.get(kind, {}).get("textura")

static func escala(kind: String) -> Vector2:
	return OBJETOS.get(kind, {}).get("escala", Vector2(0.35, 0.35))

static func nombre_nodo(kind: String) -> String:
	return OBJETOS.get(kind, {}).get("nombre_nodo", "")

static func pieza_gratis(kind: String) -> String:
	return OBJETOS.get(kind, {}).get("pieza_gratis", "")

# Forma de colision de cada "kind". Si trae "poligono_colision" a medida (ej.
# la PC, calcada de su sprite) se usa esa. Si no, el default ya NO es un
# rectangulo: es un rombo de 1 baldosa (ver _rombo_baldosa), la misma forma
# que las baldosas del piso — para que un objeto sin ajuste especial siga
# combinando con el estilo isometrico en vez de verse como una caja plana.
static func poligono_colision(kind: String) -> PackedVector2Array:
	var puntos: Array = OBJETOS.get(kind, {}).get("poligono_colision", [])
	if puntos.is_empty():
		return _rombo_baldosa()
	return PackedVector2Array(puntos)

# Rombo de 1 baldosa (128x64) centrado en el origen del objeto — mismos
# cuatro puntos que dibuja room.gd para el piso (_rombo()), pero sin
# desplazarlos a una esquina de la grilla.
static func _rombo_baldosa() -> PackedVector2Array:
	var medio_ancho := RoomStyles.TILE_W * 0.5
	var medio_alto := RoomStyles.TILE_H * 0.5
	return PackedVector2Array([
		Vector2(0, -medio_alto),
		Vector2(medio_ancho, 0),
		Vector2(0, medio_alto),
		Vector2(-medio_ancho, 0),
	])
