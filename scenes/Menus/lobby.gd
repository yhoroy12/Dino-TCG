extends Control

# ==============================================================================
# lobby.gd — Controlador da Cena de Lobby
# Gerencia navegação entre modos de jogo, popup multiplayer e exibição de perfil.
# ==============================================================================

# -----------------------------------------------------------------------------
# CAMINHOS DAS CENAS
# -----------------------------------------------------------------------------
const CENA_MENU_PRINCIPAL  := "res://Scenes/Menus/MainMenu.tscn"
const CENA_HISTORIA        := ""
const CENA_TREINAMENTO     := "res://Scenes/Menus/ModoTreino.tscn"
const CENA_COLECAO         := ""
const CENA_GERENCIAR_DECKS := "res://Scenes/Menus/GerenciadorDecks.tscn"
# TODO: criar a cena de sala de espera e descomentar a linha abaixo
# const CENA_SALA_ESPERA  := "res://scenes/multiplayer/sala_espera.tscn"

# -----------------------------------------------------------------------------
# REFERÊNCIAS DOS NÓS — BOTÕES PRINCIPAIS
# -----------------------------------------------------------------------------
@onready var button_voltar      : Button = $MarginContainer/LayoutHorizontal/ColunaDireta/ColunaDireita/HBoxContainer/ButtonVoltar
@onready var button_historia    : Button = $MarginContainer/LayoutHorizontal/ColunaDireta/ColunaDireita/Modoslist/ButtonHistoria
@onready var button_multiplayer : Button = $MarginContainer/LayoutHorizontal/ColunaDireta/ColunaDireita/Modoslist/ButtonMultiplayer
@onready var button_treinamento : Button = $MarginContainer/LayoutHorizontal/ColunaDireta/ColunaDireita/Modoslist/ButtonTreinamento
@onready var button_colecao     : Button = $MarginContainer/LayoutHorizontal/ColunaDireta/ColunaDireita/Modoslist/ButtonColecao
@onready var button_decks       : Button = $MarginContainer/LayoutHorizontal/ColunaEsquerda/DeckBox/MarginContainer/ButtonDecks

# -----------------------------------------------------------------------------
# REFERÊNCIAS DOS NÓS — POPUP MULTIPLAYER
# -----------------------------------------------------------------------------
@onready var popup_multiplayer : Control  = $Multiplayer
@onready var button_fechar     : Button   = $Multiplayer/CenterContainer/PainelConexao/Margin/Vbox/Header/ButtonFechar
@onready var button_host       : Button   = $Multiplayer/CenterContainer/PainelConexao/Margin/Vbox/ButtonHost
@onready var ip_input          : LineEdit = $Multiplayer/CenterContainer/PainelConexao/Margin/Vbox/IPInput
@onready var button_join       : Button   = $Multiplayer/CenterContainer/PainelConexao/Margin/Vbox/ButtonJoin

# -----------------------------------------------------------------------------
# REFERÊNCIAS DOS NÓS — PERFIL DO JOGADOR
# -----------------------------------------------------------------------------
@onready var avatar      : Panel = $MarginContainer/LayoutHorizontal/ColunaEsquerda/PerfilHeader/HBoxContainer/Avatar
@onready var label_titulo: Label = $MarginContainer/LayoutHorizontal/ColunaEsquerda/PerfilHeader/HBoxContainer/TextosPerfil/Titulo
@onready var label_nome  : Label = $MarginContainer/LayoutHorizontal/ColunaEsquerda/PerfilHeader/HBoxContainer/TextosPerfil/Nome
@onready var label_rank  : Label = $MarginContainer/LayoutHorizontal/ColunaEsquerda/PerfilHeader/HBoxContainer/TextosPerfil/Rank

# -----------------------------------------------------------------------------
# REFERÊNCIAS DOS NÓS — ESTATÍSTICAS
# -----------------------------------------------------------------------------
@onready var valor_vitorias    : Label = $MarginContainer/LayoutHorizontal/ColunaEsquerda/EstatisticasBox/MarginContainer/StatusList/VitoriasBox/valor
@onready var valor_derrotas    : Label = $MarginContainer/LayoutHorizontal/ColunaEsquerda/EstatisticasBox/MarginContainer/StatusList/DerrotaBox/valor
@onready var valor_taxa        : Label = $MarginContainer/LayoutHorizontal/ColunaEsquerda/EstatisticasBox/MarginContainer/StatusList/Vitorias_Box/valor
@onready var valor_colecao     : Label = $MarginContainer/LayoutHorizontal/ColunaEsquerda/EstatisticasBox/MarginContainer/StatusList/ColecaoBox/valor


