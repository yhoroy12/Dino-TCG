class_name PlayerState
extends RefCounted

var id : int

# Deck

var deck : Array[CardResource] = []
var mao : Array[CardResource] = []
var descarte : Array[CardResource] = []

# Campo

var ativo : AnimalInstance = null

var banco : Array[AnimalInstance] = []

# Recursos

var comida_disponivel : int = 0

# Controle

var venceu := false
var derrotado := false
