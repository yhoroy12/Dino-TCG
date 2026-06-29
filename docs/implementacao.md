# 🦖 Dino TCG — Estado de Implementação

Última atualização: Junho de 2026

---

# Sistema de Dados

| Sistema                       | Status         |
| ----------------------------- | -------------- |
| CardResource                  | ✅ Implementado |
| AbilityResource               | ✅ Implementado |
| Banco de Cartas (.tres)       | ✅ Implementado |
| Banco de Habilidades (.tres)  | ✅ Implementado |
| Carregamento Dinâmico         | ✅ Implementado |
| Integração Carta ↔ Habilidade | ✅ Implementado |
| Sistema Data Driven           | ✅ Implementado |

---

# Sistema de Cartas

| Sistema              | Status         |
| -------------------- | -------------- |
| Cartas de Animal     | ✅ Implementado |
| Cartas de Energia    | ✅ Implementado |
| Cartas de Vestígio   | ⚠️ Parcial     |
| Cartas de Cataclismo | ⚠️ Parcial     |
| Cartas de Território | ⚠️ Parcial     |
| Templates Visuais    | ✅ Implementado |
| Zoom de Cartas       | ✅ Implementado |

---

# Sistema de Habilidades

| Sistema                                | Status         |
| -------------------------------------- | -------------- |
| AbilityResource                        | ✅ Implementado |
| Gatilhos (Triggers)                    | ✅ Implementado |
| Condições (Conditions)                 | ✅ Implementado |
| Ações (Actions)                        | ✅ Implementado |
| Alvos (Targets)                        | ✅ Implementado |
| Quantidades (Quantities)               | ✅ Implementado |
| Interpretação pelo BattleManager       | ⚠️ Parcial     |
| Biblioteca Reutilizável de Habilidades | ✅ Implementado |

---

# Deck Builder

| Sistema                       | Status         |
| ----------------------------- | -------------- |
| Criar Deck                    | ✅ Implementado |
| Salvar Deck                   | ✅ Implementado |
| Carregar Deck                 | ✅ Implementado |
| Exclusão de Decks             | ✅ Implementado |
| Validação de 60 Cartas        | ✅ Implementado |
| Limite de 4 Cópias            | ✅ Implementado |
| Energias Ilimitadas           | ✅ Implementado |
| Validação de Bebê Obrigatório | ✅ Implementado |
| Preview de Cartas             | ✅ Implementado |
| Zoom de Cartas                | ✅ Implementado |

---

# Setup da Partida

| Sistema                     | Status             |
| --------------------------- | ------------------ |
| Compra Inicial              | ⚠️ Parcial         |
| Embaralhamento              | ⚠️ Parcial         |
| Escolha de Animal Ativo     | ❓ Não Validado     |
| Banco Inicial               | ❓ Não Validado     |
| Mulligan                    | ❌ Não Implementado |
| Sorteio de Primeiro Jogador | ❌ Não Implementado |

---

# Sistema de Turnos

| Sistema                   | Status         |
| ------------------------- | -------------- |
| Controle de Turnos        | ✅ Implementado |
| Troca de Jogador Ativo    | ✅ Implementado |
| Compra de Carta por Turno | ✅ Implementado |
| Controle de Fases         | ⚠️ Parcial     |
| Encerramento de Turno     | ⚠️ Parcial     |

---

# Sistema de Comida

| Sistema                      | Status             |
| ---------------------------- | ------------------ |
| Recurso Global de Comida     | ✅ Implementado     |
| Distribuição de Comida       | ✅ Implementado     |
| Comida Individual por Animal | ✅ Implementado |
| Consumo Automático           | ✅ Implementado |
| Nocaute por Fome             | ✅ Implementado |

---

# Evolução

| Sistema                     | Status         |
| --------------------------- | -------------- |
| Evolução Filhote → Jovem    | ✅ Implementado |
| Evolução Jovem → Adulto     | ✅ Implementado |
| Evoluções Diretas Especiais | ✅ Implementado |
| Validação por Comida        | ✅ Implementado |

---

# Sistema de Energia

| Sistema                      | Status           |
| ---------------------------- | ---------------- |
| Cartas de Energia            | ✅ Implementado |
| Energias Anexadas            | ✅ Implementado |
| Controle de Energias Ligadas | ✅ Implementado |
| Pagamento de Custos          | ✅ Implementado |

---

# Sistema de Combate

| Sistema                  | Status     |
| ------------------------ | ---------- |
| Declaração de Ataque     | ✅ Implementado |
| Cálculo de Dano Base     | ✅ Implementado |
| Aplicação de Dano        | ✅ Implementado |
| Fraqueza                 | ⚠️ Parcial |
| Resistência              | ⚠️ Parcial |
| Interpretação de Efeitos | ⚠️ Parcial |
| Nocaute por Dano         | ✅ Implementado |

---

# Sistema de Recuo

| Sistema                  | Status         |
| ------------------------ | -------------- |
| Troca do Animal Ativo    | ✅ Implementado |
| Pagamento de Energia     | ✅ Implementado |
| Pagamento por Comida     | ✅ Implementado |
| Sistema Híbrido de Recuo | ✅ Implementado |

---

# Condições Especiais

| Sistema                      | Status     |
| ---------------------------- | ---------- |
| Sono                         | ⚠️ Parcial |
| Paralisia                    | ⚠️ Parcial |
| Envenenamento                | ⚠️ Parcial |
| Sangramento                  | ⚠️ Parcial |
| Remoção Automática de Status | ⚠️ Parcial |

---

# Cartas Especiais

| Sistema           | Status         |
| ----------------- | -------------- |
| Vestígios         | ⚠️ Parcial     |
| Cataclismos       | ⚠️ Parcial     |
| Territórios       | ⚠️ Parcial     |
| Efeitos Contínuos | ❌ Não Validado |

---

# Interface

| Sistema                      | Status         |
| ---------------------------- | -------------- |
| Menu Principal               | ✅ Implementado |
| Deck Builder                 | ✅ Implementado |
| Arena de Batalha             | ⚠️ Parcial     |
| Atualização Visual de Cartas | ✅ Implementado |
| Sistema de Zoom              | ✅ Implementado |

---

# Condições de Vitória

| Sistema                 | Status             |
| ----------------------- | ------------------ |
| Vitória por 4 Nocautes  | ❌ Não Validado    |
| Vitória por Campo Vazio | ❌ Não Validado    |
| Vitória por Deck Out    | ❌ Não Validado    |
| Empate                  | ❌ Não Implementado|

---

# Estado Geral do Projeto

## Infraestrutura

✅ Avançada

* Arquitetura baseada em Resources
* Sistema Data Driven
* Deck Builder funcional
* Banco de cartas funcional
* Banco de habilidades funcional

## Jogabilidade

⚠️ Em desenvolvimento

* Combate parcialmente implementado
* Turnos implementados
* Mecânicas centrais ainda precisam de validação

## Conteúdo

⚠️ Em expansão

* Sistema preparado para novas cartas
* Sistema preparado para novas habilidades
* Expansões futuras facilitadas pela arquitetura atual

---

# Próximas Prioridades

## Prioridade Alta

* Sistema de comida individual por animal
* Sistema de energias anexadas
* Sistema de evolução completo
* Sistema de recuo completo
* Setup oficial da partida

## Prioridade Média

* Finalização do combate
* Condições especiais completas
* Cartas de Território
* Cartas de Vestígio
* Cartas de Cataclismo

## Prioridade Baixa

* IA
* Multiplayer
* Efeitos visuais
* Balanceamento
* Integração Steam
