# Planejamento — Rastreador individual (Lords Mobile)

Documento de referência para alinhamento de produto e escopo técnico. **Versão com decisões de MVP fechadas** (inclui **relatório na UI** e **export PDF**) — revisar quando algo mudar.

---

## 1. Visão

Aplicação **individual**: cada utilizador regista o seu estado no jogo ao longo do tempo. O sistema **guarda histórico** e gera **relatórios semanais e mensais** (números, gráficos e texto tipo **extrato**: o que subiu, desceu ou manteve).

**Premissa:** não há API oficial do Lords Mobile — todos os dados são **introduzidos pelo próprio utilizador** (autodeclaração). O valor está no **acompanhamento** e na **clareza do progresso**, não num espelho automático do servidor.

---

## 2. Objetivos do produto

- Permitir **cadastro e login** normais.
- Registar **métricas do jogador** em momentos definidos pelo utilizador (e opcionalmente lembretes — depois do MVP).
- Mostrar **evolução** entre períodos: semana e mês.
- Entregar um **relatório legível**: delta de poder, tropas, caçadas, kills, etc., com **gráficos** ou cartões de resumo.
- Permitir **gerar / atualizar a vista do relatório** com um botão (ver §6.1) e **exportar em PDF**.

---

## 3. Utilizador e privacidade

- **Um utilizador** = uma conta; dados **privados por defeito** (só o dono vê).
- **Timezone** no perfil: usado para definir **dia civil**, **semana (seg–dom)** e **mês civil** nos relatórios e nos registos de monstros.
- Opcional **futuro:** partilhar resumo — **fora do MVP**.

---

## 4. Dados a registar — semântica fechada (MVP)

### 4.1 Snapshots (estado geral do jogador)

Cada **snapshot** é um registo com `recorded_at` (normalmente “agora”). **Não inclui monstros** — os monstros vão num registo **à parte, por dia** (§4.2).

| Métrica | Semântica | Relatório |
|---------|-----------|-----------|
| **Nickname** | Texto atual no jogo | Mostrar último valor do período. |
| **Nível jogador**, **CV (castelo)** | Valor **absoluto** como no jogo | **Delta** entre dois snapshots no período. |
| **Poder do castelo** | Valor **absoluto** | **Delta** no intervalo. |
| **Tropas (total)** | Valor **absoluto** total | **Delta** entre snapshots. |
| **Kills** | **Acumulado** como no jogo (total que o jogo mostra) | **Delta** entre snapshots = diferença de acumulados no período. |

### 4.2 Monstros caçados — **contagem por dia** (separado dos snapshots)

- No Lords Mobile o jogador **caça todos os dias** e o **relatório/resumo dentro do jogo pode ser apagado ou deixar de estar disponível** para dias anteriores.
- Por isso o modelo não depende de “inventar” quantidades de **dias passados** com base no jogo: o utilizador **regista nesta app o que caçou naquele dia civil** (idealmente no próprio dia, enquanto ainda vê o número no jogo).
- **Um registo por dia** (no **timezone do utilizador**): “no dia **D**, caçei **N** monstros”.
- Relatório semanal/mensal: **somar** `N` para todos os dias **D** que caem na janela (seg–dom ou mês civil).
- **Retroativo:** permitir **editar** um dia recente se o utilizador esqueceu (correção), mas a **mensagem de produto** desencoraja confiar em “preencher semanas atrás” porque **no jogo já pode não haver prova** — o valor da app é **guardar no dia a dia**.

---

## 5. Snapshots, dias de caça e tempo

- **`snapshot`:** `recorded_at` + nickname, CV, poder, nível jogador, tropas, kills — sem monstros.
- **`monster_day`** (nome técnico a definir): `user_id`, **`hunt_date`** (data civil no TZ do user), **`monsters_count`**, `updated_at`. Índice único `(user_id, hunt_date)` — um número por dia editável.
- **Semana do relatório:** **segunda 00:00** até **domingo 23:59:59** no timezone do utilizador.
- **Mês do relatório:** **calendário civil** (dia 1 ao último dia), mesmo timezone.
- **Relatório:** deltas entre snapshots para poder/tropas/kills/CV/nível; **soma** de `monsters_count` nos `hunt_date` dentro do período.

**Texto tipo extrato (exemplos):**

- Poder / tropas / CV / nível: “Saldo no período: **+X** / **−Y**.”
- Kills: “Kills no período (diferença do total): **+Z**.”
- Monstros: “Monstros caçados (soma dos **dias** registados no período): **N**.”

---

## 6. Funcionalidades por fase

### 6.1 Relatório na interface: o que o botão faz (importante)

Há **duas coisas diferentes** — a copy da app deve deixar isso claro:

