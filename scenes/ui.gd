extends Control # ¡Corregido para que coincida con tu nodo!

@onready var button_profile = $buttonProfile
@onready var fondo_oscuro = $fondoOscuro

func _ready() -> void:
	# Asegurarnos de que el modal esté oculto al iniciar
	fondo_oscuro.visible = false
	
	# Conectamos el botón de perfil
	button_profile.pressed.connect(_on_button_profile_pressed)

func _on_button_profile_pressed() -> void:
	# Verificamos si el panel ya está visible
	if fondo_oscuro.visible == true:
		# Si está abierto -> LO CERRAMOS
		fondo_oscuro.visible = false
		get_tree().paused = false # Quitamos la pausa
	else:
		# Si está cerrado -> LO ABRIMOS
		fondo_oscuro.visible = true
		get_tree().paused = true # Ponemos pausa
