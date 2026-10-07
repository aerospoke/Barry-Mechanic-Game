extends RefCounted
class_name ShopCatalog

# Catálogo de piezas que se compran en la tienda de la PC. Vive aparte del
# menú y del jugador porque ambos necesitan los mismos íconos: la tienda para
# pintar la lista y Barry para mostrar la pieza en la mano. Los datos de
# precio/nombre vienen de la tabla `shop_items` (ver sql/shop_items.sql); acá
# solo viven los assets, que no tiene sentido guardar en la base de datos.
const ITEMS := {
	"oils": {
		"icono_tienda": preload("res://objetos/oil2.png"),
		"icono_mano": preload("res://objetos/work1.png"),
	},
	"filters": {
		"icono_tienda": preload("res://objetos/Estantes/filtrosAire.png"),
		"icono_mano": preload("res://objetos/airFlow5.png"),
	},
	"lights": {
		"icono_tienda": preload("res://objetos/light1.png"),
		"icono_mano": preload("res://objetos/light5.png"),
	},
	"keys": {
		"icono_tienda": preload("res://objetos/Estantes/cerrageria.png"),
		"icono_mano": preload("res://objetos/boxKeys.png"),
	},
	# Estantes nuevos. Sus imagenes de mano no son de 264px como las de
	# arriba, asi que traen su propia "escala_mano" (ver escala_mano()).
	"cables": {
		"icono_tienda": preload("res://objetos/Estantes/estanteCorriente.png"),
		"icono_mano": preload("res://objetos/herramientas/multimetro.png"),
		"escala_mano": 0.24,
	},
	"tools": {
		"icono_tienda": preload("res://objetos/Estantes/bancoHerramientas.png"),
		"icono_mano": preload("res://objetos/herramientas/martillo.png"),
		"escala_mano": 0.18,
	},
	"air": {
		"icono_tienda": preload("res://objetos/Estantes/compresorAire.png"),
		"icono_mano": preload("res://objetos/work0.png"),
	},
	# Placeholder: no hay todavia un dibujo de lata de pintura suelto, asi
	# que Barry lleva el estante en miniatura.
	"paint": {
		"icono_tienda": preload("res://objetos/Estantes/pinturas.png"),
		"icono_mano": preload("res://objetos/Estantes/pinturas.png"),
		"escala_mano": 0.065,
	},
}

# Escala del icono en la mano de Barry. 0.32 es la que tenia en barry.tscn,
# pensada para las imagenes de 264px.
const ESCALA_MANO_POR_DEFECTO := 0.32

static func icono_tienda(key: String) -> Texture2D:
	return ITEMS.get(key, {}).get("icono_tienda")

static func icono_mano(key: String) -> Texture2D:
	return ITEMS.get(key, {}).get("icono_mano")

static func escala_mano(key: String) -> float:
	return ITEMS.get(key, {}).get("escala_mano", ESCALA_MANO_POR_DEFECTO)
