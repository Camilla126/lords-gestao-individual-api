# Etapa 01 — Autenticação JWT (para fazeres tu, passo a passo)

## Objetivo

Ter **cadastro** e **login** em JSON com **JWT**, mais **`GET/PATCH /api/v1/me`** com `Authorization: Bearer`. A “tela” Vue fica para depois; testas com **Insomnia** (ou Postman). Segue a ordem **à letra**; em cada passo grava o ficheiro e só avança quando não houver erro.

**Pré-requisito:** PostgreSQL a correr e `bin/rails db:create` já feito neste projecto (se `db:migrate` falhar por BD inexistente, corre `bin/rails db:create` antes).

---

## Passo 1 — Gemas

Abre o [`Gemfile`](../../../../Gemfile) na raiz do projecto.

1. **Descomenta** a linha do `bcrypt` (fica como `gem "bcrypt", "~> 3.1.7"` ou similar).
2. **Adiciona** (por exemplo a seguir ao `bcrypt`):

```ruby
gem "jwt", "~> 2.8"
```

3. No terminal, na pasta do projecto:

```bash
bundle install
```

*(Opcional para mais tarde, com Vue noutro porto: descomenta `rack-cors` e configura `config/initializers/cors.rb` pelo guia Rails. Podes saltar por agora se só testas com Insomnia no mesmo host.)*

---

## Passo 2 — Segredo JWT (credentials)

Nunca commits chaves em texto claro no código.

```bash
EDITOR="nano" bin/rails credentials:edit
```

Se preferires VS Code: `EDITOR="code --wait" bin/rails credentials:edit`.

No YAML que abrir, **adiciona** (gera tu uma string longa e aleatória):

```yaml
jwt_secret: coloca_aqui_uma_string_longa_e_secreta
```

Grava e fecha. Alternativa em dev: variável de ambiente `JWT_SECRET` (o código abaixo aceita **credentials ou ENV**).

---

## Passo 3 — Migration `users`

Gera a migration:

```bash
bin/rails generate migration CreateUsers email:string:uniq password_digest:string timezone:string display_name:string
```

Abre o ficheiro criado em `db/migrate/XXXXXXXX_create_users.rb` e **substitui** o método `change` por isto (mantém o nome da classe e o número `Migration[8.1]` que o gerador tiver posto):

```ruby
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :timezone, null: false
      t.string :display_name

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end
```

Aplica:

```bash
bin/rails db:migrate
```

Confirma em `db/schema.rb` que a tabela `users` aparece.

---

## Passo 4 — Model `User`

Cria o ficheiro **`app/models/user.rb`** com:

```ruby
class User < ApplicationRecord
  has_secure_password

  before_validation :normalize_email

  validates :email, presence: true, format: URI::MailTo::EMAIL_REGEXP, uniqueness: { case_insensitive: true }
  validates :timezone, presence: true
  validates :password, presence: true, length: { minimum: 8 }, if: -> { password_digest.nil? || password.present? }
  validates :password_confirmation, presence: true, on: :create

  validate :timezone_must_be_known, if: -> { timezone.present? }

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def timezone_must_be_known
    TZInfo::Timezone.get(timezone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(:timezone, "must be a valid IANA timezone (e.g. Europe/Lisbon)")
  end
end
```

---

## Passo 5 — Serviço `JsonWebToken`

Garante que existe a pasta **`app/services`**. Cria **`app/services/json_web_token.rb`**:

```ruby
class JsonWebToken
  EXP = 24.hours

  class << self
    def encode(user_id:, exp: Time.current + EXP)
      payload = { sub: user_id, exp: exp.to_i }
      JWT.encode(payload, secret, "HS256")
    end

    def decode(token)
      return nil if token.blank?

      JWT.decode(token, secret, true, { algorithm: "HS256" }).first.symbolize_keys
    rescue JWT::DecodeError
      nil
    end

    private

    def secret
      key = Rails.application.credentials[:jwt_secret].presence || ENV["JWT_SECRET"]
      raise "Missing jwt_secret in credentials or JWT_SECRET in ENV" if key.blank?

      key
    end
  end
end
```

---

## Passo 6 — Concern `Authenticable`

Cria **`app/controllers/concerns/authenticable.rb`**:

```ruby
module Authenticable
  extend ActiveSupport::Concern

  private

  def authenticate_user!
    return if current_user

    render json: { error: "Unauthorized" }, status: :unauthorized
  end

  def current_user
    @current_user ||= begin
      header = request.headers["Authorization"].to_s
      token = header.split.last
      payload = JsonWebToken.decode(token)
      return nil unless payload && payload[:sub]

      User.find_by(id: payload[:sub])
    end
  end
end
```

---

## Passo 7 — `Api::V1::BaseController`

Cria as pastas **`app/controllers/api/v1`**. Cria **`app/controllers/api/v1/base_controller.rb`**:

