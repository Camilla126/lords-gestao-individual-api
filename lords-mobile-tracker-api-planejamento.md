# Planejamento técnico — API Rails + PostgreSQL (Rastreador individual)

Guia para **aprender enquanto constróis**: o que é cada peça, **em que ordem** fazer, e o **desenho concreto** da base de dados e da API. O **front (Vue)** fica **depois** — só JSON por agora.

**Pré-requisitos no computador:** Ruby (3.2+), Rails (7.x), PostgreSQL a correr, editor de código.

---

## Parte A — Mapa mental: o que é cada coisa no Rails

Imagina a aplicação em **camadas**, de baixo para cima:

| Peça | Analogia simples | O que faz |
|------|------------------|-----------|
| **Base de dados (PostgreSQL)** | Gavetas permanentes | Guarda tabelas (`users`, `snapshots`, …) em disco. |
| **Migration** | “Receita” que cria ou altera uma tabela | Ficheiro Ruby que diz: “cria a tabela `users` com estas colunas”. Corres `rails db:migrate` e o PostgreSQL atualiza. |
| **Model** (`app/models/user.rb`) | Regras + porta de entrada para uma tabela | Liga o código Ruby à tabela `users`; defines validações (`email` obrigatório), associações (`has_many :snapshots`). |
| **Route** (`config/routes.rb`) | Lista de URL → ação | Diz: quando pedires `GET /api/v1/snapshots`, vai ao `SnapshotsController#index`. |
| **Controller** (`app/controllers/...`) | Garçom da API | Recebe o pedido HTTP (JSON), chama o model (ou um service), devolve **resposta JSON** e código HTTP (200, 401, 404…). |
| **Service** (opcional, pasta `app/services/`) | Função grande com nome | Quando a lógica **não cabe bem** só no controller (ex.: relatório semanal com muitos passos), pões numa classe `WeeklyReportService` — fica mais legível e testável. **Não é obrigatório** no primeiro dia; podes começar no controller e extrair depois. |

**Fluxo de um pedido:** `Browser/Postman` → **Router** → **Controller** → **Model** (lê/escreve na BD) → **Controller** → resposta JSON.

**O que criar primeiro (ordem de aprendizagem):**

1. Projeto Rails em modo **API** + PostgreSQL.  
2. **Migrations** das tabelas (estrutura da BD).  
3. **Models** com associações e validações.  
4. **Routes** da API (versão `v1`).  
5. **Controllers** (registo, login, CRUD, relatórios).  
6. **Services** só quando a lógica do relatório começar a “pesar” no controller.

---

## Parte B — Projeto e convenções

### Nome da pasta (sugestão)

`lords-mobile-tracker-api` ou `tracker-api` — à escolha.

### Comando inicial (referência — quando fores criar o projeto)

```bash
rails new lords-mobile-tracker-api --api --database=postgresql
```

- `--api` — Rails **sem** vistas HTML; foco em JSON.  
- `--database=postgresql` — usa PostgreSQL.

### Versão da API

Todas as rotas sob **`/api/v1/`** para no futuro poderes ter `v2` sem partir clientes antigos.

### Autenticação (MVP da API)

- **JWT** (token no header `Authorization: Bearer <token>`): combina bem com **Vue** mais tarde (SPA sem cookies obrigatórios).  
- Na prática: no **login**, devolves um token assinado; nos pedidos seguintes, o controller **decodifica** o token e sabe qual é o `current_user`.

Gemas úteis (instalas no `Gemfile` quando chegares a esse passo):

- `jwt` — criar/validar tokens.  
- `bcrypt` — já vem com Rails para `has_secure_password`.  
- `rack-cors` — permitir que o **Vue** (outro domínio/porta em dev) chame a API.

*(Alternativa: sessões com cookies — mais simples em teoria, mais chatia com SPA; para o teu plano, JWT é adequado.)*

---

## Parte C — Base de dados (schema)

Nomes de tabelas em **inglês**, plural (`users`, `snapshots`, `monster_days`) — convenção Rails.

### Tabela `users`

| Coluna | Tipo PostgreSQL | Notas |
|--------|-----------------|--------|
| `id` | bigint PK | Automático. |
| `email` | string | `unique`, não nulo, índice único. |
| `password_digest` | string | Preenchido por `has_secure_password` (nunca guardes password em texto). |
| `timezone` | string | Ex.: `Europe/Lisbon`, `America/Sao_Paulo` — IANA. |
| `created_at`, `updated_at` | datetime | Automático (`timestamps`). |

Opcional MVP: `display_name` (string, nullable).

