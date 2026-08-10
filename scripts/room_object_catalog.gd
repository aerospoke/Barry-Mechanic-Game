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
	},
}

static func textura(kind: String) -> Texture2D:
	return OBJETOS.get(kind, {}).get("textura")

static func escala(kind: String) -> Vector2:
	return OBJETOS.get(kind, {}).get("escala", Vector2(0.35, 0.35))

static func nombre_nodo(kind: String) -> String:
	return OBJETOS.get(kind, {}).get("nombre_nodo", "")
