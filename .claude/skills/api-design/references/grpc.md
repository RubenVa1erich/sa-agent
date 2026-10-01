# gRPC / proto3

## Скелет

```proto
syntax = "proto3";

package company.scoring.v1;   // [TODO: префикс пакета из project_context]

import "google/protobuf/timestamp.proto";

option java_multiple_files = true;   // опции генерации — по стеку проекта

// Сервис скоринга заявок. Спецификация: <ссылка>. ФТ-020..ФТ-024.
service ScoringService {
  // Рассчитать скоринговый балл. Идемпотентен по application_id.
  // Deadline: 2 s. Ошибки: INVALID_ARGUMENT, NOT_FOUND, UNAVAILABLE.
  rpc CalculateScore(CalculateScoreRequest) returns (CalculateScoreResponse);
}

message CalculateScoreRequest {
  string application_id = 1;   // UUID, обязательно
}

message CalculateScoreResponse {
  int32 score = 1;                                   // 0..1000
  Decision decision = 2;
  google.protobuf.Timestamp calculated_at = 3;
}

enum Decision {
  DECISION_UNSPECIFIED = 0;   // обязательный нулевой элемент
  DECISION_APPROVE = 1;
  DECISION_REJECT = 2;
  DECISION_MANUAL_REVIEW = 3;
}
```

## Правила

- Для каждого поля в комментарии: обязательность (в proto3 всё опционально на уровне
  протокола — обязательность описывается семантически), формат, диапазон.
- `optional` — если нужно отличать «не передано» от значения по умолчанию.
- Enum — префикс имени типа, нулевое значение `_UNSPECIFIED`.
- Деньги — `google.type.Money` или `{ int64 units; int32 nanos; string currency_code }`.
- Ошибки: стандартные коды (`INVALID_ARGUMENT`, `NOT_FOUND`, `ALREADY_EXISTS`,
  `FAILED_PRECONDITION`, `PERMISSION_DENIED`, `UNAUTHENTICATED`, `UNAVAILABLE`,
  `DEADLINE_EXCEEDED`, `INTERNAL`) + `google.rpc.ErrorInfo` (reason, domain, metadata).
  В описании — таблица: код | reason | когда.
- Deadline и retry-политику указывать в комментарии к RPC и в описании.
- Стриминг (server/client/bidi) — только если есть явная потребность; описать
  завершение потока и поведение при обрыве.

## Совместимость

- Никогда не менять номер поля и не переиспользовать удалённые номера → `reserved`.
- Совместимо: новое поле, новый RPC, новое значение enum (клиенты должны обрабатывать неизвестные).
- Ломающее: смена типа поля, переименование пакета/сервиса/RPC, удаление без `reserved`,
  изменение семантики. → пакет `v2`.
