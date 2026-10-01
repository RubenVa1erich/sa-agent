# События: Kafka / RabbitMQ / AsyncAPI 3.0

## Что описать для каждого события

| Аспект | Вопрос |
|---|---|
| Смысл | Какой факт произошёл (прошедшее время). Событие ≠ команда. |
| Продюсер | Какой сервис — владелец факта |
| Консьюмеры | Кто подписан и зачем (известные на момент проектирования) |
| Канал | Kafka: топик, партиции, ключ. RabbitMQ: exchange, тип, routing key, очередь |
| Payload | Полное состояние (event-carried state transfer) или только ID + изменения (notification)? |
| Порядок | Нужен ли порядок; по какому ключу |
| Доставка | at-least-once (по умолчанию) → идемпотентность консьюмера |
| Ошибки | retry (сколько, backoff) → DLQ/DLT; кто разбирает DLQ |
| Retention | Kafka: сколько хранится; нужен ли compaction |
| Версионирование | как эволюционирует схема; реестр схем (Schema Registry?) |
| Outbox | как гарантируется атомарность «изменил БД + опубликовал событие» |

Если какой-то аспект неизвестен — `[TODO]`, не выдумывать (особенно партиции, retention).

## Kafka vs RabbitMQ — на что обращать внимание

| | Kafka | RabbitMQ |
|---|---|---|
| Модель | лог, консьюмер-группы читают независимо | очереди, сообщение забирается консьюмером |
| Порядок | в пределах партиции (по ключу) | в пределах очереди при одном консьюмере |
| Повторное чтение | да (offset) | нет (после ack) |
| Retry | отдельные retry-топики / DLT | DLX + TTL-очереди |
| Типично для | доменные события, CDC, стриминг | команды, задачи, RPC-over-MQ |

## Скелет AsyncAPI 3.0

```yaml
asyncapi: 3.0.0
info:
  title: <Domain> Events
  version: 1.0.0
  description: |
    <Назначение. Ссылки на ФТ.>
servers:
  kafka:
    host: '[TODO: уточнить]'
    protocol: kafka
channels:
  loanApplicationApproved:
    address: loans.application.approved.v1
    description: Заявка одобрена
    messages:
      LoanApplicationApproved:
        $ref: '#/components/messages/LoanApplicationApproved'
    bindings:
      kafka:
        partitions: '[TODO]'
operations:
  publishLoanApplicationApproved:
    action: send
    channel: { $ref: '#/channels/loanApplicationApproved' }
    summary: loan-service публикует после перевода заявки в APPROVED
components:
  messages:
    LoanApplicationApproved:
      name: LoanApplicationApproved
      contentType: application/json
      headers:
        type: object
        properties:
          correlationId: { type: string }
      bindings:
        kafka:
          key: { type: string, description: applicationId — порядок событий по заявке }
      payload:
        $ref: '#/components/schemas/LoanApplicationApprovedEnvelope'
  schemas:
    LoanApplicationApprovedEnvelope:
      type: object
      required: [id, type, source, time, data]
      properties:
        id: { type: string, format: uuid, description: ID события — ключ дедупликации }
        type: { type: string, const: loans.application.approved }
        source: { type: string, example: loan-service }
        time: { type: string, format: date-time }
        specVersion: { type: string, const: '1.0' }
        data:
          type: object
          required: [applicationId]
          properties:
            applicationId: { type: string, format: uuid }
```

Для RabbitMQ — `protocol: amqp`, в `bindings.amqp` канала: `is: routingKey`,
`exchange: { name, type: topic, durable: true }`; у операции — очередь консьюмера.

## Совместимость схем событий

- Совместимо: добавление опционального поля; добавление нового типа события.
- Ломающее: удаление/переименование поля, смена типа, новое обязательное поле,
  смена семантики, смена ключа партиционирования (ломает порядок!).
- Ломающее изменение → новый топик `.v2` + период двойной публикации. Предложить, не решать.
