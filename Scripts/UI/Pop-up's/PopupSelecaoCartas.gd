# ==================================================
# Nome: PopupSelecaoCartas
# Categoria: UI
# Responsável por exibir uma lista de cartas de qualquer
# origem (Deck, Zona Fóssil, Cemitério, Mão) para o
# jogador selecionar X cartas.
# ==================================================

class_name PopupSelecaoCartas
extends Control

signal cartas_selecionadas(cartas: Array[CardBaseResource])
signal cancelado()

var _overlay_ref: Control = null
var _cartas_escolhidas: Array[CardBaseResource] = []

## Exibe o pop-up modal para seleção de cartas.
## parent: Nó onde o overlay será instanciado.
## titulo: Título do modal (ex: "Zona Fóssil", "Busca no Deck", "Cemitério").
## instrucao: Texto descritivo da ação (ex: "Selecione 1 Fóssil para reviver").
## cartas_opcoes: Lista de cartas elegíveis para escolha.
## qtd_requerida: Quantidade de cartas a selecionar.
## permitir_menos: Se true, permite confirmar com MENOS cartas que o limite (ex: "escolha até X").
func exibir(
	parent: Node, 
	titulo: String, 
	instrucao: String, 
	cartas_opcoes: Array[CardBaseResource], 
	qtd_requerida: int = 1,
	permitir_menos: bool = false
) -> void:
	fechar()
	
	if cartas_opcoes.is_empty():
		push_warning("[PopupSelecaoCartas] Nenhuma carta enviada para seleção.")
		cancelado.emit()
		return

	var refs := HelperUI.criar_popup_base(parent, titulo, instrucao)
	_overlay_ref = refs["overlay"]
	var vbox: VBoxContainer = refs["vbox"]

	# Container com Scroll Horizontal (eixo X)
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
		var total := _cartas_escolhidas.size()
		btn_confirmar.text = "Confirmar (%d/%d)" % [total, qtd_requerida]
		if permitir_menos:
			btn_confirmar.disabled = (total == 0)
		else:
			btn_confirmar.disabled = (total != qtd_requerida)

	atualizar_estado_botao.call()

	# Montagem dos cards na horizontal
	for carta in cartas_opcoes:
		var dados_carta := HelperUI.instanciar_carta_escalada(carta, Vector2(130, 190))
		if dados_carta.is_empty():
			continue

		var envelope: Control = dados_carta["envelope"]

		# Painel de destaque azul (seleção)
		var fundo_selecao := PanelContainer.new()
		fundo_selecao.name = "FundoSelecao"
		fundo_selecao.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.4, 0.9, 0.45) # Azul translúcido
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
		envelope.move_child(fundo_selecao, 0) # Fica atrás do visual da carta

		# Botão invisível sobreposto para capturar o clique
		var btn_click := Button.new()
		btn_click.flat = true
		btn_click.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		envelope.add_child(btn_click)

		btn_click.pressed.connect(func():
			if _cartas_escolhidas.has(carta):
				_cartas_escolhidas.erase(carta)
				fundo_selecao.hide()
			else:
				if _cartas_escolhidas.size() < qtd_requerida:
					_cartas_escolhidas.append(carta)
					fundo_selecao.show()

			atualizar_estado_botao.call()
		)

		hbox.add_child(envelope)

	btn_confirmar.pressed.connect(func():
		cartas_selecionadas.emit(_cartas_escolhidas)
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
	_cartas_escolhidas.clear()
	if is_instance_valid(_overlay_ref):
		_overlay_ref.queue_free()
	_overlay_ref = null
	if not is_inside_tree():
		queue_free()
