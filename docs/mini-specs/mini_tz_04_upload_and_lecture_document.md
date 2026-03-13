# Мини-ТЗ 04: Загрузка аудио и создание документа лекции

## Цель
После остановки записи загружать аудио в Storage и создавать/обновлять документ лекции в Firestore.

## Scope
- Генерация `lectureId`.
- Upload в путь: `audio/{uid}/{lectureId}.m4a`.
- Создание документа `users/{uid}/lectures/{lectureId}`.
- Первичный статусный pipeline: `draft -> uploading -> transcribing`.
- Сохранение `transcript` в документе лекции после получения частичной или финальной транскрибации.
- Обновление поля `Lecture.transcript` в документе лекции без промежуточной отдельной модели записи.

## Артефакты
- `StorageUploadService`.
- `LectureRepository` (методы create/update status).
- DTO/mapper для записи лекции в Firestore.

## Критерии приемки
- Для каждой записи создается связка: файл в Storage + документ в Firestore.
- `audioPath`, `createdAt`, `durationSec`, `status` сохраняются корректно.
- `transcript` сохраняется в документе лекции и не теряется между этапами `transcribing -> generating -> ready`.
- Ошибка upload переводит лекцию в `failed` с сообщением об ошибке.

## Зависимости
- Мини-ТЗ 02.
- Мини-ТЗ 03.
