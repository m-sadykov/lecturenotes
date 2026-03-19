# Мини-ТЗ 02: Авторизация и пользовательский контекст

## Цель
Реализовать аутентификацию и единый доступ к `uid` пользователя для безопасной изоляции данных.

## Scope
- Интеграция Firebase Auth.
- Сценарий входа (минимум анонимный, опционально email).
- Хранение и восстановление сессии.
- Проброс `uid` в сервисный слой.
- Создание и поддержка документа `users/{uid}` как пользовательского контекста.
- Хранение в `users/{uid}`:
  - `plan`
  - `processingLimitTotalCount`
  - `processingLimitUsedCount`
  - `processingLimitRemainingCount`
  - `processingLimitIsUnlimited`
  - `recordingLimitSec`
  - `audioImportLimitSec`
  - `pdfPageLimit`

## Артефакты
- `FirebaseAuthService`.
- `FirebaseUserProfileService`.
- `AuthState` в `@Observable` модели.
- Базовый экран/flow входа.

## Критерии приемки
- После входа формируется валидный `uid`.
- Для каждого `uid` существует актуальный документ `users/{uid}`.
- Сессия сохраняется между перезапусками.
- Без `uid` нельзя запрашивать пользовательские лекции.

## Зависимости
- Мини-ТЗ 01.
