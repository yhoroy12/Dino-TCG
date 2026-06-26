extends Control

# Caminhos recomendados para as suas outras cenas. 
# Ajuste os caminhos abaixo conforme a sua pasta "res://" real.
const CENA_JOGAR = "res://scenes/Lobby/Lobby.tscn"
const CENA_DECK_BUILDER = "res://scenes/DeckBuilder/deckbuilder.tscn"
const CENA_LOJA = ""
const CENA_CONFIGURACOES = ""

# Referências para os nós de botões
@onready var botao_jogar: Button = $CenterContainer/MenuFlow/BotoesContainer/ButtonJogar
@onready var botao_deck: Button = $CenterContainer/MenuFlow/BotoesContainer/ButtonDeck
@onready var botao_loja: Button = $CenterContainer/MenuFlow/BotoesContainer/ButtonLoja
@onready var botao_opcoes: Button = $CenterContainer/MenuFlow/BotoesContainer/ButtonOpcoes
@onready var botao_sair: Button = $CenterContainer/MenuFlow/BotoesContainer/ButtonSair

func _ready() -> void:
	# Conecta os sinais de clique (pressed) de cada botão às suas respectivas funções
	botao_jogar.pressed.connect(_on_botao_jogar_pressed)
	botao_deck.pressed.connect(_on_botao_deck_pressed)
	botao_loja.pressed.connect(_on_botao_loja_pressed)
	botao_opcoes.pressed.connect(_on_botao_opcoes_pressed)
	botao_sair.pressed.connect(_on_botao_sair_pressed)


func _on_botao_jogar_pressed() -> void:
	# Carrega e muda para a cena do tabuleiro TCG
	_mudar_de_cena(CENA_JOGAR)


func _on_botao_deck_pressed() -> void:
	# Redireciona para o montador de decks
	_mudar_de_cena(CENA_DECK_BUILDER)


func _on_botao_loja_pressed() -> void:
	# Abre a loja de boosters/pacotes
	_mudar_de_cena(CENA_LOJA)


func _on_botao_opcoes_pressed() -> void:
	# Abre o menu de configurações de tela/áudio
	_mudar_de_cena(CENA_CONFIGURACOES)


func _on_botao_sair_pressed() -> void:
	# Fecha o aplicativo do jogo (funciona em builds de PC)
	get_tree().quit()


# Função auxiliar segura para fazer a transição se o arquivo da cena existir
func _mudar_de_cena(caminho_cena: String) -> void:
	if ResourceLoader.exists(caminho_cena):
		get_tree().change_scene_to_file(caminho_cena)
	else:
		print("Aviso: A cena em '%s' ainda não foi criada!" % caminho_cena)
