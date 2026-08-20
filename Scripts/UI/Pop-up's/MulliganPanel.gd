# ==================================================
# Nome: MulliganPanel
# Categoria: UI
# Responsável pela interface de mulligan.
# ==================================================

class_name MulliganPanel
extends Control

signal mulligan_confirmado(jogador_id: int)

var _overlay_ref: Control = null

func exibir(parent: Node, jogador_id: int, tempo_limite: float = 15.0) -> void:
	fechar()
	var refs := HelperUI.criar_popup_base(
		parent,
		"Mulligan necessário",
		"Sua mão não tem nenhum Animal Filhote. Ela será embaralhada de volta e uma nova mão será comprada."
	)
	_overlay_ref = refs["overlay"]

	var botao := Button.new()
	botao.text = "Confirmar"
	botao.pressed.connect(func():
		_confirmar(jogador_id)
	)
	refs["vbox"].add_child(botao)

	var local_overlay := _overlay_ref
	# 🟢 CORRIGIDO: Usa parent.get_tree()
	await parent.get_tree().create_timer(tempo_limite).timeout
	if is_instance_valid(local_overlay) and _overlay_ref == local_overlay:
		_confirmar(jogador_id)

func fechar() -> void:
	if is_instance_valid(_overlay_ref):
		_overlay_ref.queue_free()
	_overlay_ref = null
	if not is_inside_tree():
		queue_free()

func _confirmar(jogador_id: int) -> void:
	if is_instance_valid(_overlay_ref):
		mulligan_confirmado.emit(jogador_id)
		fechar()
