# Etapa 01 — Autenticação JWT (para fazeres tu, passo a passo)

## Objetivo

Ter **cadastro** e **login** em JSON com **JWT**, mais **GET/PATCH** em `/api/v1/me` com o header `**Authorization: Bearer`**. A “tela” Vue fica para depois; testas na API com **Insomnia** ou Postman, podes repetir cenários em **`rails c`**, e na base de dados com **DBeaver** ou `**rails dbconsole**` (Passos 11 e 12). Segue a ordem **à letra**; em cada passo grava o ficheiro e só avança quando não houver erro.

**Pré-requisito:** PostgreSQL a correr e `**rails db:create`** já feito neste projecto (se `**rails db:migrate**` falhar por BD inexistente, corre `**rails db:create**` antes). Se algo não encontrar `rails`, usa `**bundle exec rails …**` ou `**bin/rails …**` (mesmo comandos na pasta do projecto).

**Como ler este plano:** antes de cada trecho há **Porquê este passo** (objectivo, ordem no fluxo, ligação ao que se segue). Depois vêm comandos ou código para copiar. Em **Linha-a-linha**, cada entrada segue sempre o mesmo formato: **O que faz** / **Por que existe** / **Quando roda** — sem exemplo nem “erros comuns”.

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

**Linha-a-linha (Passo 1)**

- `**gem "bcrypt", …*`* (Gemfile) — **O que faz:** declara a dependência bcrypt. **Por que existe:** `has_secure_password` precisa bcrypt para criar/comparar o hash na coluna `**password_digest`**. **Quando roda:** na instalação de gemas (após gravar o Gemfile).
- `**gem "jwt", "~> 2.8"`** — **O que faz:** pede ao Bundler a gema JWT na faixa compatível (~> 2.8). **Por que existe:** assinar e verificar tokens no Passo 5. **Quando roda:** `bundle install` após editar o Gemfile.
- `**bundle install`** — **O que faz:** instala todas as gemas listadas segundo `Gemfile`/`Gemfile.lock`. **Por que existe:** garantir bcrypt e JWT na máquina antes de corrermos código dependente. **Quando roda:** no terminal quando o inicias após mudar gemas.

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

**Linha-a-linha (Passo 2)**

- `**EDITOR="nano"`** (antes de `rails credentials:edit`) — **O que faz:** indica qual editor abrir para o YAML temporário. **Por que existe:** evitar abrir um editor por defeito que não domines. **Quando roda:** só nessa invocação do comando no terminal.
- `**rails credentials:edit`** — **O que faz:** desencripta `config/credentials.yml.enc`, abre o YAML e, ao gravar, regrava o `.enc` encriptado (com `master.key` / `RAILS_MASTER_KEY`). **Por que existe:** segredos versionados encriptados em vez de texto claro no repo. **Quando roda:** quando executas o comando no terminal; equivalente `**bin/rails`** / `**bundle exec rails**`.
- `**jwt_secret:**` (no YAML) — **O que faz:** define a chave lida em Ruby como `Rails.application.credentials[:jwt_secret]`. **Por que existe:** o `JsonWebToken` (Passo 5) precisa do mesmo segredo para assinar e validar. **Quando roda:** cada vez que o processo Rails resolve `secret` com credentials carregadas após teres gravado o valor.
- `**JWT_SECRET`** (alternativa em dev) — **O que faz:** variável de ambiente usada quando `:jwt_secret` nas credentials está em branco (`.presence`). **Por que existe:** dev/CI sem editar credentials em cada máquina. **Quando roda:** quando o processo Rails arranca com esta env definida e o código chama `secret`.

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

**Linha-a-linha (Passo 3)**

