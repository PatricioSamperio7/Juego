extends CharacterBody3D

var max_speed = 8.0
var is_leader = false
var activo = true
var max_distance = 40.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var direccion_mirada = Vector3(0, 0, 1)

@onready var detection_area = $Area3D

func _ready():
	add_to_group("swarm")
	if get_tree().get_nodes_in_group("leader").size() == 0:
		hacerme_lider()

func hacerme_lider():
	is_leader = true
	add_to_group("leader")
	scale = Vector3(1.5, 1.5, 1.5)

func desactivar():
	if not activo: 
		return 
		
	activo = false
	
	# --- Retroalimentación de audio (Ya funciona) ---
	if has_node("SfxFalla"):
		$SfxFalla.play()

	# --- AJUSTE DE PARTÍCULAS ---
	if has_node("Chispas"):
		var particulas = $Chispas
		# 1. Las despegamos del dron para que no se muevan con él
		particulas.top_level = true 
		# 2. Aseguramos que se queden en la posición global donde tronó
		particulas.global_position = global_position 
		# 3. Las prendemos
		particulas.emitting = true

	# --- Lógica de liderazgo (Lo que ya tenías) ---
	if is_leader:
		is_leader = false
		remove_from_group("leader")
		scale = Vector3(1.0, 1.0, 1.0)
		pasar_liderazgo()
		
	position.y -= 0.5 

func pasar_liderazgo():
	var drones = get_tree().get_nodes_in_group("swarm")
	var nuevo_lider = null
	var min_dist = 9999.0
	
	for dron in drones:
		if dron != self and dron.activo:
			var d = global_position.distance_to(dron.global_position)
			if d < min_dist:
				min_dist = d
				nuevo_lider = dron
				
	if nuevo_lider != null:
		nuevo_lider.hacerme_lider()

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if not activo:
		move_and_slide()
		return 
		
	if is_leader:
		mover_lider(delta)
	else:
		mover_enjambre(delta)
		
	move_and_slide()
	revisar_choques()
	actualizar_chasis(delta) 

func revisar_choques():
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var objeto = col.get_collider()
		if objeto != null and objeto.is_in_group("trampa"):
			desactivar()

func mover_lider(delta):
	var rotacion_input = Input.get_axis("ui_right", "ui_left") 
	var acelerador = Input.get_axis("ui_down", "ui_up") 

	if abs(rotacion_input) > 0.01:
		direccion_mirada = direccion_mirada.rotated(Vector3.UP, rotacion_input * 3.5 * delta).normalized()

	var velocidad_actual = 4.0
	var mapa = get_parent()
	if "distancia_enjambre" in mapa:
		var porcentaje = (mapa.distancia_enjambre - mapa.min_dist) / (mapa.max_dist - mapa.min_dist)
		velocidad_actual = lerp(4.0, 12.0, porcentaje)

	velocity.x = direccion_mirada.x * acelerador * velocidad_actual
	velocity.z = direccion_mirada.z * acelerador * velocidad_actual

func mover_enjambre(delta):
	var lideres = get_tree().get_nodes_in_group("leader")
	if lideres.size() == 0:
		return
		
	var lider = lideres[0]
	var dist_al_lider = global_position.distance_to(lider.global_position)

	if dist_al_lider > max_distance:
		desactivar()
		return

	var apertura = 2.5
	var mapa = get_parent()
	if "distancia_enjambre" in mapa:
		apertura = mapa.distancia_enjambre

	var punto_retrasado = lider.global_position - (lider.direccion_mirada * (apertura + 1.5))
	var dist_al_punto = global_position.distance_to(punto_retrasado)

	var neighbors = detection_area.get_overlapping_bodies()
	var separation = Vector3.ZERO
	var goal_force = Vector3.ZERO
	
	for neighbor in neighbors:
		if neighbor != self and neighbor.is_in_group("swarm") and neighbor.activo:
			var dist = global_position.distance_to(neighbor.global_position)
			if dist < 0.1: 
				dist = 0.1
			
			if neighbor.is_leader and dist < apertura + 1.0:
				separation += (global_position - neighbor.global_position).normalized() * (25.0 / dist)
			elif not neighbor.is_leader and dist < apertura:
				separation += (global_position - neighbor.global_position).normalized() * (3.0 / dist)

	var radio_tolerancia = apertura * 1.2
	
	if dist_al_punto > radio_tolerancia:
		goal_force = (punto_retrasado - global_position).normalized() * 5.0
	else:
		goal_force = (punto_retrasado - global_position).normalized() * 0.5

	var steering = separation + goal_force
	var move_velocity = Vector3(velocity.x, 0, velocity.z)
	
	if dist_al_punto < radio_tolerancia and separation.length() < 4.0:
		move_velocity = move_velocity.lerp(Vector3.ZERO, delta * 12.0)
		if move_velocity.length() < 0.2:
			move_velocity = Vector3.ZERO
	else:
		move_velocity = move_velocity.lerp(steering * max_speed, delta * 4.0)
		
	var vel_maxima_tropa = max_speed
	if "distancia_enjambre" in mapa:
		var porcentaje = (apertura - mapa.min_dist) / (mapa.max_dist - mapa.min_dist)
		vel_maxima_tropa = lerp(4.0, 12.0, porcentaje)
		
	move_velocity = move_velocity.limit_length(vel_maxima_tropa * 1.2)
	
	velocity.x = move_velocity.x
	velocity.z = move_velocity.z

func actualizar_chasis(delta):
	var chasis = $ChasisVisual 
	if not chasis: return
	
	var normal_piso = Vector3.UP
	if is_on_floor():
		normal_piso = get_floor_normal()
		
	var adelante = direccion_mirada.normalized()
	var derecha = adelante.cross(normal_piso).normalized()
	adelante = normal_piso.cross(derecha).normalized()
	
	var base_inclinada = Basis(derecha, normal_piso, -adelante)
	
	# Sacamos la escala actual para no perder el tamaño del líder
	var escala = chasis.global_transform.basis.get_scale()
	
	# Normalizamos ambas bases (limpiamos escala) para que el motor no chille con el slerp
	var base_actual_limpia = chasis.global_transform.basis.orthonormalized()
	var base_meta_limpia = base_inclinada.orthonormalized()
	
	# Hacemos el giro suave
	var base_girada = base_actual_limpia.slerp(base_meta_limpia, delta * 10.0)
	
	# Le metemos la escala de vuelta vector por vector
	base_girada.x *= escala.x
	base_girada.y *= escala.y
	base_girada.z *= escala.z
	
	chasis.global_transform.basis = base_girada
