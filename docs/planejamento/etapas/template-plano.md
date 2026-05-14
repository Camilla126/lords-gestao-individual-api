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
- **Validação ao fechar a etapa (recomendado nos planos):** indicar como testar os fluxos relevantes — por exemplo cliente HTTP (**Insomnia**, Postman, etc.), **`rails c`** quando fizer sentido para inspeccionar modelos/serviços, e **confirmação na base de dados** com **DBeaver** (ligação usando os mesmos host/porta/database/user/password que `config/database.yml` em desenvolvimento) ou, como alternativa leve sem GUI, **`rails dbconsole`** / psql com a mesma query SQL exemplificada.

## Porquê e encadeamento (recomendação forte)

**Antes** de cada bloco de comandos/código (ou logo após o título do passo), incluir um parágrafo curto ou bullets **`Porquê este passo`** que respondam:

- **Para quê:** qual o **objectivo de produto ou técnico** (ex.: “precisamos de um sítio persistente para guardar contas” / “o token tem de ser verificável pelo servidor”).
- **Porque agora nesta ordem:** porque depende do passo anterior ou prepara o seguinte (ex.: “só depois da tabela `users` faz sentido o modelo `User`” / “o serviço JWT vem depois do segredo no Passo 2”).
- **O que vem a seguir:** uma frase que **liga** ao próximo passo (“no Passo seguinte vais…”).

Isto evita listas só de sintaxe sem narrativa. Junta-se à secção de explicação do código abaixo.

## Quando há código ou SQL nos passos (recomendação forte)

Logo **após** cada bloco de código (Gemfile, migration, modelo, controller, routes, payloads HTTP em JSON (Insomnia etc.), consultas SQL executáveis também no DBeaver/psql, etc.), acrescentar uma secção com título claro, por exemplo **“Entender o ficheiro (Passo N)”** ou **“O que este código faz (Passo N)”** — **não** obrigar o formato antigo de uma bullet por linha com três etiquetas curtas.

**Objectivo do texto:** ler como uma explicação de professor ou de chat: alguém que já viu o snippet e quer **perceber o ficheiro inteiro**, não decorar etiquetas.

**Estrutura sugerida (flexível):**

1. **Papel deste ficheiro no fluxo** — 1–2 parágrafos: que problema resolve; como encaixa no passo anterior e no seguinte; se for controller, de onde vem o pedido HTTP e o que devolve (em linguagem humana).
2. **Como o código está organizado** — prosa: módulos/classes primeiro; depois validações; depois métodos públicos vs `private`; ou a ordem que fizer sentido para **ler o ficheiro de cima a baixo**.
3. **Detalhe por blocos** — agrupa linhas que trabalham juntas (ex.: “o bloco `before_validation`…”, “o método `create` faz três coisas: …”). Só desce ao nível **linha a linha** quando uma linha isolada costuma confundir (ex.: `&.`, `||=`, `params.require`).
4. **Comandos shell** — um ou dois parágrafos: o que o comando faz de uma vez; flags; o que fica gravado no repo ou na BD; env vars se forem relevantes.

**Evitar:** listas longas onde cada bullet é só “**O que faz** / **Por que** / **Quando**” em três frases — isso cansa e parece manual de referência em vez de explicação.

**Permitido:** listas curtas para **passos de um fluxo** (1 → 2 → 3), ou para **pré-requisitos**, quando a lista for mais clara que parágrafos.

Motivo: o projecto favorece **estudo** — o `plano.md` deve dar a mesma clareza que uma boa resposta no chat, com o código ao lado. Referência de etapa longa: [`etapa-01-auth-jwt/plano.md`](etapa-01-auth-jwt/plano.md).

Se num passo sugerires abrir o **Rails console**, documenta **`rails c`**; demais comandos podem seguir **`rails …`** com nota de equivalência `bin/rails` (ver [`README.md`](README.md#convenção-comandos-rails-cli)).
