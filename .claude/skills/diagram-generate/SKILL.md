---
name: diagram-generate
description: >
  СЦ-04 Генерация диаграмм в PlantUML: sequence, ERD, C4 (Context/Container/Component),
  activity (BPMN-подобные процессы), state machine. Используй при запросах «нарисуй»,
  «диаграмма», «sequence», «ERD», «C4», «схема процесса», «статусная модель»,
  «переделай в activity», а также когда другой скилл встраивает диаграмму.
---

# Генерация диаграмм (PlantUML)

**Вход:** текстовое описание потока / сценария / структуры.
**Выход:** `outputs/diagrams/<project_id>_<объект>_<тип>_v<N>.puml` + текстовое описание в
сообщении (и в документе, если диаграмма встраивается). Малый артефакт — сразу результат.

## Выбор типа (если не указан)

| Во входе | Тип |
|---|---|
| Кто кого вызывает, в каком порядке, запрос/ответ | **sequence** |
| Сущности, атрибуты, связи, таблицы | **ERD** |
| Какие системы/сервисы есть и как связаны (без порядка во времени) | **C4** (Context — системы и люди; Container — сервисы, БД, брокеры; Component — внутри сервиса) |
| Шаги процесса, ветвления, роли (дорожки), бизнес-поток | **activity** со swimlanes |
| Статусы объекта и переходы между ними | **state** |

Назови выбранный тип одной строкой. Если сомнение между двумя — выбери и предложи второй.

## Правила для всех

- Участники / сущности — латинские alias, подписи — на языке артефакта:
  `participant "Сервис заявок" as LoanSvc`
- Имена компонентов — **как в `project_context.md`**, без синонимов.
- Не больше ~15 участников / ~25 сущностей на одной диаграмме — иначе предложи разбить.
- `title` обязателен. Нумерация шагов в sequence — `autonumber`.
- Не рисуй то, чего нет во входе. Предполагаемый шаг → `note` с «⚠️ Допущение».
- Проверь синтаксис: парные `alt/end`, `group/end`, `if/endif`, закрытые `{}`, `@startuml/@enduml`.

## Шаблоны

### Sequence
```plantuml
@startuml
title <Сценарий>
autonumber
actor "Клиент" as User
participant "Мобильное приложение" as App
participant "API Gateway" as GW
participant "Сервис заявок" as LoanSvc
database "БД заявок" as LoanDB
queue "Kafka" as Kafka

User -> App: Оформить заявку
App -> GW: POST /v1/loan-applications\nIdempotency-Key
GW -> LoanSvc: POST /v1/loan-applications
activate LoanSvc
LoanSvc -> LoanDB: INSERT application (status=NEW)
LoanSvc -> Kafka: LoanApplicationCreated
alt валидация не пройдена
  LoanSvc --> GW: 400 VALIDATION_ERROR
else успех
  LoanSvc --> GW: 201 Created
end
deactivate LoanSvc
GW --> App: ответ
@enduml
```
Используй `alt/else`, `opt`, `loop`, `par`, `group "Retry x3"`, `...таймаут 30 с...`,
`note right`. Асинхронное сообщение — `->>`. Ответ — `-->`.

### ERD
```plantuml
@startuml
title <Модель данных>
hide circle
skinparam linetype ortho

entity "loan_application" as LA {
  * id : uuid <<PK>>
  --
  * client_id : uuid <<FK>>
  * amount : numeric(15,2)
  * status : varchar(32)
  * created_at : timestamptz
    comment : text
}
entity "client" as C {
  * id : uuid <<PK>>
}
C ||--o{ LA : подаёт
@enduml
```
`*` — NOT NULL. Кардинальности: `||--||`, `||--o{`, `}o--o{`.

### C4 (Container)
```plantuml
@startuml
!include <C4/C4_Container>
title <Система> — Container
Person(client, "Клиент")
System_Boundary(sys, "<Система>") {
  Container(api, "API Gateway", "Kong")
  Container(loan, "Сервис заявок", "Java/Spring", "Приём и обработка заявок")
  ContainerDb(db, "БД заявок", "PostgreSQL")
  ContainerQueue(kafka, "Kafka", "Apache Kafka")
}
System_Ext(bki, "БКИ", "Кредитная история")
Rel(client, api, "Использует", "HTTPS")
Rel(api, loan, "Проксирует", "REST")
Rel(loan, db, "Читает/пишет", "JDBC")
Rel(loan, kafka, "Публикует события")
Rel(loan, bki, "Запрашивает отчёт", "REST/mTLS")
SHOW_LEGEND()
@enduml
```
Context: `!include <C4/C4_Context>`, `Person`, `System`, `System_Ext`.
Component: `!include <C4/C4_Component>`, `Component(...)` внутри `Container_Boundary`.

### Activity (процесс со swimlanes)
```plantuml
@startuml
title <Процесс>
|Клиент|
start
:Подать заявку;
|Сервис заявок|
:Проверить заявку;
if (Данные валидны?) then (да)
  :Запросить скоринг;
else (нет)
  |Клиент|
  :Получить отказ;
  stop
endif
|Сервис заявок|
fork
  :Отправить в БКИ;
fork again
  :Проверить антифрод;
end fork
:Принять решение;
stop
@enduml
```

### State
```plantuml
@startuml
title Статусы заявки
[*] --> NEW
NEW --> SCORING : submit
SCORING --> APPROVED : score >= порог
SCORING --> REJECTED : score < порог
SCORING --> MANUAL_REVIEW : пограничный балл
MANUAL_REVIEW --> APPROVED : одобрено андеррайтером
MANUAL_REVIEW --> REJECTED
NEW --> CANCELLED : cancel [клиент]
APPROVED --> [*]
REJECTED --> [*]
CANCELLED --> [*]
@enduml
```
Переходы подписывать `событие [условие] / действие`. Вместе с state-диаграммой
всегда выдавай таблицу переходов (из статуса | событие | в статус | условие | побочные эффекты)
и отмечай недостижимые / тупиковые статусы, если есть.

## Текстовое описание (в сообщении)

- Что изображено (1–2 предложения)
- Ключевые решения/особенности, видные на диаграмме (асинхронность, точки отказа, retry)
- Допущения
- Как посмотреть: плагин PlantUML в IDE (локальный рендер) или макрос PlantUML в Confluence

Не предлагай публичный сервер plantuml.com и онлайн-редакторы: код диаграммы уходит на
чужой сервер, а в нём — архитектура и данные работодателя. Если аналитик сам просит
ссылку на онлайн-рендер — напомни об этом одной строкой.

## Конвертация между типами

«Переделай sequence в activity» и т.п. — сохрани смысл, покажи, что потерялось
при конвертации (например, activity не показывает, кто кого вызывает синхронно).
Результат — новый файл с другим типом в имени.
