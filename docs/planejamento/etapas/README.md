# Etapas (um `plano.md` por pasta)

Para não sobrecarregar a raíz de [`../`](..), cada etapa usa **uma pasta** com um **único ficheiro obrigatório**: `plano.md`.

**Fonte de verdade:** o passo-a-passo que vais **executar** (comandos + código) deve ficar **aqui no repositório**, no `plano.md` — versionado com o projecto e acessível fora do Cursor. Planos só na pasta `.cursor/plans/` do IDE são **opcionais** / rascunho; não substituem este ficheiro quando queres estudar e repetir no teu ritmo.

## Convenção de nome

```
etapa-NN-<slug-curto>/
  plano.md
```

Exemplos: `etapa-01-auth-jwt/`, `etapa-02-snapshots/`.

Opcional mais tarde, na mesma pasta, só se precisares: um único extra (ex.: `notas-debug.md`). Evita vários PLANOS paralelos aqui dentro.

Exemplo existente: [`etapa-01-auth-jwt/plano.md`](etapa-01-auth-jwt/plano.md) (autenticação JWT).

## Ao começar uma etapa

1. Copia [`template-plano.md`](template-plano.md) para `etapa-NN-<slug>/plano.md` — ou expands já com **passos numerados completos** (como [`etapa-01-auth-jwt/plano.md`](etapa-01-auth-jwt/plano.md)), se essa etapa for longa/pedagógica.
2. Preenche até ao “feito”: podes usar checklist **curta** + secção grande “passo a passo” no mesmo `plano.md` quando fizer sentido; o importante é estar **no git**, não só num plano externo ao repo.
3. No fim da etapa, marca checklist e atualiza [`../api-rotas.md`](../api-rotas.md) se houver novas rotas.