### Tabela `snapshots`

| Coluna | Tipo | Notas |
|--------|------|--------|
| `id` | bigint PK | |
| `user_id` | bigint FK → `users.id` | `null: false`, `index: true`, `foreign_key: true`. |
| `recorded_at` | datetime | Quando o jogador diz que mediu o estado (obrigatório). |
| `nickname` | string | |
| `castle_level` | integer | CV. |
| `castle_power` | bigint | “Might” / poder — pode ser número grande. |
| `player_level` | integer | |
| `troops_total` | bigint | |
| `kills_total` | bigint | Acumulado do jogo. |
| `created_at`, `updated_at` | datetime | |

**Índice composto sugerido:** `(user_id, recorded_at)` — acelera listas e relatórios por utilizador e data.

### Tabela `monster_days`

| Coluna | Tipo | Notas |
|--------|------|--------|
| `id` | bigint PK | |
| `user_id` | bigint FK → `users.id` | |
| `hunt_date` | date | Dia civil no timezone do utilizador (um registo por dia). |
| `monsters_count` | integer | `>= 0`, default `0`. |
| `created_at`, `updated_at` | datetime | |

**Constraint única:** `(user_id, hunt_date)` — não dois registos para o mesmo dia.

---

## Parte D — Models (associações)

```text
User
  has_many :snapshots, dependent: :destroy
  has_many :monster_days, dependent: :destroy

Snapshot
  belongs_to :user

MonsterDay
  belongs_to :user
```

Validações mínimas:

- `User`: email formato válido, timezone presente (ou default), password no registo.  
- `Snapshot`: números não negativos onde fizer sentido; `recorded_at` presente.  
- `MonsterDay`: `monsters_count >= 0`; unicidade `user_id + hunt_date` (validação + índice único na BD).

---

## Parte E — Endpoints da API (MVP)

Todos JSON. Prefixo: **`/api/v1`**.

### Autenticação

| Método | Caminho | Descrição |
|--------|---------|-----------|
| POST | `/api/v1/signup` | Corpo: email, password, password_confirmation, timezone. Resposta: user + token (ou só token). |
| POST | `/api/v1/login` | Corpo: email, password. Resposta: token + dados mínimos do user. |
| GET | `/api/v1/me` | Header com JWT. Resposta: utilizador atual (email, timezone, …). |

### Perfil

| Método | Caminho | Descrição |
|--------|---------|-----------|
| PATCH | `/api/v1/me` | Atualizar timezone (e display_name se existir). |

### Snapshots (só do utilizador autenticado)

| Método | Caminho | Descrição |
|--------|---------|-----------|
| GET | `/api/v1/snapshots` | Lista ordenada por `recorded_at` (desc). |
| POST | `/api/v1/snapshots` | Cria snapshot (JSON com os campos). |
| GET | `/api/v1/snapshots/:id` | Detalhe (só se `snapshot.user_id == current_user.id`). |
| PATCH | `/api/v1/snapshots/:id` | Atualiza. |
| DELETE | `/api/v1/snapshots/:id` | Apaga. |

### Monster days

| Método | Caminho | Descrição |
|--------|---------|-----------|
| GET | `/api/v1/monster_days` | Lista (opcional: `?from=&to=` por intervalo de datas). |
| PUT ou PATCH | `/api/v1/monster_days/by_date` | Corpo: `hunt_date`, `monsters_count` — **upsert** (cria ou atualiza aquele dia). |
| DELETE | `/api/v1/monster_days/:id` | Apaga linha (ou DELETE por data num query param — tu decides uma convenção). |

### Relatórios (lógica mais pesada — bom candidato a **Service**)

O mesmo cálculo serve para **JSON** (UI / botão “ver relatório”) e para **PDF** (botão “exportar”). Evita duplicar regra de negócio: um **service** devolve uma estrutura Ruby (hash ou objeto); o controller renderiza JSON **ou** passa essa estrutura a um gerador PDF.

| Método | Caminho | Descrição |
|--------|---------|-----------|
| GET | `/api/v1/reports/weekly` | `Accept: application/json` (default): última semana (seg–dom) no TZ do user — deltas + soma de monstros. Query: `?week_start=YYYY-MM-DD` (opcional, segunda-feira da semana desejada). |
| GET | `/api/v1/reports/monthly` | Último mês civil ou `?year=&month=`. |
| GET | `/api/v1/reports/weekly.pdf` | Mesmos query params que `weekly`; resposta **PDF** (`Content-Type: application/pdf`; `Content-Disposition: attachment` com nome tipo `relatorio-semana-2026-05-05.pdf`). |
| GET | `/api/v1/reports/monthly.pdf` | Idem para mensal. |

