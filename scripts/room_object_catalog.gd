extends RefCounted
class_name RoomObjectCatalog

# Catálogo de objetos que se pueden colocar en una sala. Vive aparte de
# room.gd porque es puro dato (mismo patrón que RoomStyles y ShopCatalog):
# room.gd solo sabe instanciar un WorldObject y pedirle a este diccionario
# qué textura/escala usar según el "kind" que trae la fila de la base de
# datos (ver sql/room_objects.sql).
const OBJETOS := {
	"pc": {
		"textura": preload("res://objetos/Estantes/desktop.png"),
		"escala": Vector2(0.3, 0.3),
		# Nombre de nodo que espera movement_script.gd para reconocer el
		# objeto como interactivo (ver conectar_objeto() ahi). Un "kind" sin
		# esta entrada es puramente decorativo: se ve y choca, pero no hace
		# nada al tocarlo.
		"nombre_nodo": "SearchWork",
		# Sin poligono_colision propio: las imagenes de Estantes/ ya vienen
		# todas con la misma base/tamaño, asi que comparten el rombo comun
		# (ver poligono_colision() mas abajo) en vez de necesitar un ajuste
		# a medida por objeto.
	},
	"car": {
		"textura": preload("res://objetos/a3.png"),
		"escala": Vector2(0.5, 0.5),
		# Nombre reservado: aca es donde movement_script.gd conecta el
		# minijuego de completar el trabajo.
		"nombre_nodo": "WorkZone",
	},
	"trash": {
		"textura": preload("res://objetos/Estantes/basura.png"),
		"escala": Vector2(0.3, 0.3),
		# Caneca del taller: muestra un medidor con Supabase.profile_trash y,
		# llena, abre el minijuego de reciclaje al interactuar. Como los
		# estantes, va por meta y no por nombre_nodo (puede haber varias).
		"reciclaje": true,
		# Posicion del medidor respecto del origen del objeto, en pixeles:
		# centrado sobre la caneca dibujada (que no esta centrada en su
		# imagen: queda corrida a la izquierda) y justo encima de su borde.
		"posicion_medidor": Vector2(-15, -185),
	},
	"estante_aceite": {
		"textura": preload("res://objetos/Estantes/aceites.png"),
		"escala": Vector2(0.3, 0.3),
		# Al interactuar con la mano vacia, da esta pieza gratis (ya se pago
		# al comprar el estante en la tienda). No usa nombre_nodo porque
		# puede haber mas de uno por sala (a diferencia de la PC/el auto) y
		# los nombres de nodo tienen que ser unicos entre hermanos.
		"pieza_gratis": "oils",
	},
	# Mismo patron que estante_aceite: el "kind" coincide con el "key" de
	# shop_items (ver sql/shop_items_estantes.sql), asi que agregar_objeto_
	# comprado() encuentra esta entrada directo con el key que manda la tienda.
	"filters": {
		"textura": preload("res://objetos/Estantes/filtrosAire.png"),
		"escala": Vector2(0.3, 0.3),
		"pieza_gratis": "filters",
	},
	"keys": {
		"textura": preload("res://objetos/Estantes/cerrageria.png"),
		"escala": Vector2(0.3, 0.3),
		"pieza_gratis": "keys",
	},
	# Guacal de la mascota: al colocarlo (o tocarlo) se elige que mascota vive
	# en el (ver PetCatalog y room.gd). La eleccion va en room_objects.variant.
	"guacal": {
		"textura": preload("res://objetos/guacal.png"),
		"escala": Vector2(0.55, 0.55),
		# Imagen chica sin el margen de las de Estantes/: se apoya sobre la
		# base del objeto en vez de flotar a la altura de un estante.
		"posicion_sprite": Vector2(-12, 25),
		"mascota": true,
	},
	# Equipo de sonido: la musica de la sala sale de aca (ver
	# radio_equipo.gd). Se consigue gratis en la tienda.
	"radio": {
		"textura": preload("res://objetos/radio.png"),
		# Dibujado en isometrico con herramientas_dev/dibujar_radio.py.
		"escala": Vector2(0.5, 0.5),
		"posicion_sprite": Vector2(-12, 28),
		"radio": true,
	},
	# Equipo profesional: misma radio, pero suena igual de fuerte en TODO el
	# taller (sin distancia). Reemplaza al comun: nunca hay dos.
	"radio_pro": {
		"textura": preload("res://objetos/radio_pro.png"),
		# Dibujado con herramientas_dev/dibujar_parlante_pro.py.
		"escala": Vector2(0.45, 0.45),
		"posicion_sprite": Vector2(-3, 8),
		"radio": true,
		"radio_pro": true,
	},
	# Plantas en maceta (dibujadas con herramientas_dev/dibujar_plantas.py).
	# Mismo lienzo para todas, asi que comparten escala y posicion; se mecen
	# solas con la brisa ("balanceo", ver scripts/balanceo.gd).
	"planta_monstera": {
		"textura": preload("res://objetos/plantas/monstera.png"),
		"escala": Vector2(0.5, 0.5),
		"posicion_sprite": Vector2(-12, 13),
		"balanceo": true,
	},
	"planta_cactus": {
		"textura": preload("res://objetos/plantas/cactus.png"),
		"escala": Vector2(0.5, 0.5),
		"posicion_sprite": Vector2(-12, 13),
		"balanceo": true,
	},
	"planta_suculenta": {
		"textura": preload("res://objetos/plantas/suculenta.png"),
		"escala": Vector2(0.5, 0.5),
		"posicion_sprite": Vector2(-12, 13),
		"balanceo": true,
	},
	"planta_palmera": {
		"textura": preload("res://objetos/plantas/palmera.png"),
		"escala": Vector2(0.5, 0.5),
		"posicion_sprite": Vector2(-12, 13),
		"balanceo": true,
	},
	"planta_sansevieria": {
		"textura": preload("res://objetos/plantas/sansevieria.png"),
		"escala": Vector2(0.5, 0.5),
		"posicion_sprite": Vector2(-12, 13),
		"balanceo": true,
	},
	"planta_helecho": {
		"textura": preload("res://objetos/plantas/helecho.png"),
		"escala": Vector2(0.5, 0.5),
		"posicion_sprite": Vector2(-12, 13),
		"balanceo": true,
	},
	"planta_ficus": {
		"textura": preload("res://objetos/plantas/ficus.png"),
		"escala": Vector2(0.5, 0.5),
		"posicion_sprite": Vector2(-12, 13),
		"balanceo": true,
	},
	"planta_bonsai": {
		"textura": preload("res://objetos/plantas/bonsai.png"),
		"escala": Vector2(0.5, 0.5),
		"posicion_sprite": Vector2(-12, 13),
		"balanceo": true,
	},
	"planta_girasoles": {
		"textura": preload("res://objetos/plantas/girasoles.png"),
		"escala": Vector2(0.5, 0.5),
		"posicion_sprite": Vector2(-12, 13),
		"balanceo": true,
	},
	"planta_bambu": {
		"textura": preload("res://objetos/plantas/bambu.png"),
		"escala": Vector2(0.5, 0.5),
		"posicion_sprite": Vector2(-12, 13),
		"balanceo": true,
	},
	# Ventana estilo Habbo: va colgada en la pared, no en el piso (ver
	# scripts/ventana_pared.gd y room.gd _instanciar_ventana). La textura es
	# solo el icono de la tienda: en la sala se dibuja con nubes animadas.
	"ventana": {
		"textura": preload("res://objetos/ventana.png"),
		"pared": true,
	},
	# Estantes nuevos: mismo patron (kind = key de shop_items = pieza que dan).
	"cables": {
		"textura": preload("res://objetos/Estantes/estanteCorriente.png"),
		"escala": Vector2(0.3, 0.3),
		"pieza_gratis": "cables",
	},
	"tools": {
		"textura": preload("res://objetos/Estantes/bancoHerramientas.png"),
		"escala": Vector2(0.3, 0.3),
		"pieza_gratis": "tools",
	},
	"air": {
		"textura": preload("res://objetos/Estantes/compresorAire.png"),
		"escala": Vector2(0.3, 0.3),
		"pieza_gratis": "air",
	},
	"paint": {
		"textura": preload("res://objetos/Estantes/pinturas.png"),
		"escala": Vector2(0.3, 0.3),
		"pieza_gratis": "paint",
	},
}

