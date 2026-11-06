extends VBoxContainer


func _ready() -> void:
	%Draft.focus_entered.connect(%Card.set_reward_focus.bind(true))
	%Draft.focus_exited.connect(%Card.set_reward_focus.bind(false))
