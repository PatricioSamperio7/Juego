extends Area3D

signal objeto_recogido

func _on_body_entered(body):
	# Filtramos para que solo reaccione al jugador
	if body.is_in_group("jugador"):
		emit_signal("objeto_recogido")
		queue_free() # Mata el nodo para que desaparezca y limpie la memoria
