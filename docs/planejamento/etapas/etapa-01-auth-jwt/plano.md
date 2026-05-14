# Etapa 01 — Autenticação JWT (para fazeres tu, passo a passo)

## Objetivo

Ter **cadastro** e **login** em JSON com **JWT**, mais **GET/PATCH** em `/api/v1/me` com o header `**Authorization: Bearer`**. A “tela” Vue fica para depois; testas na API com **Insomnia** ou Postman, podes repetir cenários em **`rails c`**, e na base de dados com **DBeaver** ou `**rails dbconsole**` (Passos 11 e 12). Segue a ordem **à letra**; em cada passo grava o ficheiro e só avança quando não houver erro.

**Pré-requisito:** PostgreSQL a correr e `**rails db:create`** já feito neste projecto (se `**rails db:migrate**` falhar por BD inexistente, corre `**rails db:create**` antes). Se algo não encontrar `rails`, usa `**bundle exec rails …**` ou `**bin/rails …**` (mesmo comandos na pasta do projecto).

**Como ler este plano:** antes de cada trecho há **Porquê este passo** (objectivo, ordem no fluxo, ligação ao que se segue). Depois vêm comandos ou código para copiar. Em seguida, **Entender o ficheiro / o código (Passo N)** — prosa com **o que cada parte faz** (Gemfile, `params`, JWT, SQL, etc.), para além do “para quê” no geral.

**CLI Rails nos passos:** comandos `**rails …`** (`rails credentials:edit`, `rails db:migrate`, etc.), alinhados com `**rails c**` para o console. Equivalente no projecto: `**bin/rails …**` ou `**bundle exec rails …**` se o teu `rails` não for o do Bundler.

---

## Passo 1 — Gemas

**Porquê este passo** — **Para quê:** sem bcrypt e a gema `jwt` instaladas, o código dos passos seguintes nem carrega: não há hashing de senha nem biblioteca para assinar/ler tokens. **Porque nesta ordem:** primeiro declaras dependências no `Gemfile`, depois instalar com Bundler — é o contrato de pacotes Ruby antes de tocar em models ou serviços. **Depois:** no Passo 2 defines o **segredo** que o JWT vai usar; no Passo 4 o modelo usa bcrypt via `has_secure_password`.

Abre o `[Gemfile](../../../../Gemfile)` na raiz do projecto.

1. **Descomenta** a linha do `bcrypt` (fica como `gem "bcrypt", "~> 3.1.7"` ou similar).
2. **Adiciona** (por exemplo a seguir ao `bcrypt`):

```ruby
gem "jwt", "~> 2.8"
```

1. No terminal, na pasta do projecto:

```bash
bundle install
```

*(Opcional para mais tarde, com Vue noutro porto: descomenta `rack-cors` e configura `config/initializers/cors.rb` pelo guia Rails. Podes saltar por agora se só testas com Insomnia no mesmo host.)*

**Entender o ficheiro (Passo 1)**

**O que é o Gemfile** — É a lista de dependências Ruby do projecto. O Bundler lê este ficheiro e resolve versões compatíveis entre si; o resultado “congelado” costuma ir para **`Gemfile.lock`** (para toda a gente instalar as **mesmas** versões).

**`gem "bcrypt", …` (descomentado)** — A gema **bcrypt** implementa o algoritmo de hash que o Rails usa por baixo de **`has_secure_password`**. Quando gravas um `User` com `password`, o ActiveRecord **não** grava essa string na coluna `password`: calcula um digest e grava em **`password_digest`**. No login, **`authenticate`** compara a password que vêm no pedido com esse digest. Sem bcrypt no Gemfile, `has_secure_password` não funciona.

**`gem "jwt", "~> 2.8"`** — A gema **jwt** é a biblioteca que assina e verifica tokens no formato JWT. O **`~> 2.8`** significa: “versão **2.8** ou superior na série **2.x**, mas **não** salta para **3.0** sozinho” — evita surpresas de breaking changes de major. No Passo 5 vais chamar `JWT.encode` / `JWT.decode` desta gema.

**`bundle install`** — Instala ou actualiza gemas na tua máquina conforme `Gemfile`/`Gemfile.lock`. Corres na **raiz do projecto** (onde está o Gemfile). Se mudares o Gemfile outra vez, repetis o comando para o ambiente ficar alinhado.

---

## Passo 2 — Segredo JWT (credentials)