**Alternativa de desenho:** uma só rota `GET /api/v1/reports/weekly?format=pdf` ou cabeçalho `Accept: application/pdf`. O importante é **documentar uma convenção** no projeto e manter **uma** implementação do cálculo.

**Gemas PDF comuns em Rails** (escolher uma quando implementares):

- **Prawn** (`prawn`, `prawn-table`) — PDF “por código”, sem Chrome.  
- **Wicked PDF** + **wkhtmltopdf** — HTML/CSS → PDF (dependência externa).  
- **Grover** — HTML → PDF via Puppeteer/Chromium.

Para uma API só JSON + PDF simples, **Prawn** costuma ser suficiente para um extrato com texto e tabelas.

Resposta JSON sugerida (exemplo conceitual):

```json
{
  "period": { "type": "weekly", "start": "...", "end": "..." },
  "snapshots": { "start_snapshot_id": 1, "end_snapshot_id": 5 },
  "deltas": {
    "castle_power": 120000,
    "troops_total": -5000,
    "kills_total": 100,
    "castle_level": 0,
    "player_level": 1
  },
  "monsters_sum": 42,
  "summary_lines": [
    "Poder (might): +120000 entre ...",
    "Monstros (soma dos dias): 42"
  ]
}
```

A **regra exata** dos deltas (último snapshot ≤ fim vs último antes do início) segue o que está no documento de produto.

---

## Parte F — Controllers (ficheiros sugeridos)

Estrutura possível (namespace):

```text
app/controllers/api/v1/
  base_controller.rb          # current_user a partir do JWT; rescue de erros comuns
  registrations_controller.rb # signup (ou users_controller)
  sessions_controller.rb      # login
  users_controller.rb         # me, update
  snapshots_controller.rb
  monster_days_controller.rb
  reports_controller.rb
```

`BaseController` herda `ActionController::API` e define `before_action :authenticate_user!` onde precisares.

---

## Parte G — Ordem de implementação (checklist prática)

Marca à medida que avanças:

1. [ ] Criar app `--api` + configurar `database.yml` + `rails db:create`.  
2. [ ] Migration `CreateUsers` → `db:migrate`.  
3. [ ] Model `User` com `has_secure_password` e validações.  
4. [ ] Migrations `snapshots` e `monster_days` com FKs e índices únicos.  
5. [ ] Models `Snapshot`, `MonsterDay` + associações.  
6. [ ] CORS + gem `jwt` + concern ou helper para emitir/ler token.  
7. [ ] `signup` + `login` + `GET /me` a funcionar (testar com **curl** ou **Postman** / **Insomnia**).  
8. [ ] CRUD `snapshots` protegido por JWT.  
9. [ ] CRUD / upsert `monster_days`.  
10. [ ] `GET reports/weekly` e `monthly` (extrair `Reports::WeeklyService` / `MonthlyService` quando fizer sentido).  
11. [ ] **PDF:** rotas `.pdf` ou `format=pdf`; gerar ficheiro com a **mesma** lógica do passo 10 (reutilizar service).  
12. [ ] Testes automáticos (RSpec ou Minitest) nos models e nos relatórios (e pelo menos um teste de “PDF não vazio”) — quando estiveres confortável.

---

## Parte H — O que **não** precisas no início

- **Views** ERB para páginas HTML — a API é JSON; o PDF pode ser gerado **sem** layout web (ex.: Prawn desenha o PDF em Ruby).  
- **Service** — opcional no primeiro dia; relatório + PDF beneficiam cedo de um **único** service para não duplicar deltas.  
- **Front** — Vue só depois disto estável.

### PDF e base de dados

No MVP **não** é obrigatória uma tabela `generated_reports`: o PDF é **gerado em tempo real** quando o utilizador clica “Exportar”. **Futuro:** guardar PDFs ou snapshots de relatório se quiseres histórico imutável.

---

## Parte I — Ligação ao documento de produto

Regras de negócio detalhadas (monstros por dia, semana seg–dom, etc.) estão em:

`lords-mobile-individual-tracker-planejamento.md`

Este ficheiro é só **como traduzir isso em Rails + PostgreSQL + rotas**.

---

## Próximo passo no Cursor / terminal

Quando quiseres **gerar o projeto de verdade** nesta máquina, diz o **caminho da pasta** onde queres o repositório (ex.: `/Users/macbookair/projetos/lords-mobile-tracker-api`) e podemos criar migrations e ficheiros passo a passo em código.