- `**rails generate migration CreateUsers …`** — **O que faz:** cria ficheiro em `db/migrate/` com esqueleto de migração. **Por que existe:** poupas escrever só a estrutura inicial; o `change` do plano afinas à mão. **Quando roda:** uma vez no terminal antes de editares o ficheiro.
- `**class CreateUsers < ActiveRecord::Migration[8.1]`** — **O que faz:** declara a migração ligada à versão da API Rails. **Por que existe:** o Runner precisa duma classe nomeada. **Quando roda:** em `migrate`/`rollback`; usa o número que o gerador tiver posto (mantém-no).
- `**def change`** — **O que faz:** descreve alterações ao schema num único bloco. **Por que existe:** convenção reversível em muitos casos. **Quando roda:** ao executares `rails db:migrate`.
- `**create_table :users do |t|`** — **O que faz:** cria a tabela física `users`. **Por que existe:** armazenamento de contas na BD. **Quando roda:** durante esta migração.
- `**t.string :email, null: false`** — **O que faz:** coluna texto com **NOT NULL**. **Por que existe:** email obrigatório ao nível SQL. **Quando roda:** quando a migração corre; em INSERT/UPDATE seguintes.
- `**t.string :password_digest, null: false`** — **O que faz:** coluna obrigatória para o hash bcrypt. **Por que existe:** convenção de `has_secure_password`. **Quando roda:** migração + preenchimento ao gravar password.
- `**t.string :timezone, null: false`** — **O que faz:** guarda o identificador de fuso (IANA). **Por que existe:** semana/dia civil corretos nos relatórios. **Quando roda:** migração + obrigação em cada registo completo.
- `**t.string :display_name`** — **O que faz:** nome opcional sem `NOT NULL`. **Por que existe:** perfil sem obrigar apelido na BD. **Quando roda:** migração + saves como `NULL` se vazio.
- `**t.timestamps`** — **O que faz:** cria `created_at` e `updated_at`. **Por que existe:** auditoria temporal padrão Rails. **Quando roda:** preenchidos pelo ActiveRecord em operações de save.
- `**add_index :users, :email, unique: true`** — **O que faz:** índice único sobre `email`. **Por que existe:** busca rápida por email e reforço anti-duplicados na BD. **Quando roda:** na migração; uso contínuo pelo PostgreSQL em consultas/chaves.
- `**rails db:migrate`** — **O que faz:** aplica migrações pendentes e actualiza `db/schema.rb`. **Por que existe:** alinhar BD com o código versionado. **Quando roda:** no terminal após teres ficheiros novos em `db/migrate`.

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

**Linha-a-linha (Passo 4)**

- `**class User < ApplicationRecord`** — **O que faz:** declarar modelo ActiveRecord ligado por convenção à tabela `**users`**. **Por que existe:** ponte entre Ruby e dados persistidos; herdas persistência e validações Rails. **Quando roda:** sempre que usas o model na consola ou nos controllers (`**save`**, queries, etc.).
- `**has_secure_password**` — **O que faz:** activa bcrypt e atributos virtuais de senha que preenchem `**password_digest`**. **Por que existe:** nunca guardar password em texto claro. **Quando roda:** em `**save`** com nova password e em `**authenticate**` no login.
- `**before_validation :normalize_email**` — **O que faz:** regista um callback antes da fase `**valid?`**. **Por que existe:** validações e unicidade verem o email já **trim** + minúsculas. **Quando roda:** antes de `**validates …`** em cada `**save**` / `**valid?**`.
- `**validates :email, presence: true, format: …, uniqueness: { case_insensitive: true }**` — **O que faz:** exige valor, formato tipo email e email único (ignora casing). **Por que existe:** identidade estável por conta; evita dois emails “iguais” só mudando maiúsculas. **Quando roda:** dentro do ciclo `**validate`** em `**save**`.
- `**validates :timezone, presence: true**` — **O que faz:** exige timezone não vazio. **Por que existe:** relatórios no produto assumem TZ IANA fixo por utilizador. **Quando roda:** ciclo `**validate`** quando o atributo entra na validação.
- `**validates :password … if: -> { … }**` — **O que faz:** exige password presente e ≥ 8 caracteres só quando ainda não há hash **ou** o pedido inclui novo `**password`**. **Por que existe:** PATCH de perfil sem password não obriga redefinir hash. **Quando roda:** quando o lambda do `**if`** é verdadeiro no `**validate**`.
- `**validates :password_confirmation, presence: true, on: :create**` — **O que faz:** na **criação** exige campo `**password_confirmation`**. **Por que existe:** reduz typo na password inicial; updates sem troca de password não ficam obrigados a confirmação. **Quando roda:** só no primeiro `**save`** de registo novo (`**on: :create**`).
- `**validate :timezone_must_be_known, if: -> { timezone.present? }**` — **O que faz:** chama método de validação custom só quando `**timezone`** já tem valor. **Por que existe:** validar TZ real (IANA); evita dois erros diferentes pelo mesmo problema vazio. **Quando roda:** durante `**validate`** quando `**present?**`.
- `**private**` — **O que faz:** torna métodos abaixo invisíveis como API pública do model. **Por que existe:** `normalize_email` e `timezone_must_be_known` só existem para o Rails (`before_validation`, `validate`), não para chamar à mão desde fora como “serviços”. **Quando roda:** em tempo de verificação de visibilidade do Ruby sempre que há chamadas directas ilegítimas desde fora da instância.
- `**def normalize_email` / `self.email = email.to_s.strip.downcase`** — **O que faz:** reescreve `**email`** com string segura, sem espaços laterais e em minúsculas. **Por que existe:** alinhar parâmetro JSON com `**find_by(email:)`** e com unicidade. **Quando roda:** sempre que `**before_validation`** dispara antes de `**save**`.
- `**TZInfo::Timezone.get(timezone)**` — **O que faz:** falha por excepção se o identificador IANA não for conhecido. **Por que existe:** barreira extra além da string “só estar preenchida”. **Quando roda:** durante `**timezone_must_be_known`** na fase `**validate**`.
- `**rescue …` / `errors.add(:timezone, …)**` — **O que faz:** apanha TZ inválido e regista erro no ActiveModel (`**422`** no HTTP via controller). **Por que existe:** não deixar a excepção RAW subir até 500 quando o problema é entrada do cliente. **Quando roda:** quando `**Timezone.get`** levanta `**InvalidTimezoneIdentifier**`.

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

