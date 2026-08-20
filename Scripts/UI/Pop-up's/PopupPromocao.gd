class_name PopupPromocao
extends Control

signal promocao_confirmada(jogador_id: int, substituto: AnimalInstance)

var _overlay_ref: Control = null

func exibir(parent: Node, jogador_id: int, banco: Array[AnimalInstance]) -> void:
	fechar()
	if banco.is_empty():
		return

	var refs := HelperUI.criar_popup_base(
		parent,
		"PROMOÇÃO OBRIGATÓRIA",
		"Seu animal ativo foi nocauteado! Escolha um substituto do seu Banco:"
	)
	_overlay_ref = refs["overlay"]
	var vbox: VBoxContainer = refs["vbox"]

	for animal in banco:
		var btn := Button.new()
		btn.text = "%s (HP: %d/%d)" % [animal.card.name, animal.current_hp, animal.card.hp]
		btn.pressed.connect(func():
			promocao_confirmada.emit(jogador_id, animal)
			fechar()
		)
		vbox.add_child(btn)

func fechar() -> void:
	if is_instance_valid(_overlay_ref):
		_overlay_ref.queue_free()
	_overlay_ref = null
	if not is_inside_tree():
		queue_free()
