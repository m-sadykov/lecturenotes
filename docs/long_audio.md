# 📘 12. Обработка длинных аудио (Long Audio Processing)

⸻

## 12.1 Цель

Обеспечить стабильную обработку аудио записей длительностью до:

```
MVP: до 60 минут
V1+: до 3–4 часов
```

с учетом:

• ограничений STT API

• таймаутов Cloud Functions

• контроля стоимости

## 12.2 Ограничения системы

### 1️⃣ Ограничение STT API

```
максимальный размер файла ≈ 25 MB
```

Пример:

```
AAC 64 kbps → ~60 минут
```

### 2️⃣ Ограничения Cloud Functions

```
timeout (Gen2) до 60 минут
```

Но:

❗ нельзя обрабатывать длинные аудио в одном запросе

## 12.3 Стратегия MVP

В MVP используется ограничение длины записи, без chunking:

```
Free: до 10 минут
Pro: до 60 минут
```

Pipeline:

```
audio
↓
upload
↓
transcription (single request)
↓
LLM processing
```

## 12.4 Стратегия V1 (chunking)

Если аудио превышает лимит:

Используется chunking

```
audio
↓
split into chunks (10–15 min)
↓
transcribe each chunk
↓
merge transcripts
↓
LLM processing
```

## 12.5 Разбиение аудио

Размер chunk:

```
10–15 минут
```

Причины:
• быстрее обработка
• меньше вероятность ошибки
• легче retry

Формат хранения

```
audio/{uid}/{lectureId}/chunk_1.m4a
audio/{uid}/{lectureId}/chunk_2.m4a
```

## 12.6 Pipeline обработки

Шаг 1 — split audio

```
lecture.m4a
↓
chunk_1.m4a
chunk_2.m4a
chunk_3.m4a
```

Шаг 2 — транскрибация

```
chunk_1 → transcript_1
chunk_2 → transcript_2
chunk_3 → transcript_3
```

Шаг 3 — объединение

```
transcript_1
+ transcript_2
+ transcript_3
↓
full transcript
```

Шаг 4 — AI обработка

```
full transcript
↓
LLM
↓
summary
flashcards
quiz
```

## 12.7 Улучшенный pipeline (рекомендуется)

Для лучшего качества:

```
chunks
↓
chunk summaries
↓
final summary
```

Это уменьшает:

• шум

• повторения

• перегрузку модели

## 12.8 Архитектура Cloud Functions

Основной pipeline

```
processLectureAudio
↓
splitAudio
↓
transcribeChunks (parallel)
↓
mergeTranscript
↓
generateStudyPack
```

## 12.9 Cloud Tasks

Используется для:

```
retry
parallel processing
queue control
```

Каждый chunk:

```
отдельная задача
```

## 12.10 Обработка ошибок

Ошибка одного chunk

```
retry только этот chunk
```

Полная ошибка

```
status = failed
```

## 12.11 Контроль стоимости

Каждый chunk = отдельный STT запрос.

Поэтому:

```
стоимость растёт линейно
```

Ограничения

```
максимальная длительность
максимальное количество лекций
```

## 12.14 Альтернативные стратегии

1️⃣ Client-side split (рекомендуется)

Плюсы:

• дешевле

• быстрее

• нет нагрузки на backend

2️⃣ Backend split (через ffmpeg)

Плюсы:

• централизованный контроль

Минусы:

• сложнее

• дороже