**Linha-a-linha (Passo 5)**

- `**class JsonWebToken`** — **O que faz:** declarar classe utilitarista só para JWT. **Por que existe:** concentrar encode/decode fora dos controllers. **Quando roda:** ao carregar a app e ao chamar `JsonWebToken.encode/decode`.
- `**EXP = 24.hours`** — **O que faz:** define tempo de vida padrão do token quando não passes `exp` explícito. **Por que existe:** segurança (token caduca); evita ficar válido indefinidamente neste MVP. **Quando roda:** quando `encode` usa o valor por defeito de `exp:`.
- `**class << self`** — **O que faz:** seguintes métodos tornam-se **de classe**. **Por que existe:** usar `JsonWebToken.encode(...)` sem instanciar. **Quando roda:** quando a classe é carregada em memória pelo Ruby.
- `**def encode(user_id:, exp: Time.current + EXP)`** — **O que faz:** recebe sempre `user_id`; `exp` opcional (valor por defeito **agora + EXP**). **Por que existe:** interface previsível nos controllers de signup/login. **Quando roda:** sempre que o servidor emite token após login/signup bem-sucedido.
- `**payload = { sub: user_id, exp: exp.to_i }`** — **O que faz:** monta dados (claims) gravados no corpo lógico do JWT. **Por que existe:** `sub` diz qual utilizador (`id`); `exp` limita validade em formato inteiro exigido pela norma JWT. **Quando roda:** imediatamente antes de `JWT.encode`.
- `**JWT.encode(payload, secret, "HS256")`** — **O que faz:** assina com HMAC‑SHA256 usando `secret` e devolve a string do token. **Por que existe:** o cliente não pode alterar o payload sem invalidar a assinatura. **Quando roda:** no fim de cada `encode` válido.
- `**def decode(token)` / `return nil if token.blank?`** — **O que faz:** sair cedo com `nil` quando não há string de token. **Por que existe:** evitar excepção na gema por argumento vazio. **Quando roda:** sempre que `decode` é chamado sem Bearer ou com token vazio.
- `**JWT.decode(token, secret, true, { algorithm: "HS256" })`** — **O que faz:** verifica assinatura, `exp`, e força algoritmo HS256. **Por que existe:** rejeitar tokens forjados ou com `alg` estranho. **Quando roda:** no ramo normal de `decode` quando o token não está em branco.
- `**.first.symbolize_keys`** — **O que faz:** extrai só o hash do payload e normaliza chaves para símbolo (`:sub`). **Por que existe:** o restante código usa `payload[:sub]`. **Quando roda:** após decode com sucesso.
- `**rescue JWT::DecodeError` / `nil`** — **O que faz:** converte falha de decode em `nil` em vez de erro não tratado na stack. **Por que existe:** camada do concern responde `**401`** de forma uniforme. **Quando roda:** quando `JWT.decode` falha (assinatura, formato, expiração, etc.).
- `**def secret` (privado)** — **O que faz:** devolve o segredo usado em `encode`/`decode`. **Por que existe:** um único sítio para ler credentials/env. **Quando roda:** sempre que `JWT.encode` ou `JWT.decode` precisam da chave nesta classe.
- `**Rails.application.credentials[:jwt_secret].presence || ENV["JWT_SECRET"]`** — **O que faz:** lê segredo encriptado primeiro; se só houver espaços, tenta variável de ambiente. **Por que existe:** mesmo código em dev/prod/CI sem valor no Git. **Quando roda:** em cada chamada a `secret`.
- `**raise "Missing …" if key.blank?`** — **O que faz:** interrompe com mensagem explícita quando não há segredo. **Por que existe:** falhar cedo antes de assinar JWT com chave inexistente. **Quando roda:** na primeira `secret` chamada sem configurar nada.

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