**Porquê este passo** — **Para quê:** um JWT é um texto assinado; o servidor precisa de um **segredo partilhado** (só ele conhece) para emitir tokens no login/signup e para recusar tokens adulterados. **Porque agora:** antes de implementar `JsonWebToken` (Passo 5) esse segredo tem de existir nas **credentials** ou na env `JWT_SECRET`. **Depois:** no Passo 5 o método `secret` lê exactamente este valor.

Nunca commits chaves em texto claro no código.

```bash
EDITOR="nano" rails credentials:edit
```

Se preferires VS Code: `EDITOR="code --wait" rails credentials:edit`.

No YAML que abrir, **adiciona** (gera tu uma string longa e aleatória):

```yaml
jwt_secret: coloca_aqui_uma_string_longa_e_secreta
```

Grava e fecha. Alternativa em dev: variável de ambiente `JWT_SECRET` (o código abaixo aceita **credentials ou ENV**).

**Entender o fluxo (Passo 2)**

**Porque precisas de um segredo** — O JWT é um texto que o cliente guarda e reenvia; qualquer um o **lê** (payload em base64). O que impede alguém de **forjar** um token a dizer “sou o user 999” é a **assinatura HMAC**: só quem conhece o segredo pode gerar uma assinatura válida. O servidor usa o **mesmo** segredo no `encode` (signup/login) e no `decode` (cada `/me`).

**`EDITOR="nano"` (ou VS Code)** — O Rails desencripta as credentials para um ficheiro temporário e chama o programa indicado em **`EDITOR`** para o editares. **`nano`** é um editor de terminal simples; **`code --wait`** abre o VS Code e espera fechares o separador. Isto **não** fica no repositório: é só variável de ambiente **nessa** linha de comando.

**`rails credentials:edit`** — Abre o YAML das credentials, e ao gravar reencripta **`config/credentials.yml.enc`**. A chave para desencriptar está em **`config/master.key`** (local, não commitada por defeito) ou na variável **`RAILS_MASTER_KEY`**. Assim podes versionar **estrutura** de segredos encriptada sem pôr a chave em texto claro no Git.

**Chave `jwt_secret:` no YAML** — O Rails expõe isto como **`Rails.application.credentials[:jwt_secret]`** (símbolo `:jwt_secret` em Ruby). O valor deve ser uma string **longa e aleatória** (não uma palavra do dicionário). O serviço `JsonWebToken` do Passo 5 lê este valor através do método `secret`.

**`JWT_SECRET` na env** — Se em CI ou noutro PC não quiseres editar credentials, defines **`JWT_SECRET`** no ambiente antes de `rails server`. O código do Passo 5 usa **`.presence`** nas credentials: string vazia ou só espaços conta como “não definido” e aí tenta a env — duas entradas, um só sítio de leitura no código.

---

## Passo 3 — Migration `users`

**Porquê este passo** — **Para quê:** a API precisa de **persistir** contas (email, hash da senha, timezone para relatórios futuros). A **tabela** `users` na PostgreSQL é o armazém oficial; a migration é a “receita” versionada que cria essa estrutura de forma repetível (outros ambientes, CI, colegas). **Porque antes do modelo:** no Rails convém existir schema alinhado (`db/schema.rb`) antes de escrever `User` — o `ApplicationRecord` mapeia para colunas reais. **Depois:** no Passo 4 o modelo `User` adiciona **regras** (validações, bcrypt) por cima desta tabela.

Gera a migration:

```bash
rails generate migration CreateUsers email:string:uniq password_digest:string timezone:string display_name:string
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
rails db:migrate
```

Confirma em `db/schema.rb` que a tabela `users` aparece.

**Entender o ficheiro (Passo 3)**

**`rails generate migration CreateUsers …`** — Cria um ficheiro em `db/migrate/` com data no nome. Os tipos que passas na linha de comando (`email:string:uniq`, etc.) são **sugestão** do gerador; neste plano **substituís** o `change` pelo bloco final — o importante é o schema que fica no ficheiro editado, não o esqueleto inicial.

**`class CreateUsers < ActiveRecord::Migration[8.x]`** — Declara a migração. O número **`[8.1]`** (ou o que o gerador tiver posto) é a versão da API de migrações do Rails: mantém sempre o que veio do gerador para não haver avisos ou incompatibilidades.

**`def change`** — Descreve alterações ao schema. O Rails tenta, em muitos casos, **reverter** automaticamente esta migração se correres `db:rollback` — por isso convém não meter SQL arbitrário que o Rails não saiba inverter.

