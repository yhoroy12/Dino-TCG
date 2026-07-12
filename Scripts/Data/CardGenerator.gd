extends Node
# ==================================================
# Nome: CardImporterButton
# Categoria: Ferramenta de desenvolvimento (não faz parte do jogo em runtime)
#
# Lê os 3 CSVs de dados (animais, efeitos, habilidades) e gera um
# arquivo .tres por linha, já roteado para a pasta certa.
#
# COMO USAR:
# 1. Exporte animais_profissional, efeitos_profissional e
#    habilidade_profissional como CSV de verdade (não .xlsx!) — no
#    Excel/Sheets: Arquivo > Baixar/Salvar como > CSV (UTF-8).
# 2. Coloque os 3 .csv na pasta apontada pelas constantes abaixo
#    (ajuste os caminhos se a sua pasta for diferente).
# 3. Anexe este script a um nó na sua cena de importação.
# 4. Conecte o sinal "pressed" de um Button à função importar_tudo()
#    pelo painel de Sinais do editor.
# 5. Rode a cena a partir do EDITOR (Play) e clique no botão.
#    ResourceSaver.save() só grava em res:// nesse contexto — não
#    funciona num build exportado do jogo. É ferramenta de dev.
# ==================================================

const CSV_ANIMAIS := "B:/GameDev/DINO TCG GAME/Dinogame/Prehistoric TCG/animais_profissional.csv"
const CSV_EFEITOS := "B:/GameDev/DINO TCG GAME/Dinogame/Prehistoric TCG/efeitos_profissional.csv"
const CSV_HABILIDADES := "B:/GameDev/DINO TCG GAME/Dinogame/Prehistoric TCG/habilidade_profissional.csv"

const BASE_CARDS_PATH := "res://Resources/Cards/"
const PATH_HABILIDADES := "res://Resources/Abilities/"

const PASTAS_CARTAS := {
	"animal": BASE_CARDS_PATH + "Animals/",
	"cataclismo": BASE_CARDS_PATH + "Cataclismo/",
	"energia": BASE_CARDS_PATH + "Energies/",
	"territorio": BASE_CARDS_PATH + "Territories/",
	"vestigio": BASE_CARDS_PATH + "Vestigios/",
}


## Ponto de entrada — conecte o Button.pressed a esta função.
func importar_tudo() -> void:
	print("--- INICIANDO IMPORTAÇÃO ---")

	_garantir_pastas()
	_importar_animais()
	_importar_efeitos()
	_importar_habilidades()

	print("--- IMPORTAÇÃO CONCLUÍDA ---")


func _garantir_pastas() -> void:
	for pasta in PASTAS_CARTAS.values():
		DirAccess.make_dir_recursive_absolute(pasta)

	DirAccess.make_dir_recursive_absolute(PATH_HABILIDADES)


func _importar_animais() -> void:
	var linhas := _ler_csv(CSV_ANIMAIS)

	if linhas.is_empty():
		return

	var headers: PackedStringArray = linhas[0]
	var total := 0

	for i in range(1, linhas.size()):
		var linha: PackedStringArray = linhas[i]

		if linha.is_empty() or linha[0] == "":
			continue

		var carta := CardResource.new()
		_preencher_recurso(carta, headers, linha)

		var destino: String = PASTAS_CARTAS.get("animal", BASE_CARDS_PATH)
		_salvar_recurso(carta, destino, carta.id, carta.name)
		total += 1

	print("Animais importados: ", total)


func _importar_efeitos() -> void:
	var linhas := _ler_csv(CSV_EFEITOS)

	if linhas.is_empty():
		return

	var headers: PackedStringArray = linhas[0]
	var total := 0

	for i in range(1, linhas.size()):
		var linha: PackedStringArray = linhas[i]

		if linha.is_empty() or linha[0] == "":
			continue

		var efeito := EffectResource.new()
		_preencher_recurso(efeito, headers, linha)

		if not PASTAS_CARTAS.has(efeito.super_type):
			push_warning("CardImporterButton: super_type desconhecido '%s' na carta %s — pulando." % [efeito.super_type, efeito.id])
			continue

		var destino: String = PASTAS_CARTAS[efeito.super_type]
		_salvar_recurso(efeito, destino, efeito.id, efeito.name)
		total += 1

	print("Efeitos importados: ", total)


func _importar_habilidades() -> void:
	var linhas := _ler_csv(CSV_HABILIDADES)

	if linhas.is_empty():
		return

	var headers: PackedStringArray = linhas[0]
	var total := 0

	for i in range(1, linhas.size()):
		var linha: PackedStringArray = linhas[i]

		if linha.is_empty() or linha[0] == "":
			continue

		var habilidade := AbilityResource.new()
		_preencher_recurso(habilidade, headers, linha)

		_salvar_recurso(habilidade, PATH_HABILIDADES, habilidade.id, habilidade.name)
		total += 1

	print("Habilidades importadas: ", total)


# ==================================================
# HELPERS
# ==================================================

func _ler_csv(caminho: String) -> Array:
	if not FileAccess.file_exists(caminho):
		push_error("CardImporterButton: arquivo não encontrado: %s (lembre de exportar como CSV, não xlsx)" % caminho)
		return []

	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	var linhas: Array = []

	while not arquivo.eof_reached():
		var linha := arquivo.get_csv_line()

		if linha.size() == 1 and linha[0] == "":
			continue

		linhas.append(linha)

	return linhas


## Preenche as propriedades de "recurso" cujo nome bate com o header
## do CSV. Converte para int/float automaticamente quando a
## propriedade já nasce numérica no Resource; o resto vira String.
func _preencher_recurso(
	recurso: Resource,
	headers: PackedStringArray,
	linha: PackedStringArray
) -> void:

	for i in range(headers.size()):
		if i >= linha.size():
			continue

		var campo: String = headers[i].strip_edges()

		if not (campo in recurso):
			continue

		var valor_bruto: String = linha[i].strip_edges()
		var valor_atual = recurso.get(campo)

		if valor_atual is int:
			if valor_bruto.is_valid_float():
				recurso.set(campo, int(round(valor_bruto.to_float())))
		elif valor_atual is float:
			if valor_bruto.is_valid_float():
				recurso.set(campo, valor_bruto.to_float())
		else:
			recurso.set(campo, valor_bruto)


func _salvar_recurso(
	recurso: Resource,
	pasta_destino: String,
	id: String,
	nome: String
) -> void:

	var nome_seguro: String = nome.validate_filename()

	if nome_seguro == "":
		nome_seguro = id

	var caminho_final: String = pasta_destino + id + "_" + nome_seguro + ".tres"
	var erro: int = ResourceSaver.save(recurso, caminho_final)

	if erro != OK:
		push_error("CardImporterButton: falha ao salvar %s (erro %s)" % [caminho_final, erro])


func _on_pressed():
	importar_tudo()