**Linha-a-linha (Passo 6)**

- `**module Authenticable`** — **O que faz:** agrupa lógica reutilizável que um controller `**include`**-a como mixin. **Por que existe:** partilhar `current_user` e `authenticate_user!` entre controllers autenticados. **Quando roda:** ao carregar ficheiros e sempre que método do concern é invocado dentro do controller incluido.
- `**extend ActiveSupport::Concern`** — **O que faz:** activa forma “oficial” Rails de escrever concerns (hooks opcionais `included` etc.). **Por que existe:** convenção Rails e comportamento estável quando módulos crescerem. **Quando roda:** na avaliação do módulo.
- `**private`** — **O que faz:** torna métodos seguintes apenas helpers internos do controller onde o concern está incluído. **Por que existe:** impedir usar `authenticate_user!`/`current_user` como se fossem URLs públicos. **Quando roda:** em todas as chamadas que respeitem visibilidade Ruby.
- `**def authenticate_user!`** — **O que faz:** interrompe a action com `**401`** se não há utilizador válido já resolvido. **Por que existe:** usar como `**before_action`** sem repetir código. **Quando roda:** no início de cada action marcada antes do corpo (`**before_action`**).
- `**return if current_user**` — **O que faz:** sai cedo assim que `**authenticate_user!`** determina que há utilizador (token válido → `**User**` carregado). **Por que existe:** já não há nada em falta para autorizar esta request; responder `**401`** seria erro. **Quando roda:** no início de `**authenticate_user!`**, sempre que `**current_user**` não é `**nil**`.
- `**render json: { error: "Unauthorized" }, status: :unauthorized**` — **O que faz:** devolve payload JSON `**401`** padrão mínimo. **Por que existe:** mesmo contrato sempre que Bearer falta/token inválido sem expor internals. **Quando roda:** quando `**current_user`** veio `**nil**` após tentativa de resolver.
- `**@current_user ||= begin … end**` — **O que faz:** calcula `**current_user`** só uma vez por request HTTP e guarda em variável instância. **Por que existe:** JWT decode repetido dentro da mesma request é desperdício. **Quando roda:** na primeira vez que código chama `**current_user`**; chamadas seguintes reutilizam memo.
- `**request.headers["Authorization"].to_s**` — **O que faz:** lê valor cabeçalho (`Bearer …`) garantindo sempre string mesmo se header ausente. **Por que existe:** evitar `nil` onde esperas método string. **Quando roda:** dentro do bloco de memoização sempre que há tentativa nova de `**current_user`**.
- `**header.split.last**` — **O que faz:** separa texto header por espaços e fica só último fragmento esperado sendo string JWT quando formato é `**Bearer TOKEN`**. **Por que existe:** parser mínimo sem regex para MVP que funciona bem com Bearer padrão. **Quando roda:** após ler header sempre que há parse token.
- `**JsonWebToken.decode(token)`** — **O que faz:** valida/descompacta usando service central (retorna `**nil`** se ruim). **Por que existe:** lógica assinatura fica só no service. **Quando roda:** depois extrair substring token sempre que há pedido Bearer.
- `**return nil unless payload && payload[:sub]`** — **O que faz:** aborta quando decode falhou não devolve dados mínimos (subject id). **Por que existe:** resto só corre com seguro `:sub`. **Quando roda:** imediatamente após `**decode`** se payload inválido.
- `**User.find_by(id: payload[:sub])**` — **O que faz:** carrega modelo `**User`** cujo `**id**` bate `**sub**` do token. **Por que existe:** transformar JWT em objecto utilizador trabalhável dentro actions. **Quando roda:** após saber `:sub`; devolve `**nil`** se conta apagada.

