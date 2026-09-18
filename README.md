# 📧 collectionTestApiEmailService

Collection do Postman para testes de integração (end-to-end) do **EmailService** do projeto *Catálogo de Eventos*. A collection cobre os fluxos de **envio de código de recuperação de senha** e **validação do código**, incluindo cenários de sucesso, erros de validação e testes smoke (funcional e de segurança).

Além da collection, este repositório também hospeda os **mappings do WireMock que simulam o EmailService** (pasta `wiremock/`), reaproveitados pela collection de testes do [`userService`](https://github.com/LucasMCFidelis/collectionTestApiUserService) para testar o fluxo de atualização de senha sem depender do EmailService real — no mesmo padrão em que o `collectionTestApiUserService` fornece os mocks do UserService para o `auth-service` e para este próprio repositório.

---

## 📁 Estrutura

```
collectionTestApiEmailService/
├── postman/
│   ├── collections/
│   │   └── email-service.postman_collection.json
│   └── environments/
│       ├── ci.environment.json
│       ├── local-mock.environment.json
│       ├── local-real.environment.json
│       └── production-like.environment.json
└── wiremock/
    └── mappings/
        ├── 00-fallback.json
        ├── 01-validate-recovery-code.json
        ├── 02-send-recovery-code.json
        └── 03-fail-validate-recovery-code.json
```

---

## ▶️ Como executar

### Opção 1 — Postman (interface gráfica)
1. Importe a collection em `postman/collections/email-service.postman_collection.json`.
2. Importe o(s) environment(s) desejado(s) em `postman/environments/`.
3. Selecione o environment no canto superior direito do Postman.
4. Preencha as variáveis obrigatórias (ver seção [Variáveis](#️-variáveis-necessárias-para-executar-a-collection) abaixo).
5. Execute a collection inteira via **Runner**, ou cada request individualmente.

### Opção 2 — Newman (linha de comando / CI)
```bash
npm install -g newman

newman run postman/collections/email-service.postman_collection.json \
  -e postman/environments/local-mock.environment.json
```
Basta trocar o arquivo de environment (`-e`) para rodar contra outro ambiente (`local-real`, `ci` ou `production-like`).

---

## ⚙️ Variáveis necessárias para executar a Collection

Para que esta collection funcione corretamente no Postman, configure as seguintes variáveis no **Environment**:

---

### 🌐 URLs dos serviços obrigatórios

| Variável            | Descrição                                              |
|---------------------|-----------------------------------------------------------|
| `email_service_url` | URL base do EmailService (ex.: `http://localhost:3000/emails`) |
| `user_service_url`  | URL base do UserService, usado para criar/remover o usuário de teste (ex.: `http://localhost:8089/users`) |

---

### 🎭 Modo de execução (mock x real)

| Variável  | Descrição                                                                 |
|-----------|-----------------------------------------------------------------------------|
| `useMock` | `"true"` para rodar contra um serviço mockado (sem criar/remover usuários reais nem depender do UserService); `"false"` para rodar a integração real ponta a ponta. |

Quando `useMock` é `"true"`:
- A criação do usuário de teste é simulada (não chama o `user_service_url`) — um e-mail é sorteado a partir de uma lista fixa (`emailsToTest`) definida no pre-request script da collection.
- O envio do código de recuperação envia o header `x-mock-scenario` (ex.: `SUCCESS_GET_USER`), permitindo que o mock retorne a resposta correspondente ao cenário testado.
- A exclusão do usuário de teste ao final dos testes é ignorada.

---

### 🔒 Variável do teste de segurança

| Variável            | Descrição                                                                 |
|---------------------|-------------------------------------------------------------------------------|
| `emailSecurityTest` | E-mail usado apenas pelo teste **"Não expõe recovery code em PRODUCTION"** (pasta `smoke/security-smoke`). Não vem definida em nenhum environment — precisa ser configurada manualmente antes de rodar esse teste. |

---

### 🧪 Variáveis de fluxo (preenchidas automaticamente)

Essas variáveis são criadas e atualizadas automaticamente pelos scripts da collection (pre-request/test scripts), a partir das funções auxiliares `createSimpleUserRequest`, `deleteSimpleUserRequest` e `sendRecoveryCodeRequest` — registradas como variáveis de collection e reutilizadas entre requests. Não é necessário preenchê-las manualmente.

| Variável                  | Preenchida automaticamente | Descrição                                              |
|----------------------------|-----------------------------|------------------------------------------------------------|
| `emailToRecoveryCode`      | ✔️                          | E-mail usado no fluxo de envio/validação do código          |
| `userIdToRecoveryCode`     | ✔️                          | ID do usuário criado para o teste (modo real)                |
| `userTokenToRecoveryCode`  | ✔️                          | Token do usuário criado, usado para removê-lo ao final        |
| `recoveryCode`             | ✔️                          | Código de recuperação retornado pelo serviço (quando exposto) |
| `emailsToTest`             | ✔️                          | Lista fixa de e-mails usada para sortear o usuário em modo mock |
| `api_env`                  | ✔️                          | Ambiente detectado a partir do header `email-service-environment` da resposta |

> ℹ️ O usuário de teste é criado antes dos testes que dependem dele e removido (via `deleteSimpleUserRequest`) logo após o teste concluir, evitando resíduos de dados entre execuções. Em modo mock, criação e remoção são puladas.

---

## ✔️ Resumo rápido

### 🔧 Configure manualmente:
- `email_service_url`
- `user_service_url`
- `useMock`
- `emailSecurityTest` *(apenas para o teste de segurança)*

### 🤖 Variáveis gerenciadas automaticamente pelos scripts:
- `emailToRecoveryCode`
- `userIdToRecoveryCode`
- `userTokenToRecoveryCode`
- `recoveryCode`
- `emailsToTest`
- `api_env`

---

## 🧪 Testes da collection

A collection está organizada em duas pastas principais: **recovery** (fluxo completo) e **smoke** (sanidade e segurança). Todos os requests validam o status HTTP retornado e a presença/conteúdo da propriedade `message` no corpo da resposta.

### 📂 recovery / Envio de Recovery Code (`POST {{email_service_url}}/send-recovery-code`)

| Cenário | O que valida | Retorno esperado |
|---|---|---|
| **Enviar recovery code** | Cria um usuário de teste (via `createSimpleUserRequest`) e envia o código de recuperação para o e-mail sorteado. Confirma a mensagem de sucesso ("código de recuperação enviado"). Ao final, remove o usuário criado. | `200 OK` |
| **Enviar recovery code para email invalido** | Envia um e-mail em formato inválido. Confirma a mensagem "Email deve ser um email válido". | `400 Bad Request` |
| **Enviar recovery code para email não cadastrado** | Utiliza um e-mail que não existe na base. Confirma a mensagem "Usuário não encontrado". | `404 Not Found` |
| **Enviar recovery code sem passar o email** | Envia o corpo da requisição vazio, sem o campo `email`. Confirma a mensagem "Email é obrigatório". | `400 Bad Request` |

### 📂 recovery / Validação de Recovery Code (`POST {{email_service_url}}/validate-recovery-code`)

| Cenário | O que valida | Retorno esperado |
|---|---|---|
| **Validar Recovery Code com código valido** | Cria um usuário de teste, envia um código de recuperação real (`sendRecoveryCodeRequest`) e valida esse código. Fora do ambiente de produção, confirma a mensagem "Código de recuperação válido". Em produção, o teste é pulado (o código não pode ser obtido para validar). Remove o usuário ao final. | `200 OK` |
| **Validar Recovery Code com código invalido** | Usa um código aleatório para um e-mail existente. Confirma a mensagem "código de recuperação inválido". | `400 Bad Request` |
| **Validar Recovery Code com email invalido** | Envia um e-mail em formato inválido. Confirma a mensagem "Email deve ser um email válido". | `400 Bad Request` |
| **Validar Recovery Code com email não cadastrado** | Usa um e-mail que não existe na base. Confirma a mensagem "Código de recuperação inválido". | `400 Bad Request` |
| **Validar Recovery Code sem passar email** | Omite o campo `userEmail`. Confirma a mensagem "Email é obrigatório". | `400 Bad Request` |
| **Validar Recovery Code sem passar código** | Omite o campo `recoveryCode`. Confirma a mensagem "recovery code é obrigatório". | `400 Bad Request` |

### 📂 smoke / functional-smoke

| Cenário | O que valida | Retorno esperado |
|---|---|---|
| **Enviar recovery code (sanity)** | Teste de sanidade simples: envia um código de recuperação para um e-mail fixo e confirma que a mensagem indica o envio (via regex, tolerando variações de acentuação). Serve como verificação rápida de que o serviço está no ar e respondendo corretamente. | `200 OK` |

### 📂 smoke / security-smoke

| Cenário | O que valida | Retorno esperado |
|---|---|---|
| **Não expõe recovery code em PRODUCTION** | Envia um código de recuperação usando o e-mail configurado em `emailSecurityTest` e confirma que a resposta **não** contém a propriedade `recoveryCode` no corpo — evitando que o código de recuperação vaze na resposta da API em produção. | `200 OK` (sem `recoveryCode` no corpo) |

---

## 🛠️ Funções auxiliares (scripts de collection)

Essas funções são definidas no **pre-request script da collection** e ficam disponíveis para todos os requests via variáveis de collection (padrão usado para compartilhar funções entre requests no Postman):

- **`createSimpleUserRequest(attempt)`** — cria um usuário comum no `user_service_url` com nome aleatório (`{{$randomWord}}`) e um e-mail sorteado da lista `emailsToTest`, com até 5 tentativas em caso de falha. Em modo mock, apenas define `emailToRecoveryCode` sem chamar o UserService. Ao ter sucesso, preenche `userIdToRecoveryCode`, `userTokenToRecoveryCode` e `emailToRecoveryCode`.
- **`deleteSimpleUserRequest(token, userId)`** — remove o usuário de teste criado, usando o token e o ID informados, e limpa as variáveis de collection correspondentes. Em modo mock, não faz nenhuma chamada.
- **`sendRecoveryCodeRequest(email, scenario)`** — dispara uma requisição de envio de código de recuperação para o e-mail informado. Em modo mock, envia o header `x-mock-scenario` para direcionar a resposta simulada. Guarda o e-mail usado em `emailToRecoveryCode` e, se a resposta expuser o código (`recoveryCode`), guarda também em `recoveryCode` — usado depois no teste de validação com código válido.

Além disso, o **test script da collection** roda após cada request e detecta o ambiente atual a partir do header `email-service-environment` da resposta, armazenando o resultado em `api_env` (usado para pular o teste de validação de código válido quando `api_env === "production"`).

---

## 🧩 Mocks do EmailService (WireMock)

Assim como o `collectionTestApiUserService` mantém mappings que simulam o UserService, este repositório mantém os mappings que simulam o **EmailService**, consumidos pela collection do [`userService`](https://github.com/LucasMCFidelis/collectionTestApiUserService) — especificamente pelo fluxo de **atualização de senha**, que depende de um código de recuperação gerado pelo EmailService antes de poder trocar a senha do usuário.

| Arquivo | Endpoint simulado | `X-Mock-Scenario` | Resposta |
|---|---|---|---|
| `01-validate-recovery-code.json` | `POST /emails/validate-recovery-code` | `SUCCESS_VALIDATE_RECOVERY_CODE` | `200` — "Código de recuperação válido" |
| `02-send-recovery-code.json` | `POST /emails/send-recovery-code` | `SUCCESS_SEND_RECOVERY_CODE` | `200` — retorna `message` de sucesso e um `recoveryCode` fixo (`aaww11`) |
| `03-fail-validate-recovery-code.json` | `POST /emails/validate-recovery-code` | `FAIL_VALIDATE_RECOVERY_CODE` | `400` — "Código de recuperação expirado" |

### Subindo o mock isoladamente

```bash
docker run -d --name wiremock-email-service -p 8090:8080 \
  -v "$(pwd)/wiremock:/home/wiremock" \
  wiremock/wiremock
```

Isso expõe o mock em `http://localhost:8090` (porta escolhida livremente — só não pode colidir com a porta `8089` já usada pelo mock do UserService quando os dois rodam juntos). Depois, basta apontar a variável de URL do EmailService do serviço/collection sendo testado para esse endereço e enviar o header `X-Mock-Scenario` desejado.

---

| Ambiente | Arquivo | `useMock` | Uso recomendado |
|---|---|---|---|
| Local Mock | `local-mock.environment.json` | `true` | Rodar os testes localmente sem depender do UserService real |
| Local Real Integration | `local-real.environment.json` | `false` | Rodar os testes localmente contra os serviços reais em execução na máquina |
| CI Environment | `ci.environment.json` | `true` | Execução automatizada em pipelines de integração contínua |
| Production Like | `production-like.environment.json` | `true` | Testes smoke/segurança contra um ambiente equivalente à produção, sem expor dados reais |