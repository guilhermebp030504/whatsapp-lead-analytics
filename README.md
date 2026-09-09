# 📊 WhatsApp Lead Analytics

> Pipeline de dados para transformar etiquetas operacionais do WhatsApp em histórico estruturado e indicadores de acompanhamento de leads.

![Status](https://img.shields.io/badge/status-concluído-brightgreen)
![n8n](https://img.shields.io/badge/n8n-ETL-orange)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-database-336791)
![Metabase](https://img.shields.io/badge/Metabase-BI-509EE3)
![Docker](https://img.shields.io/badge/Docker-containerization-2496ED)

---

## 🎯 Sobre o projeto

Este projeto nasceu de uma necessidade simples:

**Como transformar a utilização operacional de etiquetas no WhatsApp em dados históricos que possam ser analisados?**

Em muitos processos comerciais, o WhatsApp acaba sendo utilizado como uma ferramenta de acompanhamento de leads, enquanto as informações sobre cada contato ficam restritas ao estado atual da operação.

Neste projeto, as etiquetas utilizadas no WhatsApp são tratadas como **etapas operacionais de um funil comercial**.

Exemplo:

```text
Novo Lead
    ↓
Em Atendimento
    ↓
Qualificado
```

A solução realiza periodicamente a coleta dessas informações, estrutura os dados em PostgreSQL e disponibiliza uma camada de análise através do Metabase.

O resultado é a transformação de um dado operacional em uma **base histórica para análise de processos e indicadores**.

---

## 🏗️ Arquitetura

```text
┌───────────────┐
│   WhatsApp    │
│               │
│    Labels     │
└───────┬───────┘
        │
        ▼
┌───────────────┐
│     WAHA      │
│               │
│  WhatsApp API │
└───────┬───────┘
        │
        │ HTTP / API
        ▼
┌───────────────┐
│     n8n       │
│               │
│   ETL / Sync  │
└───────┬───────┘
        │
        │ SQL
        ▼
┌───────────────┐
│  PostgreSQL   │
│               │
│ Dados atuais  │
│ + Histórico   │
└───────┬───────┘
        │
        │
        ▼
┌───────────────┐
│   Metabase    │
│               │
│      BI       │
└───────────────┘
```

### Fluxo

1. O WhatsApp é utilizado normalmente para operação dos leads.
2. Os contatos são organizados através de etiquetas.
3. O WAHA disponibiliza essas informações através de API.
4. O n8n executa a sincronização em intervalos configurados.
5. Os dados são normalizados e enviados para o PostgreSQL.
6. Os contatos são atualizados na tabela principal.
7. Cada sincronização gera um registro histórico.
8. O Metabase utiliza o PostgreSQL como fonte para os indicadores.

---

## 🧩 Tecnologias utilizadas

| Tecnologia          | Função                                         |
| ------------------- | ---------------------------------------------- |
| **n8n**             | Orquestração e automação do pipeline           |
| **WAHA**            | Integração com o WhatsApp                      |
| **PostgreSQL**      | Persistência e histórico dos dados             |
| **Metabase**        | Dashboards e análise dos indicadores           |
| **Docker**          | Containerização dos serviços                   |
| **Portainer**       | Gerenciamento dos containers                   |
| **SQL**             | Modelagem, consultas e transformação dos dados |
| **HTTP / REST API** | Comunicação entre os serviços                  |

---

## ⚙️ Pipeline de ETL

O workflow do n8n funciona como uma pequena pipeline de dados.

### 1. Extração

O n8n consulta periodicamente as etiquetas configuradas no WAHA.

Exemplo:

```http
GET /api/default/labels/{label_id}/chats
```

Cada etiqueta representa uma etapa operacional do processo.

---

### 2. Normalização

Os dados retornados pela API são transformados para um formato padronizado:

```json
{
  "chat_id": "109947471818969@lid",
  "name": "Pedro (Peu)",
  "label_id": "9"
}
```

Um ponto importante da implementação foi preservar o identificador retornado pelo WhatsApp/WAHA.

O campo:

```text
id._serialized
```

é utilizado como identificador do contato.

Isso permite trabalhar tanto com identificadores no formato `@lid` quanto com outros formatos retornados pela plataforma, sem assumir que o contato necessariamente estará associado a um número no formato tradicional.

---

### 3. Carga dos contatos

Os dados são armazenados na tabela `contacts`.

O processo utiliza `UPSERT` para manter o cadastro atual do contato:

```sql
INSERT INTO contacts (
    chat_id,
    name,
    updated_at
)
VALUES (
    $1,
    $2,
    NOW()
)
ON CONFLICT (chat_id)
DO UPDATE SET
    name = COALESCE(EXCLUDED.name, contacts.name),
    updated_at = NOW();
```

Dessa forma, cada contato possui um registro único na tabela principal.

---

### 4. Histórico

Além do estado atual, cada sincronização gera um registro em `contact_history`.

```sql
INSERT INTO contact_history (
    chat_id,
    name,
    label_id,
    observed_at
)
VALUES (
    $1,
    $2,
    $3,
    NOW()
);
```

Essa separação permite trabalhar com dois conceitos diferentes:

```text
contacts
    ↓
Estado atual

contact_history
    ↓
Evolução ao longo do tempo
```

Essa decisão é importante para o BI, pois permite analisar não apenas **onde o lead está**, mas também **como ele evoluiu**.

---

# 🗄️ Modelagem de dados

## `contacts`

Tabela responsável pelo estado atual dos contatos.

```text
contacts
├── id
├── chat_id
├── name
├── created_at
└── updated_at
```

O campo `chat_id` possui restrição de unicidade.

---

## `contact_history`

Tabela responsável pelo histórico das observações.

```text
contact_history
├── id
├── chat_id
├── name
├── label_id
└── observed_at
```

A tabela permite reconstruir a evolução dos contatos ao longo do tempo.

---

## 🔎 Views para BI

Para facilitar a construção dos dashboards, foram criadas consultas/views específicas para análise.

### Leads atuais

A view identifica o registro mais recente de cada contato.

```sql
SELECT DISTINCT ON (h.chat_id)
    h.chat_id,
    h.name,
    h.label_id,
    h.observed_at
FROM contact_history h
ORDER BY h.chat_id, h.observed_at DESC;
```

---

### Histórico de evolução

Também é possível utilizar funções de janela para comparar estados anteriores:

```sql
LAG(h.label_id) OVER (
    PARTITION BY h.chat_id
    ORDER BY h.observed_at
)
```

Isso permite identificar mudanças de etapa ao longo do tempo.

---

# 📊 Dashboard

O Metabase é utilizado como camada de visualização do projeto.

O dashboard foi pensado para responder perguntas como:

* Quantos leads existem atualmente?
* Como os leads estão distribuídos entre as etapas?
* Quantos novos leads surgiram ao longo do tempo?
* Como o volume de leads por etapa está evoluindo?
* Quais contatos estão atualmente em cada etapa?
* Como os leads estão avançando no funil?

### Indicadores

```text
┌─────────────────┐ ┌─────────────────┐
│   Total Leads   │ │  Novos Leads    │
└─────────────────┘ └─────────────────┘

┌─────────────────┐ ┌────────────────────────┐
│ Funil de Vendas │ │ Distribuição por etapa │
└─────────────────┘ └────────────────────────┘

┌─────────────────────────────────────────┐
│            Evolução de leads            │
└─────────────────────────────────────────┘
```

---

# 🔄 Exemplo de evolução

Um lead pode apresentar uma sequência como:

```text
06/09
Novo Lead
    │
    ▼
07/09
Em Atendimento
    │
    ▼
08/09
Qualificado
```

Com o histórico armazenado no PostgreSQL, essa evolução deixa de ser apenas uma informação visual no WhatsApp e passa a ser um dado que pode ser consultado e analisado.

---

# 🧠 Decisões técnicas

## PostgreSQL como camada histórica

O PostgreSQL foi utilizado não apenas como banco de dados, mas como uma camada de persistência para permitir análises temporais.

A separação entre estado atual e histórico facilita diferentes tipos de consulta.

---

## Snapshot periódico

O projeto utiliza sincronização periódica.

A cada execução do workflow, o estado observado no WhatsApp é registrado no histórico.

Essa abordagem mantém a implementação simples e permite construir análises temporais sem armazenar o conteúdo das conversas.

---

## Sem armazenamento de mensagens

O projeto não tem como objetivo armazenar o conteúdo das conversas.

São utilizados apenas os dados necessários para o acompanhamento analítico:

```text
Contato
Nome
Etiqueta
Data/hora da observação
```

Isso mantém o escopo focado em **processo, dados e indicadores**.

---

## WhatsApp como operação e BI como análise

Uma decisão importante foi não transformar o projeto em um CRM completo.

O conceito é:

```text
WhatsApp
   ↓
Operação

PostgreSQL
   ↓
Histórico

Metabase
   ↓
Análise
```

Assim, cada ferramenta possui uma responsabilidade clara.

---

# 🔐 Segurança

Informações sensíveis não fazem parte do repositório.

O projeto não deve versionar:

```text
.env
API Keys
Senhas
Credenciais do n8n
Sessões do WhatsApp
Cookies
Banco de dados real
Dados reais de clientes
Conteúdo de mensagens
```

As credenciais devem ser configuradas localmente através das variáveis de ambiente ou das credenciais do próprio n8n.

---

# 🐳 Infraestrutura

Os serviços são executados em containers Docker e podem ser administrados através do Portainer.

Exemplo da infraestrutura:

```text
Docker
│
├── WAHA
│
├── n8n
│
├── PostgreSQL
│
└── Metabase
```

Os containers utilizam uma rede Docker compartilhada para comunicação interna.

Exemplo:

```text
n8n → http://waha:3000
n8n → postgres:5432
metabase → postgres:5432
```

Isso evita depender de `localhost` para comunicação entre containers.

---

# 🚀 Como executar

## Pré-requisitos

Para executar o projeto localmente, são necessários:

* Docker
* Portainer (opcional)
* PostgreSQL
* n8n
* WAHA
* Metabase

---

## 1. Criar a rede Docker

```bash
docker network create backend
```

---

## 2. Configurar PostgreSQL

Criar os bancos necessários:

```text
whatsapp_bi
metabase
```

O banco `whatsapp_bi` contém os dados do projeto.

O banco `metabase` é utilizado internamente pelo próprio Metabase.

---

## 3. Criar as tabelas

Executar os scripts dentro de:

```text
database/
```

na seguinte ordem:

```text
01_tables.sql
02_indexes.sql
03_views.sql
```

O `04_seed.sql` é opcional e serve para dados de demonstração.

---

## 4. Configurar o n8n

Importar:

```text
n8n/whatsapp-label-sync.json
```

Depois configurar:

* URL do WAHA
* API Key
* sessão do WhatsApp
* conexão PostgreSQL
* IDs das etiquetas

---

## 5. Configurar o Metabase

O Metabase deve apontar para o PostgreSQL:

```text
Host: postgres
Port: 5432
Database: whatsapp_bi
```

A interface web pode ser disponibilizada em uma porta do host, por exemplo:

```text
http://localhost:3001
```

---

# 📈 Possíveis evoluções

O projeto foi mantido propositalmente simples, mas sua arquitetura permite evoluções futuras.

### Próximos passos possíveis

* ⏱️ Tempo médio por etapa
* 🎯 Taxa de conversão entre etapas
* 🔄 Identificação de mudanças de etapa
* 📊 Indicadores de SLA
* 📅 Análise por período
* 👥 Distribuição por responsável
* 🔔 Alertas para leads parados
* 🏢 Integração com CRM/ERP
* 📱 Integração com outros canais
* ⚡ Processamento orientado a eventos

---

# 💼 O que este projeto demonstra

Este projeto demonstra conhecimentos práticos em:

```text
Automação de Processos
        ↓
Integração de APIs
        ↓
ETL
        ↓
Modelagem de Dados
        ↓
PostgreSQL / SQL
        ↓
Histórico de Processos
        ↓
Business Intelligence
        ↓
Docker / Containers
```

Além da implementação técnica, o projeto trabalha um conceito importante:

> **Transformar uma operação manual em uma fonte estruturada de dados para tomada de decisão.**

---

# 🎓 Principais conceitos aplicados

* Process Automation
* BPM
* ETL
* REST APIs
* Data Integration
* Data Modeling
* PostgreSQL
* SQL
* Window Functions
* Historical Data
* Business Intelligence
* Data Analytics
* Docker
* Container Networking
* Workflow Automation

---

# ⚠️ Observação

Este projeto possui finalidade **educacional e de portfólio**.

A integração com WhatsApp utiliza WAHA como camada de acesso à plataforma. Para ambientes produtivos, é importante avaliar os requisitos, políticas e alternativas oficiais de integração disponibilizadas pelo WhatsApp/Meta.

---

# 👨‍💻 Autor

**Guilherme Brito Pizzollo**

Especialista em Automação de Processos (BPM)
Integração de ERPs, APIs e SQL
Node.js & PostgreSQL

---

⭐ Se este projeto foi útil ou interessante, considere deixar uma estrela no repositório.