---

## Passo 7 — `Api::V1::BaseController ----->`

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

**Linha-a-linha (Passo 7)**

- `**module Api` / `module V1`** — **O que faz:** aninha nomes Ruby para ficar `**Api::V1::BaseController`** alinhados com estrutura de pastas. **Por que existe:** mesma hierarquia que `**namespace`** nas rotas evita mismatch constante vs URL. **Quando roda:** carregamento ficheiros; resolução de constantes sempre que há referências.
- `**class BaseController < ApplicationController`** — **O que faz:** define classe base API que herdas config global app (filtros, serializers se houver futuro). **Por que existe:** partilhar include concern sem poluir signup/login herdando ApplicationController só. **Quando roda:** arranque; cada request autenticada que passe por descendant.
- `**include Authenticable`** — **O que faz:** mistura métodos `current_user` + `authenticate_user!` dentro deste controller e filhos. **Por que existe:** um único `include` onde precisamos JWT sempre. **Quando roda:** avaliação métodos sempre que descendant chama métodos mixin.

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

**Linha-a-linha (Passo 8)**

*Nos três ficheiros, `module Api` / `module V1` repetem-se pelo mesmo motivo do Passo 7: estrutura em `app/controllers/api/v1/` e nomes de classe alinhados com as rotas.*

#### RegistrationsController

- `**class RegistrationsController < ApplicationController`** — **O que faz:** o signup **não** herda `Authenticable` (logo, sem exigir Bearer). **Por que existe:** registar a primeira conta antes de existir token JWT. **Quando roda:** em cada `**POST /api/v1/signup`**.
- `**def create**` — **O que faz:** trata o corpo JSON e cria a conta respondendo com JSON. **Por que existe:** a rota `**signup`** precisa duma **action** com este nome. **Quando roda:** em cada `**POST /api/v1/signup`** válido.
- `**user = User.new(user_params)**` — **O que faz:** cria um `User` só em memória, só com campos `**permit`** em `**user_params**`. **Por que existe:** impedir que o pedido HTTP escreva atributos que não queres aceitar (**mass assignment**). **Quando roda:** logo após validar/forjar `**user_params`** no `**create**` (signup).
- `**if user.save**` — **O que faz:** corre validações do model, faz hash da password e grava na BD se tudo passar. **Por que existe:** separar resposta `**201`** (sucesso) de `**422**` (validação). **Quando roda:** logo após `**User.new`** com parâmetros válidos.
- `**render json: { … }, status: :created**` — **O que faz:** devolve `**201`** com `**token**` JWT e `**user**` (sem expor password). **Por que existe:** o cliente (Insomnia ou front) pode logo chamar `**GET /me`**. **Quando roda:** quando `**save`** devolveu `**true**`.
- `**render json: { errors: … }, status: :unprocessable_entity**` — **O que faz:** devolve `**422`** com `**user.errors.full_messages**`. **Por que existe:** mesmo contrato sempre que o modelo rejeita dados. **Quando roda:** quando `**save`** é `**false**`.
- `**user_params**` — **O que faz:** obriga `**params[:user]`** e só deixa passar email, passwords, timezone e display name. **Por que existe:** limitar o que o HTTP pode escrever no model. **Quando roda:** ao construir `**User.new(user_params)`**.
- `**user_json**` — **O que faz:** monta o hash JSON “perfil público” e remove chaves com valor `**nil`** (`**compact**`). **Por que existe:** manter o mesmo formato de `**user`** nas respostas de signup, login e `**/me**`. **Quando roda:** antes de cada `**render`** de sucesso com `**user**` no JSON.

#### SessionsController

