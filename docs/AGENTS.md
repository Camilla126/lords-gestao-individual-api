# AGENTS — Lords Mobile individual tracker (API)

Contexto para assistentes de código neste repositório. **Detalhe completo** está nos documentos de planeamento; aqui fica o essencial e onde ir buscar mais.

## Modo de trabalho (estudo)

Este projeto é focado em **estudo e prática**: aprender a construir uma API de forma ordenada.

- **Autorização explícita antes de aplicar código:** não **cries**, **alteres** nem **executes comandos/scripts que mudem o sistema** por conta do utilizador (inclui `rails`, migrações, etc.) até ele autorizar de forma inequívoca (ex.: “autorizado”, “podes aplicar esta alteração”, “implementa tu isto”).
- **Papel de professor quando não há autorização para aplicar:** explica lógica, regras de negócio, HTTP, estrutura Rails e passos sugeridos; o utilizador **implementa ou corre comandos localmente**.
- **Documentação por etapa e por rota:**
  - Cada **etapa** consolidada vai para [`planejamento/`](planejamento/) (por exemplo `etapa-01-*.md`; orientações em [`planejamento/README.md`](planejamento/README.md)): objetivos, decisões, ficheiros tocados e notas de revisão.
  - **Rotas `/api/v1`:** atualiza sempre que existir novo contrato — ver [`planejamento/api-rotas.md`](planejamento/api-rotas.md) (método, path, autenticação, parâmetros, exemplos, erros). Os planeamentos gerais na raiz continuam a ser a referência global de produto e listagem esperada das rotas.

## Documentos de referência (ler primeiro em dúvida)

| Ficheiro | Conteúdo |
|----------|----------|
| [`../lords-mobile-individual-tracker-planejamento.md`](../lords-mobile-individual-tracker-planejamento.md) | Produto: visão, dados, semântica (snapshots vs monstros/dia), semana seg–dom, mês civil, PDF, riscos, lacunas. |
| [`../lords-mobile-tracker-api-planejamento.md`](../lords-mobile-tracker-api-planejamento.md) | Técnico: schema, rotas `/api/v1`, ordem de implementação, sugestão de serviços e PDF. |

## Stack e direção

- **Back (este repo):** Ruby on Rails em modo **API** + **PostgreSQL**; respostas **JSON**; front **Vue** é separado e vem depois.
- **Auth (MVP):** JWT (`Authorization: Bearer`), `has_secure_password` / bcrypt; **CORS** para o SPA em dev.
- **Versão da API:** prefixo **`/api/v1/`**.

## Regras de negócio (não contrariar sem alinhamento)

- **Sem API do jogo:** tudo é **introduzido pelo utilizador**.
- **`snapshots`:** estado geral com `recorded_at`; métricas absolutas + **kills acumuladas** do jogo; **não** incluem monstros.
- **`monster_days`:** **um número por dia civil** no **timezone IANA** do perfil (`user_id` + `hunt_date` únicos); relatório = **soma** dos dias no período.
- **Semana do relatório:** segunda 00:00 → domingo fim do dia (no TZ do user).
- **Mês:** calendário civil no mesmo TZ.
- **Deltas:** comparar snapshots no intervalo (ver documento de produto: tipicamente último ≤ fim vs referência antes do início).
- **Relatório na UI:** “ver/atualizar” = **recalcular vista** com dados já guardados; **PDF** = mesmo cálculo que o JSON, gerado **no servidor**, sem tabela de relatórios arquivados no MVP.

## Modelo de dados (nomes)

- `users`: email único, `password_digest`, `timezone` (IANA), opcional `display_name`.
- `snapshots`: FK `user_id`, `recorded_at`, nickname, CV, poder, nível, tropas totais, kills totais; índice útil `(user_id, recorded_at)`.
- `monster_days`: FK `user_id`, `hunt_date` (date), `monsters_count` ≥ 0; **constraint única** `(user_id, hunt_date)`.

## Rotas esperadas (MVP)

- Auth: `POST /api/v1/signup`, `POST /api/v1/login`, `GET`/`PATCH /api/v1/me`.
- `snapshots`: CRUD sob o utilizador autenticado.
- `monster_days`: listagem (opcional `from`/`to`), upsert por data, delete.
- Relatórios: `GET .../reports/weekly`, `.../monthly` (JSON); PDF com mesma lógica (ex. `.pdf` ou `Accept` — **uma convenção** documentada no código).

## Princípios para alterações

- **Uma** implementação do cálculo de relatório; controllers finos, **service** quando a lógica crescer.
- Validações: timezone IANA, unicidade de `monster_days`, política clara para datas futuras em caça (ver doc de produto §13).
- Testes: modelos, relatórios, pelo menos smoke do PDF não vazio quando existir geração.

Quando alterares comportamento de produto ou contratos da API, **atualiza também** o segmento correspondente nos ficheiros `*-planejamento.md` na raiz do repositório para não ficarem desatualizados.