**`create_table :users`** — Cria a tabela **`users`** no PostgreSQL. Cada **linha** da tabela será um utilizador.

**`t.string :email, null: false`** — Coluna texto; **`null: false`** = NOT NULL na BD. Mesmo que o Ruby falhe, a BD não aceita `INSERT` sem email.

**`t.string :password_digest, null: false`** — Onde fica o **hash** bcrypt. O nome **`password_digest`** é a convenção de `has_secure_password`; tem de existir e ser obrigatório.

**`t.string :timezone, null: false`** — Fuso horário IANA (ex. `Europe/Lisbon`) para relatórios; obrigatório neste MVP.

**`t.string :display_name`** — Sem `null: false`: pode ficar **NULL** na BD se o cliente não enviar nome.

**`t.timestamps`** — Cria **`created_at`** e **`updated_at`** (tipo `datetime`). O ActiveRecord preenche-os em `create`/`update`.

**`add_index :users, :email, unique: true`** — Cria um **índice** na coluna `email`. **`unique: true`** impede dois registos com o mesmo email ao nível SQL (reforço além da validação no model). Também acelera **`find_by(email: ...)`** no login.

**`rails db:migrate`** — Aplica migrações pendentes e actualiza **`db/schema.rb`**, que é o “retrato” do schema que o Rails conhece. Só depois disto o model `User` pode assumir que essas colunas existem.

---

## Passo 4 — Model `User`

**Porquê este passo** — **Para quê:** a tabela apenas guarda **dados**; o **model** é onde definimos **regras de negócio** por registo: email válido e único, senha forte, timezone IANA, normalização do email. Também activa `has_secure_password` para preencher `password_digest` sem nunca guardar senha em claro. **Porque depois da migration:** o modelo assume que as colunas (ex.: `password_digest`, `timezone`) já existem. **Depois:** os controllers (Passo 8) fazem `User.new` / `user.save` / `find_by` / `authenticate` em cima destas regras.

Cria o ficheiro `**app/models/user.rb`** com:

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

**Entender o ficheiro (Passo 4)**

**`class User < ApplicationRecord`** — Liga a classe Ruby à tabela **`users`** por convenção (nome plural). `ApplicationRecord` herda de `ActiveRecord::Base`: ganhas `save`, `find_by`, validações, etc.

**`has_secure_password`** — Adiciona ao model os atributos virtuais **`password`** e **`password_confirmation`** (não são colunas na BD). No **`save`**, se `password` estiver presente, gera bcrypt e grava em **`password_digest`**. No login, **`user.authenticate("texto")`** compara com esse digest. A senha em claro **nunca** é persistida.

**`before_validation :normalize_email`** — Antes de correr as **`validates`**, o Rails chama **`normalize_email`**. Assim `email` já está **trim** e **minúsculas** quando testas formato e unicidade — evita `Jo@x.com` vs `jo@x.com` como contas diferentes.

**`validates :email, presence: true, format: …, uniqueness: { case_insensitive: true }`** — **`presence`** não aceita vazio/nil. **`format: URI::MailTo::EMAIL_REGEXP`** é uma regex “boa o suficiente” para email. **`uniqueness: { case_insensitive: true }`** garante um email por conta **ignorando** maiúsculas (consulta à BD com `LOWER(email)`).

**`validates :timezone, presence: true`** — Obriga timezone não vazio antes de gravar.

**`validates :password, presence: true, length: { minimum: 8 }, if: -> { password_digest.nil? || password.present? }`** — O **`if`** é um lambda: só valida password quando **ainda não há digest** (conta nova) **ou** quando o pedido traz um novo `password` (alteração futura). Assim um PATCH sem campo password não exige redefinir senha.

**`validates :password_confirmation, presence: true, on: :create`** — **`on: :create`** limita esta regra ao **primeiro** registo: na criação exiges confirmação; em updates normais não ficas preso a enviar `password_confirmation` sempre.

**`validate :timezone_must_be_known, if: -> { timezone.present? }`** — Chama o método **`timezone_must_be_known`** na fase de validação, **só** se `timezone` tiver texto (evita validar TZ quando o erro real é “campo vazio”, já coberto por `presence`).

**`private`** — Os métodos abaixo não são parte da “API” pública do model para outros programadores chamarem; o Rails continua a invocá-los internamente (`before_validation`, `validate`).

**`normalize_email`** — **`self.email =`** altera o atributo na instância corrente. **`email.to_s.strip.downcase`** garante string (`.to_s`), remove espaços à volta (**`.strip`**), minúsculas (**`.downcase`**).

