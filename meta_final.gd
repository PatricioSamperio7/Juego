extends Area3D

@onready var nivel_manager = $".." 

func _on_body_entered(body):
	if body.is_in_group("jugador"):
		
		# Filtramos para contar solo los drones que siguen jalando
		var vivos = 0
		var enjambre = get_tree().get_nodes_in_group("swarm")
		for d in enjambre:
			if d.activo:
				vivos += 1
				
		var minimo_requerido = 4 
		
		# Sacamos cuentas de lo que falta
		var faltan_obj = nivel_manager.totales - nivel_manager.recogidos
		var faltan_drones = minimo_requerido - vivos
		
		# Si ya cumple con todo, disparamos la pantalla de victoria
		if faltan_obj <= 0 and faltan_drones <= 0:
			nivel_manager.nivel_completado()
			
		# Si la regó en algo, armamos el reporte de advertencia en el centro de la pantalla
		else:
			var mensaje = "Acceso Denegado:\n"
			if faltan_obj > 0:
				mensaje += "Faltan " + str(faltan_obj) + " objetos.\n"
			if faltan_drones > 0:
				mensaje += "Te faltan " + str(faltan_drones) + " drones activos."
				
			nivel_manager.mostrar_mensaje_meta(mensaje)
