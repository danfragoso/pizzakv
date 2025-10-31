# Desafio Técnico: Banco de Dados Key-Value para Pizzaria Bate-Papo

## 📋 Visão Geral

- Desenvolvimento de um banco de dados key-value com persistencia com operações via TCP


## 🎯 Requisitos Principais


Operações via TCP


COMANDOS:
- read <key>          → Retorna valor ou erro
- write <key>|<value> → Retorna bool (sucesso/falha)
- delete <key>        → Retorna bool (sucesso/falha)
- status             → Retorna uint (métricas do sistema)

- 70% chaves pequenas (<= 1KB)
- 20% chaves médias (1KB - 10KB) 
- 10% chaves grandes (10KB - 100KB)
- Padrão de acesso: 80/20 (80% das consultas em 20% dos dados)


### Critérios de Avaliação

1. Velocidade de Escrita (prioridade alta)
2. Velocidade de Leitura (prioridade alta)
3. Tamanho do Armazenamento (prioridade média)
4. Persistência e Recuperação (crítico)


### 📊 Métricas Expandidas
| Métrica              | Descrição                               |
|----------------------|-----------------------------------------|
| Throughput Escrita   | Operações de escrita por segundo        |
| Throughput Leitura   | Operações de leitura por segundo        |
| Latência P95 Escrita | 95º percentil de latência               |
| Latência P95 Leitura | 95º percentil de latência               |
| Tempo de Recuperação | Tempo para recuperar dados após restart |


### 💾 Métricas de Armazenamento
| Métrica                   | Descrição                          |
|---------------------------|------------------------------------|
| Overhead de Armazenamento | <15% do tamanho dos dados          |
| Taxa de Compactação       | Eficiência na compactação de dados |
| Fragmentação              | Percentual de espaço desperdiçado  |


### 🛡️ Métricas de Confiabilidade
| Métrica                | Descrição                           |
|------------------------|-------------------------------------|
| Durabilidade dos Dados | Garantia de persistência após write |
| Consistência em Falhas | Integridade após kill -9            |
| Log de Operações       | Rastreabilidade das operações       |