**`timezone_must_be_known`** — **`TZInfo::Timezone.get(timezone)`** levanta excepção se o identificador não for IANA válido. O **`rescue`** apanha isso e **`errors.add(:timezone, …)`** acrescenta mensagem ao objecto de erros do ActiveModel — o controller pode devolver **422** com essa mensagem em vez de **500**.

---

## Passo 5 — Serviço `JsonWebToken`

**Porquê este passo** — **Para quê:** depois do login o cliente precisa de prova **sem estado no servidor** (“sou o utilizador X”) — o JWT compacta isso. Este serviço **centraliza** assinatura (`encode`) e verificação (`decode`) com HS256 e o segredo do Passo 2, para não espalhar detalhes JWT pelos controllers. **Porque depois do model:** o token só precisa do `user.id` (`sub`); o `User` já existe para criar conta e autenticar. **Depois:** `Authenticable` (Passo 6) chama `JsonWebToken.decode` em cada pedido protegido.

Garante que existe a pasta `**app/services`**. Cria `**app/services/json_web_token.rb`**:

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

**Entender o ficheiro (Passo 5)**

**Classe e constante `EXP`** — `JsonWebToken` agrupa só lógica estática (sem `initialize`). **`EXP = 24.hours`** usa ActiveSupport: é um objeto `Duration`; em **`encode`** combina-se com **`Time.current + EXP`** para definir **quando** o token deixa de ser válido (claim **`exp`** no JWT).

**`class << self`** — Abre o “eigenclass” da classe: os métodos definidos aí tornam-se **métodos de classe** (`JsonWebToken.encode`), úteis para serviços que não precisam de estado por instância.

**`encode(user_id:, exp: Time.current + EXP)`** — Argumentos **keyword**: obrigas **`user_id:`**; **`exp:`** é opcional e tem valor por defeito “agora + 24h”. **`exp.to_i`** converte para **segundos Unix** (inteiro), formato que a norma JWT espera no claim `exp`.

**`payload = { sub: user_id, exp: exp.to_i }`** — **`sub`** (“subject”) guarda **quem** é o token — aqui o `id` do utilizador. **`exp`** é o instante de expiração. Estes pares vão dentro do payload assinado.

**`JWT.encode(payload, secret, "HS256")`** — Assina o payload com **HMAC-SHA256** usando `secret`. O terceiro argumento fixa o algoritmo no cabeçalho do token. Sem o segredo correcto, ninguém produz uma assinatura que `decode` aceite.

**`decode(token)` — início** — **`token.blank?`** (Rails) cobre `nil`, string vazia e string só com espaços: devolves **`nil`** cedo para não chamar a gema com lixo.

**`JWT.decode(token, secret, true, { algorithm: "HS256" })`** — O terceiro argumento **`true`** é **“verify signature”** — obriga a validar a assinatura e o `exp`. O **hash** final **`{ algorithm: "HS256" }`** força o algoritmo admitido (mitiga ataques em que o atacante tenta outro `alg`). O retorno da gema é um **array**; o **`.first`** é o hash do payload.

**`.symbolize_keys`** — Garante chaves como **`:sub`** e **`:exp`** em Ruby (o decode pode devolver strings como chaves).

**`rescue JWT::DecodeError`** — Qualquer problema de assinatura, formato ou expiração cai aqui; devolves **`nil`** para o `Authenticable` tratar como “sem utilizador”.

**`secret` (privado)** — **`Rails.application.credentials[:jwt_secret]`** lê o YAML das credentials. **`.presence`** devolve `nil` se for `nil` ou string só com espaços. **`|| ENV["JWT_SECRET"]`** tenta a env a seguir. **`raise … if key.blank?`** impede o servidor de emitir tokens com segredo em branco (falha explícita em vez de comportamento silencioso e inseguro).

---

## Passo 6 — Concern `Authenticable`

**Porquê este passo** — **Para quê:** cada pedido com `Authorization: Bearer` precisa de código que **abra o header**, **valide o JWT** (via `JsonWebToken`) e **carregue o `User`** — senão **repetirias** essa lógica em cada controller. O concern concentra `current_user` e `authenticate_user!`. **Porque depois do serviço JWT:** reutiliza `decode`; **antes** dos controllers finais que chamam `before_action`. **Depois:** `BaseController` inclui isto uma vez; `MeController` protege rotas sem duplicar código.

Cria `**app/controllers/concerns/authenticable.rb`**:

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

