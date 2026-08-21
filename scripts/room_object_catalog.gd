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
		# Ocupa 2 casillas (1 de ancho x 2 de profundidad). tamano_colision()
		# lo traduce a pixeles multiplicando por RoomStyles.TILE_W/TILE_H, asi
		# mide exactamente lo mismo en cualquier sala, sea cual sea el estilo.
		"baldosas": Vector2(1, 2),
	},
	"car": {
		"textura": preload("res://objetos/a3.png"),
		"escala": Vector2(0.5, 0.5),
		# Nombre reservado: aca es donde movement_script.gd conecta el
		# minijuego de completar el trabajo.
		"nombre_nodo": "WorkZone",
		"baldosas": Vector2(2, 2),
	},
	"trash": {
		"textura": preload("res://objetos/trash2.png"),
		"escala": Vector2(0.3, 0.3),
		# Sin nombre_nodo: decorativo, nunca tuvo comportamiento propio.
		"baldosas": Vector2(1, 1),
	},
	"estante_aceite": {
		"textura": preload("res://objetos/aceites1.png"),
		"escala": Vector2(0.3, 0.3),
		"baldosas": Vector2(1, 1),
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

static func tamano_colision(kind: String) -> Vector2:
	var baldosas: Vector2 = OBJETOS.get(kind, {}).get("baldosas", Vector2(1, 1))
	return Vector2(baldosas.x * RoomStyles.TILE_W, baldosas.y * RoomStyles.TILE_H)
