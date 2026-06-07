extends Node3D

var drone_scene = preload("res://swarm_agent.tscn")
var num_drones = 8

@export var energia_maxima = 100.0
@export var drenaje_base = 1.0 
@export var tiempo_nivel = 120.0 # 2 minutos de default, lo cambias en el Inspector

@export var punto_spawn = Vector3(15, 20, 15) 
@export var offset_camara = Vector3(0, 20, 25) 

var energia_actual = 100.0
var tiempo_restante = 120.0
var distancia_enjambre = 2.5 
var min_dist = 1.5
var max_dist = 6.0

# --- Variables para los coleccionables ---
var recogidos = 0
var totales = 3

@onready var label_energia = $HUD/LabelEnergia
@onready var label_distancia = $HUD/LabelDistancia
@onready var label_tiempo = $HUD/LabelTiempo 
@onready var label_coleccionables = $HUD/LabelColeccionables 
@onready var label_drones = $HUD/LabelDrones
@onready var label_mensaje_meta = $HUD/LabelMensajeMeta

# --- Referencias a todas las pantallas nuevas ---
@onready var pantalla_inicio = $HUD/PantallaInicio
@onready var pantalla_pausa = $HUD/PantallaPausa
@onready var pantalla_gameover = $HUD/PantallaGameOver
@onready var pantalla_victoria = $HUD/PantallaVictoria

@onready var btn_arrancar = $HUD/PantallaInicio/BtnArrancar
@onready var btn_continuar = $HUD/PantallaPausa/BtnContinuar
@onready var btn_reiniciar = $HUD/PantallaPausa/BtnReiniciar
@onready var btn_reintentar = $HUD/PantallaGameOver/BtnReintentar
@onready var btn_niveles = $HUD/PantallaVictoria/BtnNiveles

func _ready():
	energia_actual = energia_maxima
	tiempo_restante = tiempo_nivel
	
	# Congelamos el nivel de entrada para leer el objetivo
	get_tree().paused = true
	if pantalla_inicio: 
		pantalla_inicio.show()
	
	var cam = $Camera3D
	cam.global_position = punto_spawn + offset_camara
	cam.look_at(punto_spawn)
	
	for i in range(num_drones):
		var new_drone = drone_scene.instantiate()
		new_drone.position = punto_spawn + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		add_child(new_drone)

	# --- Conexión de los coleccionables ---
	if has_node("Coleccionable1"): $Coleccionable1.objeto_recogido.connect(_sumar_punto)
	if has_node("Coleccionable2"): $Coleccionable2.objeto_recogido.connect(_sumar_punto)
	if has_node("Coleccionable3"): $Coleccionable3.objeto_recogido.connect(_sumar_punto)

	# --- Conexión de todos los botones ---
	if btn_arrancar: btn_arrancar.pressed.connect(quitar_pausa_inicio)
	if btn_continuar: btn_continuar.pressed.connect(quitar_pausa)
	if btn_reiniciar: btn_reiniciar.pressed.connect(reiniciar_nivel)
	if btn_reintentar: btn_reintentar.pressed.connect(reiniciar_nivel)
	if btn_niveles: btn_niveles.pressed.connect(ir_a_selector)
	
	# Aseguramos que los demás menús arranquen apagados
	if pantalla_pausa: pantalla_pausa.hide()
	if pantalla_gameover: pantalla_gameover.hide()
	if pantalla_victoria: pantalla_victoria.hide()

func _process(delta):
	# Botón de reinicio rápido
	if Input.is_physical_key_pressed(KEY_R):
		reiniciar_nivel()
		return

	# Pausa con la tecla ESCAPE
	if Input.is_physical_key_pressed(KEY_ESCAPE):
		poner_pausa()
		return

	# Controles del enjambre
	if Input.is_physical_key_pressed(KEY_E):
		distancia_enjambre = min(distancia_enjambre + (delta * 3.0), max_dist)
	elif Input.is_physical_key_pressed(KEY_Q):
		distancia_enjambre = max(distancia_enjambre - (delta * 3.0), min_dist)

	# El reloj avanza solo si hay pila
	if tiempo_restante > 0 and energia_actual > 0:
		tiempo_restante -= delta
		if tiempo_restante <= 0:
			tiempo_restante = 0
			apagar_enjambre() 

	calcular_consumo(delta)
	actualizar_pantalla()
	seguir_al_lider(delta)

