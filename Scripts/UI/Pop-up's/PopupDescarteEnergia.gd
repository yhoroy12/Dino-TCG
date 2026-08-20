# ==================================================
# Nome: PopupDescarteEnergia
# Categoria: UI
# Responsável por permitir ao jogador escolher quais
# energias anexadas a um animal serão descartadas.
# ==================================================

class_name PopupDescarteEnergia
extends Control

signal energias_selecionadas(energias: Array[CardBaseResource])
signal cancelado()

var _overlay_ref: Control = null
var _selecionadas: Array[CardBaseResource] = []

## Exibe o modal para escolha de energias a descartar.
## parent: Nó pai onde o overlay será instanciado.
## instrucao: Mensagem explicativa (ex: "Escolha 2 energias para descartar pelo ataque").
## energias_disponiveis: Array com as energias anexadas ao animal.
## qtd_descarte: Quantidade de energias que DEVEM ser escolhidas.
func exibir(
	parent: Node,
	instrucao: String,
	energias_disponiveis: Array[CardBaseResource],
	qtd_descarte: int
) -> void:
	fechar()

	if energias_disponiveis.size() < qtd_descarte:
		push_error("[PopupDescarteEnergia] Energias disponíveis menores que o custo do descarte.")
		cancelado.emit()
		return

	var refs := HelperUI.criar_popup_base(parent, "Descarte de Energia", instrucao)
	_overlay_ref = refs["overlay"]
	var vbox: VBoxContainer = refs["vbox"]

	# Container horizontal para exibir as cartas de energia
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(hbox)

	var btn_confirmar := Button.new()
	
	var atualizar_estado_botao = func():
		var total := _selecionadas.size()
		btn_confirmar.text = "Confirmar Descarte (%d/%d)" % [total, qtd_descarte]
		btn_confirmar.disabled = (total != qtd_descarte)

	atualizar_estado_botao.call()

	for energia in energias_disponiveis:
		var dados_carta := HelperUI.instanciar_carta_escalada(energia, Vector2(110, 160))
		if dados_carta.is_empty():
			continue

		var envelope: Control = dados_carta["envelope"]

		# Highlight de seleção (fundo vermelho para indicar descarte)
		var fundo_selecao := PanelContainer.new()
		fundo_selecao.name = "FundoSelecao"
		fundo_selecao.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.9, 0.1, 0.1, 0.45) # Vermelho translúcido
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_color = Color(1.0, 0.3, 0.3)
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
			if _selecionadas.has(energia):
				_selecionadas.erase(energia)
				fundo_selecao.hide()
			else:
				if _selecionadas.size() < qtd_descarte:
					_selecionadas.append(energia)
					fundo_selecao.show()

			atualizar_estado_botao.call()
		)

		hbox.add_child(envelope)

	btn_confirmar.pressed.connect(func():
		energias_selecionadas.emit(_selecionadas)
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
	_selecionadas.clear()
	if is_instance_valid(_overlay_ref):
		_overlay_ref.queue_free()
	_overlay_ref = null
	if not is_inside_tree():
		queue_free()