| Ação do utilizador | O que é |
|--------------------|--------|
| **Registar dados** (snapshot, dia de monstro) | **Alimenta** o sistema. Isto **não** é “o relatório”. |
| **Ver / gerar relatório** (botão tipo *“Ver extrato”*, *“Relatório desta semana”*, *“Atualizar relatório”*) | Só **recalcula e mostra** o resumo com base no que **já está** na base. Não cria novos números; pede à API o JSON do período. O botão pode chamar-se *“Atualizar”* se a ideia for “atualizar **a vista** com os meus dados mais recentes”. |

**Exportar PDF** fica no **mesmo ecrã** do relatório: depois de ver o extrato, **“Exportar PDF”** gera o ficheiro (o servidor devolve o PDF; o front faz *download*). O PDF no MVP é **sempre gerado a partir dos dados atuais** (não arquivamos versões fechadas — isso pode ser fase 2 se quiseres “fotografias” de cada semana).

### MVP

- Registo, login, recuperação de password.
- Perfil: nickname, **timezone**, tooltips/glossário.
- **Snapshots:** criar, editar, apagar.
- **Registo diário de monstros:** escolher **dia** (default = hoje no TZ do user) + quantidade; editar/apagar linha desse dia.
- Lista de snapshots + **lista ou calendário** dos dias de caça (opcional no MVP: só formulário “dia + quantidade”).
- **Painel / ecrã de relatório:** escolher período (ex.: **última semana** / **último mês** ou seletor de semana-mês) + botão **“Ver relatório”** / **“Atualizar”** (recalcula a vista) + **“Exportar PDF”** (mesmo conteúdo do extrato em PDF).
- Cálculo de deltas e texto resumo do extrato (como nas secções 4–5).

### Depois do MVP

- Lembretes “regista o teu dia de caça”.
- Gráfico de barras monstros/dia; gráficos longitudinais outras métricas.
- Tropas por tipo; export **CSV** (além do PDF).
- **Opcional:** arquivar PDFs por semana (relatório “congelado” no histórico) — hoje o PDF reflete **sempre** o estado atual dos dados.

---

## 7. Stack técnica (proposta)

- **Front:** Vue.js  
- **Back:** Ruby on Rails (API JSON)  
- **BD:** PostgreSQL  

Autenticação: JWT ou sessões; passwords com `bcrypt` / Devise ou equivalente.

---

## 8. Modelo de dados (alto nível)

| Entidade | Conteúdo |
|----------|----------|
| `users` | email, password_digest, **timezone**, display name opcional |
| `snapshots` | user_id, recorded_at, nickname, castle_level, castle_power, player_level, troops_total, kills_total |
| `monster_days` *(nome exemplo)* | user_id, **hunt_date** (date), **monsters_count** (integer ≥ 0), timestamps — **único** `(user_id, hunt_date)` |

- Relatórios: **diff** entre snapshots no intervalo; **sum(monsters_count)** onde `hunt_date` ∈ período.

---

## 9. Riscos e limitações

| Risco | Mitigação |
|-------|-----------|
| Relatório no jogo apagado | Modelo **diário na app** preserva o que foi registado; UX explica que **passado longínquo** pode não ser recuperável no jogo. |
| Poucos snapshots no período | Mensagem “dados insuficientes” para métricas que dependem de snapshots. |
| Monstros sem registo nalguns dias | Soma só conta dias com entrada; opcional mostrar “dias em falta”. |

---

## 10. Decisões registadas (resumo)

| Tema | Decisão |
|------|---------|
| Kills | **Acumulado do jogo** nos snapshots → delta = diferença entre totais. |
| Monstros | **Contagem por dia civil** (TZ do user), **tabela própria**; não vai no snapshot. Motivo: caça diária + **relatório no jogo pode ser apagado** — não forçar “preencher dias antigos” como fonte de verdade. |
| Semana | **Segunda → domingo**. |
| Mês | **Calendário civil**. |
| Tropas | **Total**; delta entre snapshots. |
| Snapshots | **Editar e apagar** permitidos. |
| Monstros | **Editar** dia (correção); **não** insistir em backfill de meses atrás na copy do produto. |
| Relatório na UI | Botão **ver/atualizar extrato** = recalcular **vista** a partir dos dados já guardados; **não** substitui o registo de snapshots/monstros. |
| PDF | **Exportar PDF** no ecrã do relatório; ficheiro gerado no **servidor** a partir do mesmo cálculo do JSON. MVP = **sem** tabela de “relatórios arquivados”. |

---

## 11. Relação com o projeto anterior

O planejamento de **gestão de guilda** fica **arquivado**; este documento é o **ativo** para o rastreador individual.

---

## 12. Pronto para código?

