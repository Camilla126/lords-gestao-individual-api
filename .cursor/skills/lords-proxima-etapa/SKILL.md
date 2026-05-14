---
name: lords-proxima-etapa
description: >-
  Scaffolds the next study etapa for this repo: creates
  docs/planejamento/etapas/etapa-NN-<slug>/plano.md from project conventions
  (README + template-plano). Use when the user invokes this skill, asks for the
  next etapa, próxima etapa, nova pasta de etapa, or scaffolding plano.md after
  etapa-01-auth-jwt.
disable-model-invocation: true
---

# Lords — próxima etapa (`plano.md`)

Cria **só** a documentação da próxima etapa (`plano.md` + pasta), alinhada com `docs/planejamento/etapas/README.md` e `docs/planejamento/etapas/template-plano.md`. **Não** implementar código Rails nem correr migrações **a menos que** o utilizador autorize explicitamente (modo estudo em `docs/AGENTS.md`).

## Antes de criar ficheiros

1. Lê `docs/planejamento/etapas/README.md` (convenção `etapa-NN-<slug-curto>/plano.md`).
2. Lê `docs/planejamento/etapas/template-plano.md` — a nova `plano.md` deve seguir as secções do **início** do template (Objetivo, Pronto quando, Passos macro, Após esta etapa, orientações porquê/explicação de código quando houver passos).
3. Lista pastas em `docs/planejamento/etapas/` que casem com `etapa-[0-9][0-9]-*`. Determina o **maior `NN`** já usado; a próxima etapa é **`NN + 1`**, sempre com **dois dígitos** (`02`, `03`, …).

## Slug e título

- Se o utilizador **indicou** slug e/ou título na mensagem, usa-os (slug: minúsculas, hífens, curto; pasta `etapa-NN-<slug>`).
- Senão, usa a **sugestão por número de etapa** para este produto (ordem alinhada a `docs/AGENTS.md` e Parte E/G de `lords-mobile-tracker-api-planejamento.md` na raiz do repo):

| NN | Slug sugerido | Título sugerido (cabeçalho `# Etapa NN — …`) |
|----|---------------|-----------------------------------------------|
| 02 | `snapshots` | Snapshots (CRUD sob JWT) |
| 03 | `monster-days` | Monster days (listagem, upsert, delete) |
| 04 | `reports-json` | Relatórios semanais e mensais (JSON) |
| 05 | `reports-pdf` | Exportação PDF (mesma lógica que JSON) |
| 06 | `testes` | Testes automáticos (models, relatórios, smoke PDF) |

Se `NN` for **7 ou superior**, não inventes domínio: pergunta ao utilizador **slug** e **título** antes de criar.

Se a pasta `etapa-NN-<slug>` **já existir**, não sobrescrevas `plano.md` sem confirmação; informa e pede instruções.

## Conteúdo inicial do `plano.md`

1. Título: `# Etapa NN — <título>`.
2. Secções mínimas espelhando o template: **Objetivo** (1 frase placeholder ou frase honesta a partir do doc técnico), **Pronto quando** (3–6 checkboxes `[ ]` realistas para essa etapa), **Passos macro** (bullets), **Após esta etapa** (incluir linha a apontar para `docs/planejamento/api-rotas.md` quando a etapa introduzir ou alterar contratos HTTP).
3. Uma secção **Passo a passo** (numerada) com **2–4 passos iniciais** só como esqueleto (títulos + “A desenvolver”) **ou**, se tiveres contexto do `lords-mobile-tracker-api-planejamento.md` / `lords-mobile-individual-tracker-planejamento.md`, bullets concretos **sem** fingir que já está tudo fechado — o utilizador completa depois.
4. Inclui um parágrafo curto **encadeamento com a etapa anterior** (ex.: etapa 02 assume JWT da etapa 01).

## Depois de criar

- Lembra na resposta: ao **fechar** a implementação dessa etapa, actualizar `docs/planejamento/api-rotas.md` se houver rotas novas ou mudanças de contrato.
- Comandos nos exemplos: preferir **`rails …`** e **`rails c`** com nota de `bin/rails` / `bundle exec` como em `docs/planejamento/etapas/README.md`.

## Resumo para o utilizador

No fim, indica o caminho criado (`docs/planejamento/etapas/etapa-NN-<slug>/plano.md`) e o que falta preencher se deixaste placeholders.
