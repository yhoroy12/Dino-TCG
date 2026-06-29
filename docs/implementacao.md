🦖 Dino TCG — Estado de Implementação
Última atualização: Junho de 2026

Sistema de Dados
SistemaStatusCardResource✅ Implementado
AbilityResource✅ Implementado
Banco de Cartas (.tres)✅ Implementado
Banco de Habilidades (.tres)✅ Implementado
Carregamento Dinâmico✅ Implementado
Integração Carta ↔ Habilidade✅ Implementado
Sistema Data Driven✅ Implementado

Sistema de Cartas
SistemaStatusCartas de Animal✅ Implementado
Cartas de Energia✅ Implementado
Cartas de Vestígio⚠️ Parcial
Cartas de Cataclismo⚠️ Parcial
Cartas de Território⚠️ Parcial
Templates Visuais✅ Implementado
Zoom de Cartas✅ Implementado

Sistema de Habilidades
SistemaStatusAbilityResource✅ Implementado
Gatilhos (Triggers)✅ Implementado
Condições (Conditions)✅ Implementado
Ações (Actions)✅ Implementado
Alvos (Targets)✅ Implementado
Quantidades (Quantities)✅ Implementado
Interpretação pelo BattleManager⚠️ Parcial
Biblioteca Reutilizável de Habilidades✅ Implementado

Deck Builder
SistemaStatusCriar Deck✅ Implementado
Salvar Deck✅ Implementado
Carregar Deck✅ Implementado
Exclusão de Decks✅ Implementado
Validação de 60 Cartas✅ Implementado
Limite de 4 Cópias✅ Implementado
Energias Ilimitadas✅ Implementado
Validação de Filhote Obrigatório✅ Implementado
Preview de Cartas✅ Implementado
Zoom de Cartas✅ Implementado

Setup da Partida
SistemaStatusEmbaralhamento✅ Implementado
Compra Inicial de 7 Cartas✅ Implementado
Sorteio de Primeiro Jogador✅ Implementado
Mulligan Obrigatório✅ Implementado
Cartas Extras por Mulligan✅ Implementado
Escolha de Animal Ativo✅ Implementado
Banco Inicial⚠️ Parcial

Sistema de Turnos
SistemaStatusControle de Turnos✅ Implementado
Troca de Jogador Ativo✅ Implementado
Compra de Carta por Turno✅ Implementado
Controle de Fases⚠️ Parcial
Encerramento de Turno✅ Implementado

Sistema de Comida
SistemaStatusRecurso Global de Comida✅ Implementado
Distribuição de Comida✅ Implementado
Comida Individual por Animal✅ Implementado
Consumo Automático✅ Implementado
Nocaute por Fome✅ Implementado

Evolução
SistemaStatusEvolução Filhote → Jovem✅ Implementado
Evolução Jovem → Adulto✅ Implementado
Evoluções Diretas Especiais✅ Implementado
Validação por Comida✅ Implementado
Preservação de Estado✅ Implementado

Sistema de Energia
SistemaStatusCartas de Energia✅ Implementado
Energias Anexadas no Ativo✅ Implementado
Energias Anexadas no Banco✅ Implementado
Limite de Uma Energia por Turno✅ Implementado
Parser de Custo por Cor✅ Implementado
Validação de Custo Colorido✅ Implementado
Validação de Energia Incolor✅ Implementado
Descarte ao Nocautear✅ Implementado

Sistema de Combate
SistemaStatusDeclaração de Ataque✅ Implementado
Validação de Custo✅ Implementado
Cálculo de Dano Base✅ Implementado
Aplicação de Dano✅ Implementado
Fraqueza⚠️ Parcial
Resistência⚠️ Parcial
Interpretação de Efeitos⚠️ Parcial
Nocaute por Dano✅ Implementado

Sistema de Recuo
SistemaStatusTroca do Animal Ativo✅ Implementado
Recuo Gratuito✅ Implementado
Pagamento por Energia✅ Implementado
Pagamento por Comida✅ Implementado
Sistema Híbrido de Recuo✅ Implementado
Validação de Banco Vazio✅ Implementado

Condições Especiais
SistemaStatusSono⚠️ Parcial
Paralisia⚠️ Parcial
Envenenamento⚠️ Parcial
Sangramento⚠️ Parcial
Remoção Automática de Status⚠️ Parcial

Cartas Especiais
SistemaStatusVestígios⚠️ Parcial
Cataclismos⚠️ Parcial
Territórios⚠️ Parcial
Efeitos Contínuos❌ Não Validado

Interface
SistemaStatusMenu Principal✅ Implementado
Deck Builder✅ Implementado
Arena de Batalha⚠️ Parcial
Atualização Visual de Cartas✅ Implementado
Sistema de Zoom✅ Implementado

Condições de Vitória
SistemaStatusVitória por 4 Nocautes✅ Implementado
Vitória por Campo Vazio❌ Não Validado
Vitória por Deck Out✅ Implementado
Empate✅ Implementado

Estado Geral do Projeto
Infraestrutura
✅ Avançada

Arquitetura baseada em Resources
Sistema Data Driven
Deck Builder funcional
Banco de cartas funcional
Banco de habilidades funcional

Jogabilidade
⚠️ Em desenvolvimento

Core da versão 0.2 implementado no GameState
Setup oficial implementado
Combate parcialmente validado
Condições especiais e cartas especiais pendentes de validação

Conteúdo
⚠️ Em expansão

Sistema preparado para novas cartas
Sistema preparado para novas habilidades
Expansões futuras facilitadas pela arquitetura atual


Próximas Prioridades
Prioridade Alta

Validação completa da Arena de Batalha com o novo GameState
Finalização das condições especiais
Validação das condições de vitória por campo vazio

Prioridade Média

Cartas de Território
Cartas de Vestígio
Cartas de Cataclismo
Fraqueza e Resistência no combate
Interpretação completa de efeitos pelo BattleManager

Prioridade Baixa

IA
Multiplayer LAN
Efeitos visuais
Balanceamento
Integração Steam