- `**class SessionsController < ApplicationController**` — **O que faz:** o login é **público** (sem concern `Authenticable`). **Por que existe:** o Bearer só é criado **nesta** action após validar email + password. **Quando roda:** cada `**POST /api/v1/login`**.
- `**find_by(email: … strip.downcase)**` — **O que faz:** procura o utilizador com o email normalizado (como no model, antes das validações). **Por que existe:** o email na BD está em minúsculas; o pedido pode trazer maiúsculas. **Quando roda:** no início de `**create`** (login).
- `**user&.authenticate(…)**` — **O que faz:** compara a password com `**password_digest`** (bcrypt); o `**?.**` evita erro se `**user**` for `**nil**`. **Por que existe:** mesma resposta genérica se o email não existir ou a password estiver errada. **Quando roda:** logo após `**find_by`** no login.
- `**render … status: :ok**` — **O que faz:** devolve `**200`** com `**token**` e `**user**` no mesmo formato que o signup (`**user_json**`). **Por que existe:** o cliente trata igual “conta já criada” e “voltar a entrar”. **Quando roda:** quando `**authenticate`** devolve verdadeiro.
- `**render … unauthorized**` — **O que faz:** responde `**401`** com mensagem genérica *Invalid credentials*. **Por que existe:** não dizer apenas por esse texto se o email existe ou só a password falhou (menos pistas para tentativas automatizadas de descobrir contas). **Quando roda:** quando não há utilizador ou a password falha.
- `**session_params*`* — **O que faz:** `**permit(:email, :password)`** no **nível raiz** dos `params`. **Por que existe:** no login o JSON do plano não traz objeto `**user`** — formato diferente do signup. **Quando roda:** ao início de `**create`** (login).

#### MeController

- `**class MeController < BaseController**` — **O que faz:** `**/me`** herda `**BaseController**`, onde já existe `**include Authenticable**`. **Por que existe:** todas as actions de perfil assumem Bearer válido sem repetir código. **Quando roda:** em cada pedido `**GET`** ou `**PATCH**` para `**/me**`.
- `**before_action :authenticate_user!**` — **O que faz:** corre `**authenticate_user!`** antes de `**show**` e `**update**`. **Por que existe:** sem token válido devolves `**401`** antes de qualquer lógica de perfil. **Quando roda:** início de cada action listada nos pedidos `**/me`**.
- `**def show**` — **O que faz:** constrói JSON com `**user_json(current_user)`**. **Por que existe:** endpoint `**GET /me`** apenas lê dados do utilizador autenticado. **Quando roda:** `**GET`** com `**Authorization: Bearer**` válido.
- `**def update` + `current_user.update(me_params)**` — **O que faz:** aplica alterações apenas no que `**me_params`** permitir (timezone e display name neste MVP). **Por que existe:** limitar PATCH sem expor mudança de password por este mesmo endpoint. **Quando roda:** `**PATCH /me`** com JSON `**user**` aninhado e Bearer válido.
- `**422` com lista de erros** — **O que faz:** se `**update`** falhar validações, devolves o mesmo envelope `**errors**` (e o mesmo código **422**) que no signup. **Por que existe:** cliente trata validações igual em todos os POST/PATCH nesta API. **Quando roda:** quando `**current_user.update(me_params)`** devolve `**false**`.

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

**Linha-a-linha (Passo 9)**