**Entender o ficheiro (Passo 6)**

**`module Authenticable`** — Agrupa métodos que vão ser **misturados** num controller com `include Authenticable`. O ficheiro vive em `app/controllers/concerns/` por convenção Rails.

**`extend ActiveSupport::Concern`** — Padrão oficial de “concern”: permite no futuro usar blocos como `included do … end` para configurar o host quando o módulo for incluído, sem hacks frágeis.

**`private`** — `authenticate_user!` e `current_user` não são **actions**; ficam como helpers. O **`before_action`** do Rails chama-os na mesma instância do controller — a visibilidade `private` não bloqueia isso.

**`authenticate_user!`** — Nome com **`!`** por convenção (“pode falhar de forma visível”). Primeiro chama **`current_user`**: se devolver um `User`, o **`return`** sai — a action continua. Se for **`nil`**, **`render json: … status: :unauthorized`** envia **401** com corpo JSON. (Nota: em actions mais longas, após `render` convém **`and return`** para garantir que nada abaixo corre; neste MVP as actions são curtas.)

**`@current_user ||= begin … end`** — **`||=`** significa: “se `@current_user` for ainda `nil` ou `false`, executa o bloco e guarda o resultado; senão reutiliza o valor”. Na **primeira** chamada a `current_user` no request, corres decode + `find_by`; nas seguintes (na mesma request) **não** repetis o trabalho.

**`request.headers["Authorization"].to_s`** — **`request`** é o pedido HTTP actual. **`headers["Authorization"]`** devolve o valor do cabeçalho ou `nil`. **`.to_s`** converte `nil` em `""` para poderes sempre chamar métodos de string em seguida.

**`header.split.last`** — Para `"Bearer eyJ…"`, **`split`** parte por espaços em `["Bearer", "eyJ…"]`; **`.last`** fica o token. Se o cabeçalho estiver mal formatado, o valor pode não ser um JWT válido — o **`decode`** trata e devolve `nil`.

**`JsonWebToken.decode(token)`** — Centraliza validação; **`nil`** = “não autenticável”.

**`return nil unless payload && payload[:sub]`** — Sem payload ou sem **`:sub`**, não há id de utilizador fiável — devolves **`nil`**.

**`User.find_by(id: payload[:sub])`** — Carrega o `User` com esse **primary key**. Se o token for velho mas a conta foi apagada, **`find_by`** devolve **`nil`** — comporta-se como sessão inválida.

---

## Passo 7 — `Api::V1::BaseController`

**Porquê este passo** — **Para quê:** rotas autenticadas partilham o mesmo comportamento (saber **quem** é `current_user`, poder bloquear com 401). Um `BaseController` sob `Api::V1` é o sítio único para `**include Authenticable`** para os controllers que **herdam** dele. **Porque separado de `ApplicationController`:** signup/login ficam sem token e herdam só de `ApplicationController`; `/me` herda de `BaseController` para obrigar JWT. **Depois:** defines rotas (Passo 9) que apontam para controllers que já seguem esta hierarquia.

Cria as pastas `**app/controllers/api/v1`**. Cria `**app/controllers/api/v1/base_controller.rb`**:

```ruby
module Api
  module V1
    class BaseController < ApplicationController
      include Authenticable
    end
  end
end
```

O `[ApplicationController](../../../../app/controllers/application_controller.rb)` já pode ficar só com `class ApplicationController < ActionController::API` — não precisas do concern aqui.

**Entender o ficheiro (Passo 7)**

**`module Api` / `module V1` (aninhados)** — Em Ruby, `module Api; module V1; class BaseController` define a constante **`Api::V1::BaseController`**. O caminho do ficheiro **`app/controllers/api/v1/base_controller.rb`** tem de corresponder a esse nome (Zeitwerk / autoload). As rotas **`namespace :api`** e **`namespace :v1`** geram URLs com prefixo **`/api/v1`** e resolvem controllers sob esse namespace.

**`class BaseController < ApplicationController`** — Herda tudo o que definires no `ApplicationController` global (por exemplo `ActionController::API`). É o “pai” só da **árvore API v1**, não de signup/login se esses herdarem directamente de `ApplicationController`.

**`include Authenticable`** — Copia os métodos do módulo para esta classe e para **subclasses**. Assim `MeController < BaseController` herda automaticamente `current_user` e `authenticate_user!` sem repetir ficheiros.