# -----------------------------------------------------------------------------
# INICIALIZAÇÃO
# -----------------------------------------------------------------------------
func _ready() -> void:
	_conectar_botoes()
	_carregar_perfil()
	_carregar_estatisticas()


func _conectar_botoes() -> void:
	# Navegação principal
	button_voltar.pressed.connect(_on_voltar_pressed)
	button_historia.pressed.connect(_on_historia_pressed)
	button_multiplayer.pressed.connect(_on_multiplayer_pressed)
	button_treinamento.pressed.connect(_on_treinamento_pressed)
	button_colecao.pressed.connect(_on_colecao_pressed)
	button_decks.pressed.connect(_on_decks_pressed)

	# Popup Multiplayer
	button_fechar.pressed.connect(_on_fechar_popup_pressed)
	button_host.pressed.connect(_on_hospedar_pressed)
	button_join.pressed.connect(_on_conectar_pressed)


# -----------------------------------------------------------------------------
# PERFIL E ESTATÍSTICAS
# -----------------------------------------------------------------------------
func _carregar_perfil() -> void:
	# Por enquanto os textos ficam como estão na cena.
	# Quando o sistema de perfil for desenvolvido, substituir pelos dados reais:
	# label_titulo.text = GameState.perfil.titulo
	# label_nome.text   = GameState.perfil.nome
	# label_rank.text   = GameState.perfil.rank
	pass


func _carregar_estatisticas() -> void:
	# Quando o sistema de persistência for desenvolvido, carregar os dados reais:
	# var stats = GameState.obter_estatisticas()
	# valor_vitorias.text = str(stats.get("vitorias", 0))
	# valor_derrotas.text = str(stats.get("derrotas", 0))
	# valor_colecao.text  = "%d/%d" % [stats.get("cartas_obtidas", 0), CardDatabase.total_cartas()]
	#
	# Taxa de vitória: evita divisão por zero
	# var total = stats.get("vitorias", 0) + stats.get("derrotas", 0)
	# var taxa  = (float(stats.get("vitorias", 0)) / total * 100.0) if total > 0 else 0.0
	# valor_taxa.text = "%.1f%%" % taxa
	pass


# -----------------------------------------------------------------------------
# HANDLERS — NAVEGAÇÃO PRINCIPAL
# -----------------------------------------------------------------------------
func _on_voltar_pressed() -> void:
	get_tree().change_scene_to_file(CENA_MENU_PRINCIPAL)


func _on_historia_pressed() -> void:
	get_tree().change_scene_to_file(CENA_HISTORIA)


func _on_treinamento_pressed() -> void:
	get_tree().change_scene_to_file(CENA_TREINAMENTO)


func _on_colecao_pressed() -> void:
	get_tree().change_scene_to_file(CENA_COLECAO)


func _on_decks_pressed() -> void:
	get_tree().change_scene_to_file(CENA_GERENCIAR_DECKS)


# -----------------------------------------------------------------------------
# HANDLERS — POPUP MULTIPLAYER
# -----------------------------------------------------------------------------
func _on_multiplayer_pressed() -> void:
	popup_multiplayer.visible = true


func _on_fechar_popup_pressed() -> void:
	popup_multiplayer.visible = false


func _on_hospedar_pressed() -> void:
	# TODO: implementar criação de sessão LAN quando a cena de sala de espera existir
	# NetworkManager.criar_sessao()
	# get_tree().change_scene_to_file(CENA_SALA_ESPERA)
	push_warning("Lobby: Hospedar ainda não implementado — aguardando cena de sala de espera.")


func _on_conectar_pressed() -> void:
	var ip := ip_input.text.strip_edges()

	if ip.is_empty():
		push_warning("Lobby: IP não informado.")
		# TODO: exibir feedback visual para o jogador (ex: bordas vermelhas no LineEdit)
		return

	# TODO: implementar conexão LAN
	# NetworkManager.conectar_a(ip)
	# get_tree().change_scene_to_file(CENA_SALA_ESPERA)
	push_warning("Lobby: Conectar ainda não implementado — IP recebido: %s" % ip)
