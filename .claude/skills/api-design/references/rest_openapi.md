# REST / OpenAPI 3.1 — паттерны

Соглашения по умолчанию — `.claude/rules/conventions.md`. Проектные — приоритетнее.

## Ресурсы и методы

| Операция | Метод | Путь | Успех |
|---|---|---|---|
| Список | GET | `/v1/loan-applications` | 200 |
| Получить | GET | `/v1/loan-applications/{applicationId}` | 200 |
| Создать | POST | `/v1/loan-applications` | 201 + `Location` |
| Заменить | PUT | `/v1/loan-applications/{applicationId}` | 200 |
| Частично изменить | PATCH | `/v1/loan-applications/{applicationId}` | 200 (JSON Merge Patch) |
| Удалить | DELETE | `/v1/loan-applications/{applicationId}` | 204 |
| Действие / переход состояния | POST | `/v1/loan-applications/{applicationId}/cancel` | 200 / 202 |
| Длительная операция | POST → 202 + `Location` на статус операции | | 202 |

- Действия, не укладывающиеся в CRUD (cancel, approve, submit) — подресурс-глагол через POST.
  Это допустимое отступление от «чистого» REST; не изобретай искусственные ресурсы.
- Вложенность — не глубже 2 уровней.
- Фильтры — query-параметры: `?status=ACTIVE&createdFrom=...`.

## Идемпотентность

- GET, PUT, DELETE — идемпотентны по определению.
- POST создания / финоперации — `Idempotency-Key` (UUID, обязательный заголовок).
  Описать: срок хранения ключа, ответ на повтор (тот же код и тело), ответ на тот же ключ
  с другим телом (422 `IDEMPOTENCY_KEY_REUSED`).

## Конкурентность

- Для изменений сущностей с конкурентным доступом — оптимистическая блокировка:
  `ETag` в ответе, `If-Match` в запросе, 412 при несовпадении.

## Пагинация

```yaml
parameters:
  - name: limit
    in: query
    schema: { type: integer, minimum: 1, maximum: 100, default: 20 }
  - name: cursor
    in: query
    schema: { type: string }
# ответ
PageOfX:
  type: object
  required: [items]
  properties:
    items: { type: array, items: { $ref: '#/components/schemas/X' } }
    nextCursor: { type: [string, "null"], description: "null — последняя страница" }
```

## Скелет спецификации

```yaml
openapi: 3.1.0
info:
  title: <Service> API
  version: 1.0.0
  description: |
    <Назначение. Ссылка на спеку.>
servers:
  - url: https://api.example.com   # [TODO: уточнить]
tags:
  - name: <Resource>
paths:
  /v1/<resources>:
    post:
      tags: [<Resource>]
      operationId: create<Resource>
      summary: <Кратко>
      description: |
        <Логика, ссылки на ФТ: ФТ-012>
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
        - $ref: '#/components/parameters/RequestId'
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/Create<Resource>Request' }
      responses:
        '201':
          description: Создано
          headers:
            Location: { schema: { type: string } }
          content:
            application/json:
              schema: { $ref: '#/components/schemas/<Resource>' }
        '400': { $ref: '#/components/responses/ValidationError' }
        '401': { $ref: '#/components/responses/Unauthorized' }
        '403': { $ref: '#/components/responses/Forbidden' }
        '409': { $ref: '#/components/responses/Conflict' }
        '422': { $ref: '#/components/responses/BusinessRuleViolation' }
        '500': { $ref: '#/components/responses/InternalError' }
components:
  securitySchemes:
    bearerAuth: { type: http, scheme: bearer, bearerFormat: JWT }
  parameters:
    IdempotencyKey:
      name: Idempotency-Key
      in: header
      required: true
      schema: { type: string, format: uuid }
    RequestId:
      name: X-Request-Id
      in: header
      required: false
      schema: { type: string }
  schemas:
    Money:
      type: object
      required: [amount, currency]
      properties:
        amount: { type: string, pattern: '^-?\d+(\.\d{1,2})?$', example: "15000.00" }
        currency: { type: string, pattern: '^[A-Z]{3}$', example: RUB }
    Problem:
      type: object
      required: [type, title, status]
      properties:
        type: { type: string, format: uri }
        title: { type: string }
        status: { type: integer }
        detail: { type: string }
        instance: { type: string }
        code: { type: string, description: Машиночитаемый код ошибки }
        errors:
          type: array
          items:
            type: object
            required: [field, message]
            properties:
              field: { type: string, example: amount.value }
              code: { type: string, example: MUST_BE_POSITIVE }
              message: { type: string }
  responses:
    ValidationError:
      description: Невалидный запрос
      content:
        application/problem+json:
          schema: { $ref: '#/components/schemas/Problem' }
    # Unauthorized, Forbidden, NotFound, Conflict, BusinessRuleViolation, InternalError — аналогично
security:
  - bearerAuth: []
```

## Ломающие изменения (REST)

**Ломающие:** удаление/переименование поля, эндпоинта, enum-значения в ответе (для строгих
клиентов); смена типа/формата; новое обязательное поле в запросе; ужесточение валидации;
смена кода ответа; смена семантики поля.

**Совместимые:** новое опциональное поле в запросе; новое поле в ответе; новый эндпоинт;
ослабление валидации; новое значение enum во входе.

**Внимание:** новое значение enum в *ответе* — потенциально ломающее, если клиенты не
обрабатывают неизвестные значения. Указывать явно.