**Porque não `include Authenticable` no `ApplicationController`** — `RegistrationsController` e `SessionsController` herdam de `ApplicationController` e **não** devem exigir JWT. Só controllers “atrás do login” herdam de **`BaseController`** e ganham o concern.

---

## Passo 8 — Controllers de registo e sessão

**Porquê este passo** — **Para quê:** são as **portas HTTP** da feature: criar conta, obter token, consultar/editar perfil. Traduzem JSON → modelo → JSON e códigos HTTP correctos (`201`, `401`, `422`). **Porque depois de models + JWT + concern:** já tens peças para persistir utilizador, emitir token e resolver `current_user` em `/me`. **Depois:** sem rotas (Passo 9) estes métodos não têm URL pública; o Passo 11 valida o fluxo completo.

`**app/controllers/api/v1/registrations_controller.rb`**

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

`**app/controllers/api/v1/sessions_controller.rb**`

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

`**app/controllers/api/v1/me_controller.rb**`

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

**Entender os ficheiros (Passo 8)**

**Namespaces `Api::V1`** — Igual ao Passo 7: cada ficheiro sob `app/controllers/api/v1/` declara `module Api` / `module V1` para o nome da classe bater com o router.

**RegistrationsController**

- **`class … < ApplicationController`** — Signup **sem** Bearer; o cliente ainda não tem token.
- **`def create`** — Action invocada por **`POST /api/v1/signup`**. O corpo HTTP JSON vira **`params`** no Rails.
- **`User.new(user_params)`** — Constrói um registo **em memória**; ainda não há `INSERT` na BD. Só os atributos que **`user_params`** permitir entram no objecto (protecção contra *mass assignment*).
- **`user.save`** — Valida, hasheia password se aplicável, e faz **`INSERT`** se válido; devolve **`true`**/`false`.
- **`render json: … status: :created`** — **`status: :created`** é HTTP **201** “recurso criado”. O JSON inclui **`token`** (novo JWT com `sub: user.id`) e **`user`** (perfil sem secrets).
- **`render json: … status: :unprocessable_entity`** — HTTP **422**: pedido bem formado mas regras de negócio falharam (validações). **`user.errors.full_messages`** é um array de strings legível para o cliente.
- **`user_params`** — **`require(:user)`** faz **`400`-style** se faltar a chave `user` no JSON (Strong Parameters). **`permit(...)`** lista **whitelist** de colunas que o cliente pode escrever.
- **`user_json(user)`** — Monta hash Ruby que o `render json:` converte em JSON. **`.compact`** remove pares com valor **`nil`** (ex.: `display_name` ausente).

**SessionsController**

- **`find_by(email: …)`** — Procura **uma** linha; devolve `nil` se não existir. O email normaliza-se como no model para bater com o que está na BD.
- **`user&.authenticate(session_params[:password])`** — **`&.`** safe navigation: se `user` for `nil`, a expressão inteira é **`nil`** (short-circuit) — não chamas `authenticate` em `nil`. Se `user` existir, **`authenticate`** compara com `password_digest`.
- **`status: :ok`** — HTTP **200**; aqui significa “login ok”, não “criado”.
- **`status: :unauthorized`** — HTTP **401** “não autenticado”; mensagem genérica para email ou password errados.
- **`session_params`** — **`params.permit(:email, :password)`** na **raiz** porque o JSON de login **não** tem `"user": { … }`.

**MeController**

- **`class … < BaseController`** — Herda **`include Authenticable`** indirectamente.
- **`before_action :authenticate_user!`** — Antes de **`show`** e **`update`**, corre o porteiro; se falhar, a action nem chega a correr o teu código útil.
- **`show`** — Só **`render`** do `current_user` já resolvido pelo token.
- **`update`** — **`current_user.update(me_params)`** aplica PATCH parcial só nos atributos permitidos; **`if`** escolhe **200** + JSON ou **422** + erros.
- **`me_params`** — **`require(:user).permit(:timezone, :display_name)`** — o PATCH **tem** de trazer `"user": { … }`; não **permites** `password` aqui no MVP.

---

## Passo 9 — Rotas

**Porquê este passo** — **Para quê:** ligar **URLs estáveis** (`/api/v1/signup`, etc.) aos **métodos** que implementaste — sem isto o Rails devolve 404 mesmo com controllers correctos. **Porque ao fim dos controllers:** primeiro existe código a invocar; as rotas só publicam esse contrato. **Depois:** sobes o servidor (Passo 10) e testas com Insomnia (Passo 11) usando exactamente estes paths.

