# Etapa NN — `<título curto>`

## Objetivo

Uma frase.

## Pronto quando

- [ ] …

## Passos macro (opcional)

- …

## Ficheiros / decisões úteis (opcional, curto)

- …

## Após esta etapa

- Rotas novas ou alteradas registadas em `docs/planejamento/api-rotas.md`.

## Porquê e encadeamento (recomendação forte)

**Antes** de cada bloco de comandos/código (ou logo após o título do passo), incluir um parágrafo curto ou bullets **`Porquê este passo`** que respondam:

- **Para quê:** qual o **objectivo de produto ou técnico** (ex.: “precisamos de um sítio persistente para guardar contas” / “o token tem de ser verificável pelo servidor”).
- **Porque agora nesta ordem:** porque depende do passo anterior ou prepara o seguinte (ex.: “só depois da tabela `users` faz sentido o modelo `User`” / “o serviço JWT vem depois do segredo no Passo 2”).
- **O que vem a seguir:** uma frase que **liga** ao próximo passo (“no Passo seguinte vais…”).

Isto evita listas só de sintaxe sem narrativa. Junta-se às explicações linha-a-linha abaixo.

## Quando há código ou SQL nos passos (recomendação forte)

Logo **após** cada bloco de código (Gemfile, migration, modelo, controller, routes, payloads JSON em Insomnia, consultas SQL, etc.), acrescentar uma secção **“Linha-a-linha (Passo N)”** ou equivalente:

- cada **linha** relevante ou cada **agrupamento curto** (ex.: método inteiro quando for curto), usando **sempre** o mesmo formato em três partes: **O que faz** / **Por que existe** / **Quando roda** — por entrada (sem misturar exemplo nem “erro comum” nessa bullet);
- para comandos de shell (`bundle`, `rails`, `rails credentials:edit`): nas mesmas três partes, cobrir também **flags**, **efeitos persistentes no repo**, e variáveis de ambiente relacionadas quando aplicável.

Motivo: o projecto favorece **estudo** — o próprio texto do `plano.md` deve servir como apoio quando estás a ler o código no IDE. Referência vivo: [`etapa-01-auth-jwt/plano.md`](etapa-01-auth-jwt/plano.md).

Se num passo sugerires abrir o **Rails console**, documenta **`rails c`**; demais comandos podem seguir **`rails …`** com nota de equivalência `bin/rails` (ver [`README.md`](README.md#convenção-comandos-rails-cli)).
