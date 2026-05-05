# Documentação das rotas da API (`/api/v1`)

Contrato único que evoluímos à medida que as rotas forem implementadas. Base comum dos exemplos:

- **`Content-Type`:** `application/json` onde houver body.
- **Auth (MVP planeada):** `Authorization: Bearer <jwt>` quando indicado como “JWT”.

Repetir uma secção **por recurso ou rota**. Remove os comentários entre `<…>` quando preenchidas.

---

## Template por rota / grupo

### `<NomeHumanReadable>`

| Campo | Valor |
|--------|--------|
| Método / path | `<GET|POST|PATCH|DELETE>` `<ex.: /api/v1/login>` |
| Autenticação | `<none | JWT>` |
| Query params | `<lista ou —>` |
| Body (JSON) | `<campos obrigatórios/opcionais ou —>` |
| Resposta 2xx | `<shape resumido e códigos; ex.: 200 objeto user + token>` |
| Erros típicos | `<ex.: 401 token inválido; 422 erros validação>` |

**Exemplo request**

```http
<MÉTODO> <CAMINHO> HTTP/1.1
Authorization: Bearer <jwt>
Content-Type: application/json

{}
```

**Exemplo response**

```json
{}
```

---

## Rotas já documentadas aqui

*Nenhuma ainda — adicionar secções conforme cada rota ficar disponível.*
