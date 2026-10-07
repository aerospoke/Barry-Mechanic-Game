extends RefCounted
class_name PetCatalog

# Mascotas que se pueden elegir para el guacal de la sala (ver "guacal" en
# room_object_catalog.gd y el selector en pet_picker.gd). La eleccion se
# guarda en room_objects.variant (ver sql/mascotas.sql). Sumar una mascota
# nueva es agregar una entrada aca: su escena (un CharacterBody2D que se
# mueve solo, como cat.tscn) y de donde sacar su icono.
const MASCOTAS := {
	"nami": {
		"nombre": "Nami",
		"descripcion": "Gata curiosa. Se pasea por el taller y se echa a dormir donde quiere.",
		"escena": preload("res://scenes/cat.tscn"),
		# Primer cuadro de la hoja de sprites, para el menu y el boton.
		"hoja": preload("res://objetos/spirtegatos.png"),
		"region_icono": Rect2(206, 7, 33, 33),
		# Los sprites del gato son de 33px: en la sala se ven mas grandes.
		"escala": 2.2,
	},
}

const POR_DEFECTO := "nami"

static func existe(id: String) -> bool:
	return MASCOTAS.has(id)

static func nombre(id: String) -> String:
	return MASCOTAS.get(id, {}).get("nombre", id)

static func descripcion(id: String) -> String:
	return MASCOTAS.get(id, {}).get("descripcion", "")

static func escena(id: String) -> PackedScene:
	return MASCOTAS.get(id, {}).get("escena")

static func escala(id: String) -> float:
	return MASCOTAS.get(id, {}).get("escala", 1.0)

static func icono(id: String) -> Texture2D:
	var datos: Dictionary = MASCOTAS.get(id, {})
	if datos.is_empty():
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = datos["hoja"]
	atlas.region = datos["region_icono"]
	return atlas