- `**Rails.application.routes.draw do`** — **O que faz:** começa o bloco onde defines todos os URLs e verbos HTTP da app. **Por que existe:** o Rails regista estas regras no arranque; sem isto há só 404 ou rotas defaults. **Quando roda:** ao iniciar Puma até mudares `**routes.rb`**.
- `**get "up" => "rails/health#show", as: :rails_health_check**` — **O que faz:** expõe `**GET /up**` como health check do framework. **Por que existe:** infraestrutura (load balancer, k8s) pode testar vida da app sem tocar na API de produto nem na BD necessariamente. **Quando roda:** em cada pedido a esse path — não faz parte da auth JWT.
- `**namespace :api do**` — **O que faz:** faz com que todas as linhas lá dentro esperem `**Api::**` controllers e `**/api/...**` no URL (por defeito). **Por que existe:** separar a API JSON das rotas “web” caso as tenhas mais tarde no mesmo projeto. **Quando roda:** sempre que resolves um URL sob `**/api**` (após migrações de rotas e restart se preciso).
- `**namespace :v1 do**` — **O que faz:** aninha outro nível (`**/api/v1/...**` e `**Api::V1::**`). **Por que existe:** podes criar `**v2**` com contratos diferentes sem apagar `**v1**` de imediato. **Quando roda:** em cada endpoint que ficou declarado dentro destes `**namespace**`-s.
- `**post "signup", to: "registrations#create"**` — **O que faz:** `**POST /api/v1/signup**` chama `**create**` na classe `**Api::V1::RegistrationsController**` (Rails infere o nome `**Registrations**` a partir da string `**registrations**`). **Por que existe:** expor registar conta sem Bearer. **Quando roda:** ao testar signup (Passo 11).
- `**post "login", to: "sessions#create"**` — **O que faz:** `**POST /api/v1/login**` chama `**Api::V1::SessionsController#create**`. **Por que existe:** trocar email+password por token JWT sem session cookie. **Quando roda:** em cada `**POST**` de login válido contra este path.
- `**get "me", to: "me#show"**` — **O que faz:** `**GET /api/v1/me**` chama `**Api::V1::MeController#show**`. **Por que existe:** ler perfil com Bearer (read-only por este verbo HTTP). **Quando roda:** Passo 11 após cópias do token.
- `**patch "me", to: "me#update"**` — **O que faz:** `**PATCH /api/v1/me**` chama `**#update**` com corpo JSON parcial. **Por que existe:** atualizar só campos permitidos sem `**`:id`** no path (**“eu”** = quem está no token). **Quando roda:** quando mandas **`PATCH`** com **`Authorization`**.

---

## Passo 10 — Subir o servidor

**Porquê este passo** — **Para quê:** o código só executa quando o processo **Puma** está a ouvir pedidos HTTP; o Insomnia precisa de um host:porta (típico `localhost:3000`). **Porque depois das rotas:** garantes que o router e os controllers carregam no arranque. **Depois:** experimentas os pedidos reais no Passo 11.

```bash
rails server
```

Por defeito: `http://localhost:3000`.

**Linha-a-linha (Passo 10)**

- `**rails server`** — **O que faz:** arranca **Puma** e liga-te ao `**config.ru`**, porta **3000** por defeito. **Por que existe:** sem processo HTTP nada das rotas pode ser testado (Insomnia, browser). **Quando roda:** até terminares este comando (**Ctrl+C**); atalho comum `**rails s`**.
- `**localhost:3000**` (valor por defeito) — **O que faz:** URL base onde o Passo 11 monta paths como `**http://localhost:3000/api/v1/signup`**. **Por que existe:** mesmo host onde o servidor escuta até mudares porta com `**-p`**. **Quando roda:** enquanto o servidor está levantado nessa porta.

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

**Linha-a-linha (Passo 11 — significado dos campos)**

*Estes snippets não são Ruby; são **corpos HTTP JSON** que o `**ActionDispatch`** transforma em `**params**` nos controllers.*

- `**"user": { … }` (Signup / PATCH)** — **O que faz:** aninha sob `**user*`* tudo que o `**RegistrationsController#user_params**` e `**MeController#me_params**` esperam ler. **Por que existe:** `**params.require(:user)`** falha ou filtra bem se esta chave existe e tem os campos certos; no Insomnia fica óbvio o que é recurso `**User**` vs metadados. **Quando roda:** quando envias signup ou PATCH com este wrapper.
- `**email`** — **O que faz:** identificador de conta e entrada de `**find_by`** no login. **Por que existe:** o modelo obriga unicidade/formato antes de `**save`**; normalizado no `**User**`. **Quando roda:** em signup e login.
- `**password` / `password_confirmation`** — **O que faz:** senha nova + segunda cópia que `has_secure_password` compara só em memória. **Por que existe:** confirma que o cliente não gravou erro de digitação sem guardar dois hashes; `**password_confirmation`** não tem coluna na BD — só validação ActiveModel. **Quando roda:** signup (opcional `**password_confirmation`** na validação forte — no plano envias-os em conjunto).
- `**timezone**` — **O que faz:** string IANA (ex.: `**Europe/Lisbon`**) que o `**User**` valida com TZInfo. **Por que existe:** relatórios e UI futuras com dias locais coherentes (**Passo 4**). **Quando roda:** signup obrigatório; PATCH opcional segundo `**me_params`**.
- `**display_name**` — **O que faz:** nome amigável opcional para respostas JSON. **Por que existe:** perfil pode existir só com email; `**.compact`** na resposta esconde chaves `**nil**`. **Quando roda:** signup ou PATCH quando quiseres texto visível ao utilizador.
- **Corpo do login sem `"user"` na raiz** — **O que faz:** `**email`** e `**password**` vêm ao nível topo do JSON. **Por que existe:** UX mais simples (dois campos); no código forças `**session_params`** com `**permit**` na raiz em vez de reutilizar `**user_params**`. **Quando roda:** `**POST /api/v1/login`** apenas.