# Objetos de ambientacion (sofas, luces, banderas...): catalogo generado por
# herramientas_dev/dibujar_objetos.py. Se busca ahi lo que no esta aca.
const ObjetosAmbiente = preload("res://scripts/objetos_ambiente.gd")

static func _datos(kind: String) -> Dictionary:
	if OBJETOS.has(kind):
		return OBJETOS[kind]
	return ObjetosAmbiente.OBJETOS.get(kind, {})

# Se pisa (tapetes, lineas): se dibuja debajo de todo y no choca.
static func es_de_piso(kind: String) -> bool:
	return _datos(kind).get("piso", false)

# Luces que se prenden y apagan: textura de prendida (null = no es luz).
static func textura_encendida(kind: String) -> Texture2D:
	return _datos(kind).get("textura_on")

# Objetos con varias versiones a elegir (banderas): {id: {nombre, textura}}.
static func variantes(kind: String) -> Dictionary:
	return _datos(kind).get("variantes", {})

static func textura(kind: String) -> Texture2D:
	return _datos(kind).get("textura")

static func escala(kind: String) -> Vector2:
	return _datos(kind).get("escala", Vector2(0.35, 0.35))

static func nombre_nodo(kind: String) -> String:
	return _datos(kind).get("nombre_nodo", "")

static func pieza_gratis(kind: String) -> String:
	return _datos(kind).get("pieza_gratis", "")

static func posicion_sprite(kind: String) -> Vector2:
	return _datos(kind).get("posicion_sprite", Vector2.INF)

static func es_radio(kind: String) -> bool:
	return _datos(kind).get("radio", false)

static func es_radio_pro(kind: String) -> bool:
	return _datos(kind).get("radio_pro", false)

static func se_balancea(kind: String) -> bool:
	return _datos(kind).get("balanceo", false)

static func es_de_pared(kind: String) -> bool:
	return _datos(kind).get("pared", false)

static func es_mascota(kind: String) -> bool:
	return _datos(kind).get("mascota", false)

static func es_reciclaje(kind: String) -> bool:
	return _datos(kind).get("reciclaje", false)

static func posicion_medidor(kind: String) -> Vector2:
	return _datos(kind).get("posicion_medidor", Vector2(0, -150))

# Forma de colision de cada "kind". Si trae "poligono_colision" a medida (ej.
# la PC, calcada de su sprite) se usa esa. Si no, el default ya NO es un
# rectangulo: es un rombo de 1 baldosa (ver _rombo_baldosa), la misma forma
# que las baldosas del piso — para que un objeto sin ajuste especial siga
# combinando con el estilo isometrico en vez de verse como una caja plana.
static func poligono_colision(kind: String) -> PackedVector2Array:
	var puntos: Array = _datos(kind).get("poligono_colision", [])
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
