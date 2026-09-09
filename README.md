# WhatsApp Lead Analytics

Pipeline de dados para sincronização periódica de leads classificados
por etiquetas do WhatsApp, utilizando WAHA, n8n, PostgreSQL e Metabase.

## Arquitetura

WhatsApp
   ↓
WAHA
   ↓
n8n
   ↓
PostgreSQL
   ↓
Metabase

## Objetivo

Transformar a classificação operacional dos contatos no WhatsApp
em dados históricos para análise de funil comercial.

## Tecnologias

- WAHA
- n8n
- PostgreSQL
- Metabase
- Docker
- Portainer

## Funcionamento

A cada X horas, o workflow:

1. Consulta os chats associados às labels configuradas.
2. Obtém `id._serialized` e nome do contato.
3. Atualiza a tabela `contacts`.
4. Registra a situação do contato em `contact_history`.
5. O PostgreSQL mantém o histórico para análise temporal.
6. O Metabase utiliza os dados para construção dos dashboards.

## Indicadores

- Total de leads
- Leads por etapa
- Novos leads
- Evolução do funil
- Distribuição por etapa
- Histórico de movimentação
- Conversão entre etapas
- Tempo entre etapas

## Estrutura

...