---

## Passo 12 — Ver na base de dados (confirmação)

**Porquê este passo** — **Para quê:** além do JSON no Insomnia, vês **na fonte** que o email, timezone e `**password_digest`** (hash bcrypt, nunca texto claro) estão gravados — liga o que aprendeste sobre migrations modelos à realidade PostgreSQL. **Porque no fim:** só faz sentido depois de um signup bem-sucedido. **Depois:** checklist final + documentar rotas em `api-rotas.md` se ainda não o fizeste.

**DBeaver (alternativa recomendada em GUI):** cria uma ligação **PostgreSQL** com os mesmo valores que `**config/database.yml**` para `development` (host, porta, nome da BD, utilizador, password). Abre o SQL Editor na base do projecto e corre o mesmo `SELECT` abaixo; não precisas de **`rails dbconsole`** se preferires explorar esquema e dados no DBeaver.

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

**Linha-a-linha (Passo 12)**

- `**rails dbconsole`** — **O que faz:** abre cliente **psql** com as mesmas credenciais que `**config/database.yml`**. **Por que existe:** ver linhas brutas sem carregar modelo nem seeds; fecha o ciclo “migrate → modelo → HTTP → BD”. **Quando roda:** comando manual no terminal após signup bem-sucedido (em **DBeaver** corres o mesmo SQL ligado ao mesmo servidor/BD).

- `**SELECT id, email, timezone, display_name`** — **O que faz:** lê dados de perfil que também aparecem no JSON de `**user`**. **Por que existe:** confirmar valores persistidos igual ao esperado pelo Insomnia (ou pelo DBeaver a mostrar a grelha). **Quando roda:** no **psql** após `**rails dbconsole`** ou no editor SQL do DBeaver.
- `**password_digest IS NOT NULL AS tem_hash_senha**` — **O que faz:** testa linha por linha se existe hash bcrypt sem imprimir conteúdo sensível inteiro à consola neste exemplo. **Por que existe:** `has_secure_password` devia ter corrido antes de aparecer `**true`**; se for `**false**`, algo estranho gravou conta sem digest. **Quando roda:** na mesma query de confirmação.
- `**FROM users`** — **O que faz:** aponta para a tabela criada pela migration `**CreateUsers`** (refletida em `**schema.rb**`). **Por que existe:** liga comando SQL físico ao mapa `**User`** ⇄ `**users**`. **Quando roda:** sempre que corrês esta `**SELECT`**.
- `**ORDER BY id DESC**` — **O que faz:** mostra primeiro os registos com `**id`** mais alto — normalmente últimos testes. **Por que existe:** evitas percorrer tabela inteira só para encontrar conta que acabas de criar. **Quando roda:** no final da cláusula `**SELECT`**.
- `**LIMIT 5**` — **O que faz:** trunca resultado a cinco linhas máximo. **Por que existe:** em dev há muitos re-testes — não precisas listar todas. **Quando roda:** após `**ORDER BY`**.
- `**\q**` — **O que faz:** sai do cliente **psql** de volta ao shell. **Por que existe:** comando **meta** do psql — não faz parte SQL ISO. **Quando roda:** quando terminaste de inspecionar.

---

## Checklist final

- Passos 1–9 feitos sem erros de consola.
- Insomnia (ou Postman): signup → login → GET `/me` OK.
- **`rails c`** (opcional): experimentar `**User**` / tokens se quiseres fixar o fluxo em Ruby.
- BD: linha em `users` visível — **DBeaver** ou Passo 12 com `**rails dbconsole**`.
- Documentaste as rotas em `[../../api-rotas.md](../../api-rotas.md)` (copia o contrato + exemplos que usaste).

## Referências

- Visão técnica global: `[../../../../lords-mobile-tracker-api-planejamento.md](../../../../lords-mobile-tracker-api-planejamento.md)`.

