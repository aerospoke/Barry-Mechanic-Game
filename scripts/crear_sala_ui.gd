extends Control

# Onboarding: se muestra una sola vez, justo despues del primer login, cuando
# el jugador todavia no tiene ninguna sala (ver login_ui.gd). Elige un estilo,
# se crea la sala en la base de datos y entra directo a ella, igual que si la
# hubiera creado desde la PC (ver searchwork_ui.gd _on_estilo_elegido).

@onready var nombre_edit: LineEdit = $NombreEdit
@onready var style_container: VBoxContainer = $StyleContainer
@onready var titulo: Label = $Titulo

const StatusLabel = preload("res://scripts/status_label.gd")

var status: Label

func _ready() -> void:
	status = StatusLabel.crear(self, Vector2(30.0, 620.0), 360.0)
	# profile_name ya deberia estar cargado: login_ui.gd/registro_ui.gd llaman
	# a load_profile() antes de mandar para aca. Si por lo que sea llegara
	# vacio, se cae al genérico en vez de mostrar "BIENVENIDO, ".
	var nombre := Supabase.profile_name.strip_edges()
	titulo.text = "BIENVENIDO, %s" % nombre.to_upper() if nombre != "" else "BIENVENIDO"
	_construir_opciones_sala()

func _construir_opciones_sala() -> void:
	for id in RoomStyles.ORDEN:
		var estilo: Dictionary = RoomStyles.ESTILOS[id]

		var btn := Button.new()
		btn.custom_minimum_size.y = 80
		btn.text = "%s\n%s" % [estilo["nombre"], estilo["descripcion"]]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_color_override("font_color", estilo["suelo_a"])
		btn.pressed.connect(_on_estilo_elegido.bind(id))
		style_container.add_child(btn)

func _on_estilo_elegido(id: String) -> void:
	var estilo: Dictionary = RoomStyles.ESTILOS[id]
	var nombre := nombre_edit.text.strip_edges()
	if nombre == "":
		nombre = str(estilo["nombre"])

	status.mostrar_info("Creando \"%s\"..." % nombre)
	_bloquear_estilos(true)

	# es_principal=true: esta es la primera sala de la cuenta (por eso estamos
	# en el onboarding), asi que queda como la sala a la que se entra directo
	# la proxima vez que inicie sesion (ver Supabase.redirigir_tras_login()).
	var sala := await Supabase.create_room(nombre, id, true)
	if sala.is_empty():
		# Sin conexion o sin tabla `rooms`: se entra igual con una sala suelta,
		# pero no quedara guardada al cerrar el juego.
		status.mostrar_error("No se pudo guardar la sala; entras sin guardarla")
		sala = {"id": "", "name": nombre, "style": id, "owner": Supabase.user_id, "is_main": true}

	Supabase.current_room = sala
	get_tree().change_scene_to_file("res://scenes/room.tscn")

func _bloquear_estilos(bloqueado: bool) -> void:
	for child in style_container.get_children():
		if child is Button:
			child.disabled = bloqueado