Abre `[config/routes.rb](../../../../config/routes.rb)` e deixa assim (podes manter o comentário do `up` se quiseres):

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
rails routes | grep api
```

**Entender o ficheiro (Passo 9)**

**`Rails.application.routes.draw do … end`** — Todo o roteamento da aplicação vive neste bloco. O ficheiro é `config/routes.rb`; é lido quando o servidor (Puma) arranca.

**`get "up" => "rails/health#show", as: :rails_health_check`** — Mapeia **`GET /up`** para o controller interno de saúde do Rails. **`as:`** dá nome à rota para helpers (`rails_health_check_path`); útil para monitorização, não para a API de negócio.

**`namespace :api do`** — Prefixa URLs com **`/api`** e espera classes sob o módulo **`Api::`**. O ficheiro do controller fica em `app/controllers/api/`.

**`namespace :v1 do`** — Dentro de `api`, prefixa com **`/v1`** e módulo **`V1`**. URL final: **`/api/v1/...`**.

**`post "signup", to: "registrations#create"`** — **`post`** = método HTTP POST. A string **`"signup"`** define o segmento de path (junto com namespaces → **`/api/v1/signup`**). **`to:`** diz **`controller#action`**: ficheiro `registrations_controller.rb`, classe `RegistrationsController`, método **`create`**.

**`post "login", to: "sessions#create"`** — Idem para **`/api/v1/login`** → **`SessionsController#create`**.

**`get "me", to: "me#show"`** — **`GET`** é idempotente e só leitura; **`/api/v1/me`** → **`MeController#show`**.

**`patch "me", to: "me#update"`** — **`PATCH`** para actualização parcial do recurso “eu”; mesmo path base **`/me`**, verbo diferente do GET.

**`rails routes | grep api`** — **`rails routes`** lista todas as rotas; **`grep api`** filtra linhas com “api” para veres só o que interessa à API.

---

## Passo 10 — Subir o servidor

**Porquê este passo** — **Para quê:** o código só executa quando o processo **Puma** está a ouvir pedidos HTTP; o Insomnia precisa de um host:porta (típico `localhost:3000`). **Porque depois das rotas:** garantes que o router e os controllers carregam no arranque. **Depois:** experimentas os pedidos reais no Passo 11.

```bash
rails server
```

Por defeito: `http://localhost:3000`.

**Entender o comando (Passo 10)**

**`rails server`** — Arranca o processo do servidor web (**Puma** por defeito no Rails 7+). Ele carrega a aplicação Rails (ambiente, autoload, rotas) e fica à escuta de pedidos TCP.

**`config.ru`** — Ficheiro Rack na raiz; é o “ponto de entrada” que o Puma usa para delegar pedidos à stack Rails.

**`localhost` e porta `3000`** — Por defeito o servidor **liga-se** a todas as interfaces ou só a localhost conforme versão/config; na prática usas **`http://127.0.0.1:3000`** ou **`http://localhost:3000`**. O Passo 11 monta URLs completas com esse host.

**`rails s`** — Atalho idêntico a **`rails server`**.

**`-p PORTA`** — Opção para outra porta (ex.: **`rails s -p 4000`**) se **3000** estiver ocupada.

**Parar o servidor** — **Ctrl+C** no terminal mata o processo; deixa de haver servidor a ouvir até voltares a correr `rails s`.

---

## Passo 11 — Testes no Insomnia (ordem)

**Porquê este passo** — **Para quê:** validares o **contrato** fim-a-fim: corpo JSON, cabeçalhos, códigos de estado e formato da resposta — o browser ainda não existe (Vue vem depois). **Porque nesta ordem (signup → login → /me → PATCH):** o token só faz sentido depois de existir utilizador; `/me` prova que o Bearer funciona. **Depois:** opcionalmente confirmas na BD (Passo 12) que o registo ficou materializado.

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

**Entender os corpos JSON (Passo 11)**

**O que o Rails faz com o body** — Com **`Content-Type: application/json`**, o middleware parseia o corpo e preenche **`params`** com chaves de texto (e por vezes símbolos consoante o acesso). Os controllers usam **`params.require` / `permit`** para ler com segurança.

**Header `Content-Type: application/json`** — Diz ao servidor que o corpo é JSON; sem isto o parse pode falhar ou `params` ficar vazio.

**Signup / PATCH — objecto `"user"`** — Agrupa atributos do model. **`params.require(:user)`** no controller **levanta erro** se a chave `"user"` faltar — falhas cedo com pedido mal formado. Cada campo dentro de `user` vira **`params[:user][:email]`**, etc.