```ruby
module Api
  module V1
    class BaseController < ApplicationController
      include Authenticable
    end
  end
end
```

O [`ApplicationController`](../../../../app/controllers/application_controller.rb) já pode ficar só com `class ApplicationController < ActionController::API` — não precisas do concern aqui.

---

## Passo 8 — Controllers de registo e sessão

**`app/controllers/api/v1/registrations_controller.rb`**

```ruby
module Api
  module V1
    class RegistrationsController < ApplicationController
      def create
        user = User.new(user_params)
        if user.save
          render json: { token: JsonWebToken.encode(user_id: user.id), user: user_json(user) }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def user_params
        params.require(:user).permit(:email, :password, :password_confirmation, :timezone, :display_name)
      end

      def user_json(user)
        { id: user.id, email: user.email, timezone: user.timezone, display_name: user.display_name }.compact
      end
    end
  end
end
```

**`app/controllers/api/v1/sessions_controller.rb`**

```ruby
module Api
  module V1
    class SessionsController < ApplicationController
      def create
        user = User.find_by(email: session_params[:email].to_s.strip.downcase)
        if user&.authenticate(session_params[:password])
          render json: { token: JsonWebToken.encode(user_id: user.id), user: user_json(user) }, status: :ok
        else
          render json: { error: "Invalid credentials" }, status: :unauthorized
        end
      end

      private

      def session_params
        params.permit(:email, :password)
      end

      def user_json(user)
        { id: user.id, email: user.email, timezone: user.timezone, display_name: user.display_name }.compact
      end
    end
  end
end
```

**`app/controllers/api/v1/me_controller.rb`**

```ruby
module Api
  module V1
    class MeController < BaseController
      before_action :authenticate_user!

      def show
        render json: { user: user_json(current_user) }, status: :ok
      end

      def update
        if current_user.update(me_params)
          render json: { user: user_json(current_user) }, status: :ok
        else
          render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def me_params
        params.require(:user).permit(:timezone, :display_name)
      end

      def user_json(user)
        { id: user.id, email: user.email, timezone: user.timezone, display_name: user.display_name }.compact
      end
    end
  end
end
```

---

## Passo 9 — Rotas

Abre [`config/routes.rb`](../../../../config/routes.rb) e deixa assim (podes manter o comentário do `up` se quiseres):

```ruby
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "signup", to: "registrations#create"
      post "login", to: "sessions#create"
      get "me", to: "me#show"
      patch "me", to: "me#update"
    end
  end
end
```

Confirma:

```bash
bin/rails routes | grep api
```

---

## Passo 10 — Subir o servidor

```bash
bin/rails server
```

Por defeito: `http://localhost:3000`.

---

## Passo 11 — Testes no Insomnia (ordem)

**1. Signup** — `POST` `http://localhost:3000/api/v1/signup`  
Headers: `Content-Type: application/json`  
Body (JSON):

```json
{
  "user": {
    "email": "tu@example.com",
    "password": "senhaSegura8",
    "password_confirmation": "senhaSegura8",
    "timezone": "Europe/Lisbon",
    "display_name": "Tu"
  }
}
```

Resposta esperada: **201**, JSON com `token` e `user`.

**2. Login** — `POST` `http://localhost:3000/api/v1/login`  
Body (JSON — **sem** chave `"user"` no root):

```json
{
  "email": "tu@example.com",
  "password": "senhaSegura8"
}
```

Copia o `token`.

**3. Eu** — `GET` `http://localhost:3000/api/v1/me`  
Header: `Authorization: Bearer <cole_o_token_aqui>`

Resposta esperada: **200** com `user`.

**4. (Opcional) PATCH `/me`** — body:

```json
{
  "user": {
    "timezone": "America/Sao_Paulo",
    "display_name": "Novo nome"
  }
}
```

Mesmo header Bearer.

---

## Passo 12 — Ver na base de dados (confirmação)

```bash
bin/rails dbconsole
```

No prompt SQL:

```sql
SELECT id, email, timezone, display_name,
       password_digest IS NOT NULL AS tem_hash_senha,
       created_at
FROM users
ORDER BY id DESC
LIMIT 5;
\q
```

Deves ver a tua linha com `email` correcto e `password_digest` preenchido (é o hash bcrypt, **não** a password em claro).

---

## Checklist final

- [ ] Passos 1–9 feitos sem erros de consola.
- [ ] Insomnia: signup → login → GET `/me` OK.
- [ ] BD: linha em `users` visível (Passo 12).
- [ ] Documentaste as rotas em [`../../api-rotas.md`](../../api-rotas.md) (copia o contrato + exemplos que usaste).

## Referências

- Visão técnica global: [`../../../../lords-mobile-tracker-api-planejamento.md`](../../../../lords-mobile-tracker-api-planejamento.md).
