extends Area3D

func _ready():
	body_entered.connect(_al_chocar)

func _al_chocar(body):
	if body.has_method("desactivar") and body.activo:
		body.desactivar()
