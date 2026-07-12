class_name CardBaseResource
extends Resource
# ==================================================
# Campos comuns a QUALQUER carta jogável (Animal ou Efeito).
# CardResource (Animal) e EffectResource (Energia/Vestígio/
# Cataclismo/Território) estendem esta classe.
#
# Existe para que sistemas que precisam tratar "qualquer carta"
# de forma uniforme (CardDatabase, DeckBuilder, Deck) usem
# Array[CardBaseResource] com tipagem forte, em vez de afrouxar
# tudo pra Resource genérico ou duplicar a mesma checagem de tipo
# em uma dezena de lugares.
# ==================================================

@export var id: String = ""
@export var name: String = ""
@export var super_type: String = ""
@export_multiline var text_ui: String = ""
