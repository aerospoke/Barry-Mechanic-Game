extends RefCounted
class_name ShopCatalog

# Catálogo de piezas que se compran en la tienda de la PC. Vive aparte del
# menú y del jugador porque ambos necesitan los mismos íconos: la tienda para
# pintar la lista y Barry para mostrar la pieza en la mano. Los datos de
# precio/nombre vienen de la tabla `shop_items` (ver sql/shop_items.sql); acá
# solo viven los assets, que no tiene sentido guardar en la base de datos.
const ITEMS := {
	"oils": {
		"icono_tienda": preload("res://objetos/aceites1.png"),
		"icono_mano": preload("res://objetos/work1.png"),
	},
	"filters": {
		"icono_tienda": preload("res://objetos/filtrosaire.png"),
		"icono_mano": preload("res://objetos/airFlow5.png"),
	},
	"lights": {
		"icono_tienda": preload("res://objetos/light1.png"),
		"icono_mano": preload("res://objetos/light5.png"),
	},
	"keys": {
		"icono_tienda": preload("res://objetos/cerrageria.png"),
		"icono_mano": preload("res://objetos/boxKeys.png"),
	},
}

static func icono_tienda(key: String) -> Texture2D:
	return ITEMS.get(key, {}).get("icono_tienda")

static func icono_mano(key: String) -> Texture2D:
	return ITEMS.get(key, {}).get("icono_mano")
