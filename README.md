# Lords Mobile Tracker — API (Rails)

API JSON em modo **`--api`**, PostgreSQL (Rails 8). Stack de arranque **sem** Docker/Kamal/Thruster nem Solid Cache/Queue/Cable (cache em memória e jobs `async` no MVP).

## Requisitos

- Ruby (ver `.ruby-version`)
- Bundler (`gem install bundler`)
- PostgreSQL a correr (no macOS: `brew services start postgresql@14` ou a versão que instalaste)

## Arranque

Na pasta do projeto:

```bash
bundle install          # se ainda não corrês-te
rails db:create         # cria BD development + test
rails db:migrate        # depois de criarmos as migrations (passo seguinte)
rails server           # API em http://localhost:3000
```

Se `db:create` falhar com erro de ligação ao PostgreSQL:

- Confirma que o serviço Postgres está ativo.
- Se usares utilizador/password em vez do socket, edita `config/database.yml` (`username`, `password`, `host: localhost`).

## Próximo passo do plano

1. Migrations: `users`, `snapshots`, `monster_days`.
2. Autenticação (JWT + signup/login).

Documentação de produto/regras na raiz: `lords-mobile-individual-tracker-planejamento.md` e `lords-mobile-tracker-api-planejamento.md`, e `docs/AGENTS.md` para o agente.