func calcular_consumo(delta):
	if energia_actual <= 0:
		return 

	var penalizacion_rezagados = 0.0
	var drones = get_tree().get_nodes_in_group("swarm")
	var lider = null
	var drones_perdidos = 0

	for d in drones:
		if d.is_leader and d.activo:
			lider = d
			break

	if lider != null:
		for d in drones:
			if d.activo and not d.is_leader:
				var dist = d.global_position.distance_to(lider.global_position)
				if dist > 18.0:
					drones_perdidos += 1
					
		penalizacion_rezagados = drones_perdidos * 1.5

	var drenaje_apertura = (distancia_enjambre - min_dist) * 0.3
	var drenaje_total = drenaje_base + drenaje_apertura + penalizacion_rezagados
	energia_actual -= drenaje_total * delta

	if energia_actual <= 0:
		energia_actual = 0
		apagar_enjambre()

func apagar_enjambre():
	var drones = get_tree().get_nodes_in_group("swarm")
	for d in drones:
		if d.activo:
			d.activo = false
			d.is_leader = false
			d.position.y -= 0.5 
			
	# Congelamos el mundo y botamos la pantalla de Game Over
	get_tree().paused = true
	if pantalla_gameover:
		pantalla_gameover.show()

func actualizar_pantalla():
	if label_energia:
		var porcentaje = (energia_actual / energia_maxima) * 100.0
		label_energia.text = "Batería: %d%%" % int(porcentaje)
	if label_distancia:
		label_distancia.text = "Apertura (Q/E): %.1f m" % distancia_enjambre
	if label_tiempo:
		var mins = int(tiempo_restante) / 60
		var secs = int(tiempo_restante) % 60
		label_tiempo.text = "Tiempo: %02d:%02d" % [mins, secs]
	if label_coleccionables:
		label_coleccionables.text = "Objetos: %d / %d" % [recogidos, totales]
		
	if label_drones:
		var vivos = 0
		var enjambre = get_tree().get_nodes_in_group("swarm")
		for d in enjambre:
			if d.activo:
				vivos += 1
		label_drones.text = "Drones: %d" % vivos
		
		# --- CONDICIÓN DE DERROTA: Se acabaron las máquinas ---
		if vivos == 0 and not get_tree().paused:
			apagar_enjambre()

func seguir_al_lider(delta):
	var lideres = get_tree().get_nodes_in_group("leader")
	if lideres.size() > 0:
		var lider = lideres[0]
		var cam = $Camera3D
		
		var distancia_cable = 8.0 
		var altura = 4.0
		
		var direccion_atras = -lider.direccion_mirada.normalized()
		var punto_objetivo = lider.global_position + (direccion_atras * distancia_cable)
		punto_objetivo.y += altura
		
		cam.global_position = cam.global_position.lerp(punto_objetivo, delta * 5.0)
		cam.look_at(lider.global_position + Vector3(0, 1.0, 0), Vector3.UP)

func _sumar_punto():
	recogidos += 1
	if has_node("SfxPunto"):
		$SfxPunto.play()

func mostrar_mensaje_meta(texto: String):
	if label_mensaje_meta:
		label_mensaje_meta.text = texto
		await get_tree().create_timer(3.0).timeout
		if label_mensaje_meta:
			label_mensaje_meta.text = ""

# --- FUNCIONES DE CONTROL DE PANTALLAS ---
func quitar_pausa_inicio():
	get_tree().paused = false
	if pantalla_inicio:
		pantalla_inicio.hide()

func poner_pausa():
	if not get_tree().paused and pantalla_pausa:
		get_tree().paused = true
		pantalla_pausa.show()

func quitar_pausa():
	get_tree().paused = false
	if pantalla_pausa:
		pantalla_pausa.hide()

func reiniciar_nivel():
	get_tree().paused = false 
	get_tree().reload_current_scene()

func nivel_completado():
	get_tree().paused = true
	if pantalla_victoria:
		pantalla_victoria.show()

func ir_a_selector():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://menu.tscn") # <- Aquí va la ruta real de tu equipo
