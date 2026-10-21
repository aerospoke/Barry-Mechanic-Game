extends RefCounted
class_name Vestuario

# Trajes de Barry (overoles de colores). Cada uno recolorea la ropa azul del
# sprite original con el shader traje.gdshader, sin dibujar hojas nuevas.
# Se desbloquean con puntos (los que da cada trabajo) o siendo Gold. La
# eleccion se guarda en profiles.outfit (ver sql/profiles_outfit.sql).
#
# Sumar un traje = agregar una entrada aca.

const SHADER := preload("res://scripts/traje.gdshader")

const TRAJES := {
	"clasico": {"nombre": "Azul Clasico", "color": null, "puntos": 0},
	"rojo": {"nombre": "Rojo Turbo", "color": Color(0.80, 0.16, 0.14), "puntos": 20},
	"negro": {"nombre": "Negro Nocturno", "color": Color(0.22, 0.22, 0.27), "puntos": 50},
	"verde": {"nombre": "Verde Militar", "color": Color(0.36, 0.46, 0.22), "puntos": 100},
	"naranja": {"nombre": "Naranja Seguridad", "color": Color(0.96, 0.50, 0.12), "puntos": 150},
	"rosa": {"nombre": "Rosa Chicle", "color": Color(0.95, 0.45, 0.66), "puntos": 220},
	"morado": {"nombre": "Morado Galaxia", "color": Color(0.48, 0.26, 0.78), "puntos": 300},
	"blanco": {"nombre": "Blanco Pista", "color": Color(0.90, 0.91, 0.95), "puntos": 400},
	"dorado": {"nombre": "Dorado Gold", "color": Color(0.96, 0.76, 0.24), "gold": true},
}

const POR_DEFECTO := "clasico"

static func ids() -> Array:
	return TRAJES.keys()

static func nombre(id: String) -> String:
	return TRAJES.get(id, {}).get("nombre", id)

static func desbloqueado(id: String) -> bool:
	var traje: Dictionary = TRAJES.get(id, {})
	if traje.is_empty():
		return false
	if traje.get("gold", false):
		return Supabase.profile_is_gold
	return Supabase.profile_points >= int(traje.get("puntos", 0))

static func requisito(id: String) -> String:
	var traje: Dictionary = TRAJES.get(id, {})
	if traje.get("gold", false):
		return "Exclusivo de la Membresia Gold"
	var puntos := int(traje.get("puntos", 0))
	if puntos == 0:
		return "Disponible desde el inicio"
	return "Se desbloquea con %d puntos" % puntos

# Trajes que se desbloquean al pasar de `antes` a `despues` puntos (para
# festejarlos al volver de un trabajo).
static func nuevos_entre(antes: int, despues: int) -> Array:
	var nuevos: Array = []
	for id in TRAJES:
		var traje: Dictionary = TRAJES[id]
		if traje.get("gold", false):
			continue
		var puntos := int(traje.get("puntos", 0))
		if puntos > antes and puntos <= despues:
			nuevos.append(id)
	return nuevos

# Material para cualquier sprite de Barry (el del juego o la vista previa del
# vestidor). null = traje clasico, sin recolorear.
static func material(id: String) -> ShaderMaterial:
	var color = TRAJES.get(id, {}).get("color")
	if color == null:
		return null
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("color_traje", color)
	return mat
