# ==================================================
# Nome: PopupSelecaoAnimal
# Categoria: UI
# Responsável por exibir animais em campo (banco próprio
# ou do oponente) para o jogador selecionar um alvo.
# ==================================================

class_name PopupSelecaoAnimal
extends Control

signal animais_selecionados(animais: Array[AnimalInstance])
signal cancelado()

var _overlay_ref: Control = null
var _escolhidos: Array[AnimalInstance] = []

func exibir(
	parent: Node,
	titulo: String,
	instrucao: String,
	animais_opcoes: Array[AnimalInstance],
	qtd_requerida: int = 1
) -> void:
	fechar()

	if animais_opcoes.is_empty():
		push_warning("[PopupSelecaoAnimal] Nenhum animal enviado para seleção.")
		cancelado.emit()
		return

	var refs := HelperUI.criar_popup_base(parent, titulo, instrucao)
	_overlay_ref = refs["overlay"]
	var vbox: VBoxContainer = refs["vbox"]

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(hbox)

	var btn_confirmar := Button.new()

	var atualizar_estado_botao = func():
		var total := _escolhidos.size()
		btn_confirmar.text = "Confirmar (%d/%d)" % [total, qtd_requerida]
		btn_confirmar.disabled = (total != qtd_requerida)

	atualizar_estado_botao.call()

	for animal in animais_opcoes:
		if animal == null or animal.card == null:
			continue

		var dados_carta := HelperUI.instanciar_carta_escalada(animal.card, Vector2(130, 190))
		if dados_carta.is_empty():
			continue

		var envelope: Control = dados_carta["envelope"]

		var label_hp := Label.new()
		label_hp.text = "HP: %d/%d" % [animal.current_hp, animal.card.hp]
		label_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		envelope.add_child(label_hp)

		var fundo_selecao := PanelContainer.new()
		fundo_selecao.name = "FundoSelecao"
		fundo_selecao.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.4, 0.9, 0.45)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_color = Color(0.2, 0.6, 1.0)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		fundo_selecao.add_theme_stylebox_override("panel", style)
		fundo_selecao.hide()

		envelope.add_child(fundo_selecao)
		envelope.move_child(fundo_selecao, 0)

		var btn_click := Button.new()
		btn_click.flat = true
		btn_click.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		envelope.add_child(btn_click)

		btn_click.pressed.connect(func():
			if _escolhidos.has(animal):
				_escolhidos.erase(animal)
				fundo_selecao.hide()
			else:
				if _escolhidos.size() < qtd_requerida:
					_escolhidos.append(animal)
					fundo_selecao.show()

			atualizar_estado_botao.call()
		)

		hbox.add_child(envelope)

	btn_confirmar.pressed.connect(func():
		animais_selecionados.emit(_escolhidos)
		fechar()
	)
	vbox.add_child(btn_confirmar)

	var btn_cancelar := Button.new()
	btn_cancelar.text = "Cancelar"
	btn_cancelar.pressed.connect(func():
		cancelado.emit()
		fechar()
	)
	vbox.add_child(btn_cancelar)

func fechar() -> void:
	_escolhidos.clear()
	if is_instance_valid(_overlay_ref):
		_overlay_ref.queue_free()
	_overlay_ref = null
	if not is_inside_tree():
		queue_free()
