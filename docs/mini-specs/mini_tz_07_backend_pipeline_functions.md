# Мини-ТЗ 07: Backend pipeline на Cloud Functions

## Цель
Реализовать серверный pipeline обработки аудио от загрузки до готовых учебных материалов.

## Scope
- Trigger на upload аудио.
- Функция `transcribeLecture`.
- Функция `generateStudyPack`.
- Оркестрация через Cloud Tasks.
- Обновление статусов: `transcribing -> generating -> ready/failed`.

## Артефакты
- Cloud Functions (TypeScript/Node).
- Очереди задач и retry политика.
- Логирование и error handling для pipeline.

## Критерии приемки
- Pipeline автоматически запускается после загрузки аудио.
- При успешной обработке в Firestore появляются transcript и AI-поля.
- Ошибки фиксируются, статус переводится в `failed`.

## Зависимости
- Мини-ТЗ 04.
