extends PanelContainer

signal selecionado(dados: Dictionary)
signal ativo_pressionado(dados: Dictionary)
signal editar_pressionado(dados: Dictionary)

const COR_ATIVO   := Color(0.2, 0.9, 0.3, 1.0)
const COR_INATIVO := Color(0.2, 0.2, 0.2, 1.0)

var _dados: Dictionary = {}

@onready var capa_art      : TextureRect    = $CapaArt
@onready var label_nome    : Label          = $InfoPadding/Text/Nome
@onready var label_qtd     : Label          = $InfoPadding/Text/Quantidade
@onready var overlay       : PanelContainer = $ActionsOverlay
@onready var button_ativo  : Button         = $ActionsOverlay/ButtonContainer/ButtonAtivo
@onready var button_editar : Button         = $ActionsOverlay/ButtonContainer/ButtonEditar


func _ready() -> void:
	print("[FundoCapa] _ready disparou — nó: ", name)

	# Verifica se todos os nós foram encontrados
	print("[FundoCapa] capa_art: ",      capa_art)
	print("[FundoCapa] label_nome: ",    label_nome)
	print("[FundoCapa] label_qtd: ",     label_qtd)
	print("[FundoCapa] overlay: ",       overlay)
	print("[FundoCapa] button_ativo: ",  button_ativo)
	print("[FundoCapa] button_editar: ", button_editar)

	overlay.visible = false
	gui_input.connect(_on_gui_input)
	button_ativo.pressed.connect(func(): ativo_pressionado.emit(_dados))
	button_editar.pressed.connect(func(): editar_pressionado.emit(_dados))

	# Confirma mouse_filter do próprio nó raiz
	print("[FundoCapa] mouse_filter do raiz: ", mouse_filter, " (0=Stop, 1=Pass, 2=Ignore)")

	# Lista todos os filhos e seus mouse_filter para identificar quem bloqueia
	_listar_mouse_filters(self, 0)


func _listar_mouse_filters(no: Node, nivel: int) -> void:
	var indent := "  ".repeat(nivel)
	if no is Control:
		print("[FundoCapa] %s%s — mouse_filter: %d" % [indent, no.name, no.mouse_filter])
	for filho in no.get_children():
		_listar_mouse_filters(filho, nivel + 1)


func configurar(dados: Dictionary) -> void:
	print("[FundoCapa] configurar() chamado com dados: ", dados.keys())
	_dados = dados

	if not is_node_ready():
		print("[FundoCapa] nó ainda não está pronto, aguardando ready...")
		await ready
		print("[FundoCapa] ready concluído, continuando configurar()")

	label_nome.text = dados.get("nome", "Sem nome")
	print("[FundoCapa] label_nome definido para: ", label_nome.text)

	var colecao: Array = dados.get("colecao", [])
	var total_cartas := 0
	for entrada in colecao:
		total_cartas += int(entrada.get("quantidade", 0))
	label_qtd.text = "%d / %d" % [total_cartas, DeckRulesSystem.TAMANHO_DECK_VALIDO]
	print("[FundoCapa] label_qtd definido para: ", label_qtd.text)

	var caminho_capa: String = dados.get("capa", "")
	if caminho_capa != "" and ResourceLoader.exists(caminho_capa):
		capa_art.texture = load(caminho_capa)
		print("[FundoCapa] capa carregada: ", caminho_capa)
	else:
		capa_art.texture = null
		print("[FundoCapa] sem capa (caminho vazio ou inexistente): '", caminho_capa, "'")

	_atualizar_borda(dados.get("ativo", false))


func marcar_ativo(valor: bool) -> void:
	_dados["ativo"] = valor
	_atualizar_borda(valor)


func abrir_overlay() -> void:
	print("[FundoCapa] abrir_overlay() chamado")
	overlay.visible = true


func fechar_overlay() -> void:
	print("[FundoCapa] fechar_overlay() chamado")
	overlay.visible = false


func overlay_aberto() -> bool:
	return overlay.visible


func _atualizar_borda(ativo: bool) -> void:
	var estilo := StyleBoxFlat.new()
	estilo.border_width_left   = 3
	estilo.border_width_right  = 3
	estilo.border_width_top    = 3
	estilo.border_width_bottom = 3
	estilo.border_color = COR_ATIVO if ativo else COR_INATIVO
	add_theme_stylebox_override("panel", estilo)


func _on_gui_input(event: InputEvent) -> void:
	# Loga QUALQUER evento que chegue para confirmar que o gui_input está sendo recebido
	if event is InputEventMouseButton:
		print("[FundoCapa] _on_gui_input — botão: ", event.button_index, " pressed: ", event.pressed, " overlay visível: ", overlay.visible)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("[FundoCapa] clique esquerdo detectado")

		if overlay.visible:
			var clique_no_overlay    := overlay.get_global_rect().has_point(event.global_position)
			var clique_no_btn_ativo  := button_ativo.get_global_rect().has_point(event.global_position)
			var clique_no_btn_editar := button_editar.get_global_rect().has_point(event.global_position)
			print("[FundoCapa] clique_no_overlay: ", clique_no_overlay, " | btn_ativo: ", clique_no_btn_ativo, " | btn_editar: ", clique_no_btn_editar)

			if clique_no_overlay and not clique_no_btn_ativo and not clique_no_btn_editar:
				fechar_overlay()
		else:
			print("[FundoCapa] emitindo sinal selecionado com dados: ", _dados.get("nome", "???"))
			selecionado.emit(_dados)