**Sim.** No primeiro PR: validar `timezone`, validar `hunt_date` (política para datas futuras — ver §13), índice único por `(user_id, hunt_date)`.

---

## 13. Pesquisa no jogo (resumo) e lacunas de regra adicionais

Conteúdo baseado em wiki da comunidade (ex.: Fandom *Monster Hunting*, *Might*), guias e hábito dos jogadores — **não** é documentação oficial da IGG. Serve para alinhar **rótulos** e **expectativas** do relatório.

### 13.1 O que o jogo ajuda a alinhar

| Tema | Observação | Impacto no produto |
|------|----------------|---------------------|
| **Kills** | Em geral o perfil expõe estatísticas em **Boosts & Stats → Stats** (ex.: **Troop Kills** — abates de tropas inimigas, acumulado). | O teu modelo **“kills acumuladas no snapshot → delta”** faz sentido; na UI usa o **mesmo nome** que o cliente (PT-BR) para não haver duas interpretações de “kill”. |
| **Might / poder** | *Might* agrega **várias fontes** (tropas, edifícios, pesquisa, armadilhas, etc.). Perder **tropas** reduz might, mas o valor total também muda por **outras ações** (evoluir edifício, concluir pesquisa). | O extrato “ganhou/perdeu poder” é **variação líquida do número total** entre dois snapshots — **não** prova que foi só por tropas ou só por batalha. Texto de ajuda curto na app evita expectativa errada. |
| **Tropas** | O número total de tropas e o might mudam com feridos/mortos/curas/treino (enfermaria, etc.). | Delta de **tropas** entre snapshots é válido como **registo declarado**; interpretação fina (feridos vs mortos) é **fora do MVP**. |
| **Caça a monstros** | Caça usa **energia**, há **um ataque de caça de cada vez** ao mesmo monstro, monstros no mapa têm tempo limitado; **monstros de evento** (ex.: Bash) podem ter regras diferentes. | O teu registo **“quantos monstros no dia”** é **agregado pelo jogador** — não há API. Vale uma linha na app: **“conta como definires (ex.: monstros derrotados no dia)”** para alinhar com a guilda. |
| **Estatística diária de caça no cliente** | Não há painel oficial tipo “caçaste N monstros hoje” exportável como API; guildas muitas vezes **contam à mão**, por bots externos ou metas em eventos. | O modelo **diário na tua app** é **razoável** e até tipico — estás a substituir planilha/discord, não a espelhar um ecrã único do jogo. |

### 13.2 Lacunas / decisões extra (recomendado fechar cedo)

1. **“Poder do castelo” vs might total** — No jogo os jogadores falam em *might* total e às vezes em componentes. Decidir se o campo é **might total da conta** (recomendado para bater certo com o perfil) ou só uma parte; renomear label na UI para coincidir com o ecrã que copias (evita erro sistemático nos deltas).

2. **Contagem de “monstro no dia”** — Um monstro pode levar **vários ataques** até morrer; na guilda pode importar **“kills” de monstros** (cartas derrotadas) vs **ataques**. Uma frase na app ou no onboarding: **“regista o número que a tua guilda usa para metas”**.

3. **Conta única / um reino** — MVP = **uma conta app ↔ um conjunto de métricas**. Migração de reino ou conta secundária: **nova conta** ou **reset manual** — evitar misturar dados sem querer.

4. **Datas futuras em `monster_days`** — Permitir **só até hoje** (no TZ do user) ou permitir **planeamento**? Para relatório honesto, o mais simples é **bloquear futuro** ou avisar “não recomendado”.

5. **Mudança de timezone** — Se o user mudar o TZ, **dias já gravados** não devem “mudar de dia civil” automaticamente (armazenar **data já interpretada** ou **UTC noon** + TZ atual — definir uma regra única).

6. **Horário de verão (DST)** — Semanas que cruzam mudança de relógio: usar biblioteca de timezone **IANA** (`America/Sao_Paulo`, etc.) nos relatórios para domingo–segunda não saltarem dados.

7. **Snapshots duplicados no mesmo dia** — Vários snapshots no mesmo dia com valores diferentes: para deltas usar **último do dia** ou **primeiro**? **Regra sugerida:** para período semanal/mês usar **último snapshot ≤ fim do período** vs **último antes do início** (comportamento standard).

---

## 14. Próximo passo técnico

Migrations `users`, `snapshots`, `monster_days` (ou nome final) + endpoints REST (incluindo **relatórios em JSON** e **export PDF**); glossário de labels alinhado ao cliente PT-BR quando possível. Detalhe de rotas e gemas em `lords-mobile-tracker-api-planejamento.md`.

---

*Documento atualizado com pesquisa informal ao ecossistema Lords Mobile (wiki/comunidade); rever se a IGG alterar ecrãs de estatísticas.*
