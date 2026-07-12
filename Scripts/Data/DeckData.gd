extends Resource
class_name DeckData

# ==============================================================================
# DeckData — Objeto de Dados do Baralho (core/data/DeckData.gd)
# ==============================================================================

@export var id: String = ""
@export var nome: String = "Novo Deck"
@export var ativo: bool = false
@export var capa: String = ""
@export var vitorias: int = 0
@export var derrotas: int = 0

## Lista plana de cartas que compõem o deck atualmente. CardBaseResource
## (não CardResource) porque um deck pode conter Animal (CardResource) E
## Energia/Vestígio/Cataclismo/Território (EffectResource) ao mesmo tempo.
@export var cartas: Array[CardBaseResource] = []


## Retorna o dicionário serializado pronto para ser salvo em JSON
func para_dicionario() -> Dictionary:
	var agrupado: Dictionary = {}
	for carta in cartas:
		if carta and carta.id.strip_edges() != "":
			agrupado[carta.id] = agrupado.get(carta.id, 0) + 1

	var colecao_array: Array = []
	for card_id in agrupado:
		colecao_array.append({
			"id": card_id,
			"quantidade": agrupado[card_id]
		})

	return {
		"id": id,
		"nome": nome,
		"ativo": ativo,
		"capa": capa,
		"vitorias": vitorias,
		"derrotas": derrotas,
		"colecao": colecao_array
	}


## Popula este resource a partir de um dicionário vindo do JSON.
## Usa CardDatabase.obter_qualquer() (não obter_carta()) porque a
## coleção salva pode referenciar tanto CardResource quanto
## EffectResource — obter_carta() só resolve CardResource e faria
## qualquer carta de Efeito salva no deck sumir silenciosamente ao
## recarregar.
func de_dicionario(dados: Dictionary) -> void:
	id = dados.get("id", "")
	nome = dados.get("nome", "Novo Deck")
	ativo = dados.get("ativo", false)
	capa = dados.get("capa", "")
	vitorias = dados.get("vitorias", 0)
	derrotas = dados.get("derrotas", 0)
	cartas.clear()

	var colecao = dados.get("colecao", [])
	for entrada in colecao:
		var card_id = str(entrada.get("id", ""))
		var qtd = int(entrada.get("quantidade", 0))
		var recurso_base: CardBaseResource = CardDatabase.obter_qualquer(card_id)

		if recurso_base:
			for i in range(qtd):
				cartas.append(recurso_base.duplicate() as CardBaseResource)
		else:
			push_error("DeckData: Carta ID não encontrada no banco de dados: " + card_id)