- **`email`** — Vai para validação de presença, formato e unicidade no `User`.
- **`password` / `password_confirmation`** — Não são colunas: o `has_secure_password` usa-os só em memória e grava **`password_digest`**. A confirmação reduz erros de digitação na criação.
- **`timezone`** — String que o Passo 4 valida como IANA (TZInfo).
- **`display_name`** — Opcional no model; pode ser omitido ou `null`.

**Header `Authorization: Bearer <token>`** — No **`GET /me`** e **`PATCH /me`**, o **`Authenticable`** lê este cabeçalho. **`Bearer`** é o esquema; a seguir vem o JWT **sem** aspas no valor real.

**Login — raiz com `email` e `password`** — O mesmo **`params`**, mas **sem** aninhar em `user`; por isso **`session_params`** usa **`params.permit(:email, :password)`** directamente. Se aqui usasses `require(:user)`, o login deste plano quebrava.

**Ordem dos pedidos (1→2→3→4)** — Signup cria linha na BD e devolve token; login obtém **outro** token para o mesmo user; GET `/me` prova que o token identifica o `User`; PATCH opcional testa `me_params` e respostas 422 se enviares timezone inválido, etc.

---

## Passo 12 — Ver na base de dados (confirmação)

**Porquê este passo** — **Para quê:** além do JSON no Insomnia, vês **na fonte** que o email, timezone e `**password_digest`** (hash bcrypt, nunca texto claro) estão gravados — liga o que aprendeste sobre migrations modelos à realidade PostgreSQL. **Porque no fim:** só faz sentido depois de um signup bem-sucedido. **Depois:** checklist final + documentar rotas em `api-rotas.md` se ainda não o fizeste.

**DBeaver (alternativa recomendada em GUI):** cria uma ligação **PostgreSQL** com os **mesmos** valores que `**config/database.yml**` para `development` (host, porta, nome da BD, utilizador, password). Abre o SQL Editor na base do projecto e corre o mesmo `SELECT` abaixo; não precisas de **`rails dbconsole`** se preferires explorar esquema e dados no DBeaver.

```bash
rails dbconsole
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

**Entender a confirmação na BD (Passo 12)**

**Porque voltar à BD** — O JSON da API pode mentir por bug teu; a tabela **`users`** é a **fonte de verdade** do que ficou persistido após o signup.

**`rails dbconsole`** — Abre o cliente de linha de comando **psql** (PostgreSQL) já com **user**, **host**, **database** e **password** lidos de **`config/database.yml`** para o ambiente actual (normalmente `development`). Não precisas de copiar credenciais à mão.

**DBeaver** — GUI alternativa: crias uma “PostgreSQL connection” com os **mesmos** quatro dados (host, porta, database, user, password). Executas o mesmo SQL num editor de queries.

**`SELECT id, email, timezone, display_name`** — Projecta colunas de perfil que correspondem ao que também mostras no JSON `user` (sem revelar digest completo na listagem se não quiseres).

**`password_digest IS NOT NULL AS tem_hash_senha`** — Expressão booleana por linha: **`true`** se a coluna digest existe e não é `NULL` — confirma que o `save` do Rails correu o fluxo bcrypt. O alias **`tem_hash_senha`** só renomeia a coluna no resultado para leres melhor.

**`FROM users`** — Tabela física mapeada pelo model `User` (`users` plural).

**`ORDER BY id DESC`** — Ordena pelo `id` descendente: os **últimos** registos criados aparecem primeiro (útil em dev com muitos testes).

**`LIMIT 5`** — Corta o resultado a cinco linhas para não despejar a tabela inteira no ecrã.

**`\q`** — Comando **do programa psql** para sair (meta-comando). No DBeaver não usas `\q`; fechas a janela ou desligas a ligação.

---

## Checklist final

- Passos 1–9 feitos sem erros de consola.
- Insomnia (ou Postman): signup → login → GET `/me` OK.
- **`rails c`** (opcional): experimentar `**User**` / tokens se quiseres fixar o fluxo em Ruby.
- BD: linha em `users` visível — **DBeaver** ou Passo 12 com `**rails dbconsole**`.
- Documentaste as rotas em `[../../api-rotas.md](../../api-rotas.md)` (copia o contrato + exemplos que usaste).

## Referências

- Visão técnica global: `[../../../../lords-mobile-tracker-api-planejamento.md](../../../../lords-mobile-tracker-api-planejamento.md)`.

