### 📘 Техническое задание

## Lecture Notes AI: Flashcards & Quiz

Версия: 1.0
Платформа: iOS
Минимальная версия iOS: 17.0
Технологии: SwiftUI + Firebase + AI API

## 1. Описание продукта

Lecture Notes AI — приложение для студентов, которое позволяет: 1. записывать лекции 2. автоматически получать конспект 3. генерировать флэшкарты 4. проходить мини-квиз

Основной сценарий:

```
Record lecture
↓
AI transcription
↓
Summary
↓
Flashcards
↓
Quiz
```

Цель продукта — ускорить подготовку к экзаменам и обучение.

## 2. Основные функции MVP

2.1 Запись лекции

Функционал:
• запись аудио
• пауза / продолжение
• остановка записи
• отображение времени записи

Формат:

```
AAC / m4a
44.1 kHz
mono
32–64 kbps
```

После остановки:

```
lecture draft → upload → processing
```

### 2.2 Обработка лекции

Pipeline:

```
Upload audio
↓
Speech-to-text
↓
AI summary
↓
Concept extraction
↓
Flashcards generation
↓
Quiz generation
```

Статусы:

```
draft
uploading
transcribing
generating
ready
failed
```

### 2.3 Результат лекции

Каждая лекция содержит:

**Summary**

• короткий конспект

• подробный конспект

⸻

**Outline**

Структура лекции:

```
Topic 1
Topic 2
Topic 3
```

**Glossary**

Термины:

```
term → definition
```

пример:

```
Photosynthesis → process where plants convert sunlight into energy
```

**Flashcards**

Формат:

```
Question
Answer
```

пример:

```
Q: What is photosynthesis?
A: Process where plants convert sunlight into chemical energy
```

Количество:

```
10–20 карточек
```

**Quiz**

Формат:

```
Multiple choice
4 варианта
```

пример:

```
Which pigment absorbs sunlight in plants?

A Chlorophyll
B Hemoglobin
C Keratin
D Melanin
```

## 3. Экраны приложения

MVP требует 8 экранов.

### 3.1 Onboarding

Функции:

• описание приложения

• разрешение микрофона

• выбор языка вывода

### 3.2 Lecture List (Home)

Список лекций.

Элемент:

```
Title
Course
Date
Duration
Status
```

Функции:

• поиск

• фильтр по курсу

• кнопка Record

### 3.3 Recorder

Функции:

```
Record
Pause
Resume
Stop
```

UI элементы:

```
таймер
лимит записи
название курса
```

### 3.4 Processing

Статус обработки.

UI:

```
Uploading
Transcribing
Generating notes
```

Пользователь может закрыть экран.

### 3.5 Lecture Detail

Основной экран.

Tabs:

```
Summary
Outline
Glossary
Flashcards
Quiz
Transcript
```

### 3.6 Flashcards Practice

Режим изучения.

UI:

```
Card
Flip
Know / Don't know
Progress
```

### 3.7 Quiz

Функции:

```
multiple choice questions
score calculation
result screen
```

### 3.8 Paywall

Подписка:

```
Free
Pro
```

### 3.9 Settings

Настройки:

```
language
delete audio after processing
restore purchases
support
```

## 4. Архитектура iOS приложения

Используется архитектура:

```
MVVM
+ Service layer
+ Manager layer
```

Цель:

```
View максимально простые
логика в ViewModel
сервисы отвечают за инфраструктуру
```

### 4.1 Архитектурные слои

View

SwiftUI views.

Ответственность:

```
UI
bindings
user actions
```

View не должна:

```
работать с Firebase
вызывать API
содержать бизнес-логику
```

**ViewModel**

Отвечает за:

```
UI state
business logic
calls to services
```

пример:

```
RecorderViewModel
LectureDetailViewModel
LecturesListViewModel
```

**Services / Managers**

Отвечают за инфраструктуру.

Примеры:

```
RecordingManager
LectureRepository
FirebaseAuthService
StorageUploadService
SubscriptionManager
```

### 4.2 Структура проекта

```
App
 AppEnvironment
 DIContainer

Common
 Models
 Extensions
 Resources

Services
 RecordingManager
 FirebaseAuthService
 LectureRepository
 StorageUploadService
 SubscriptionManager

Modules

 Onboarding
 LecturesList
 Recorder
 Processing
 LectureDetail
 FlashcardsPractice
 Quiz
 Paywall
 Settings

UIComponents
 Reusable SwiftUI components
```

### 4.3 Правило структуры (обязательно)

Для всех новых задач, экранов и рефакторинга используется только структура:

```
App
Common
Services
Modules
UIComponents
```

Новые feature-экраны должны добавляться в `Modules/<FeatureName>`, а общие модели и утилиты — в `Common`.

## 5. Firebase архитектура

Используется:

```
Firebase Auth
Firestore
Firebase Storage
Cloud Functions
Cloud Tasks
```

### 5.1 Firebase Storage

Аудио хранится:

```
audio/{uid}/{lectureId}.m4a
```

### 5.2 Firestore

Коллекции:

```
users/{uid}

users/{uid}/lectures/{lectureId}
```

### 5.3 Lecture document

```
status
title
course
createdAt
durationSec

audioPath

languageDetected
outputLanguage

transcript

summaryShort
summaryLong

outline[]

glossary[]

flashcards[]

quiz[]
```

## 6. Cloud Functions

Pipeline обработки.

### 6.1 Upload trigger

Trigger:

```
on audio upload
```

Функция:

```
set status = transcribing
enqueue transcription task
```

### 6.2 Transcription

Функция:

```
transcribeLecture
```

Шаги:

```
speech-to-text
save transcript
status = generating
```

### 6.3 AI generation

Функция:

```
generateStudyPack
```

Генерирует:

```
summary
outline
glossary
flashcards
quiz
```

После:

```
status = ready
```

## 7. AI Output Schema

LLM должен возвращать JSON.

```
{
 "title": "string",
 "summaryShort": "string",
 "summaryLong": "string",
 "outline": ["string"],
 "glossary": [
   { "term": "string", "definition": "string" }
 ],
 "flashcards": [
   { "q": "string", "a": "string" }
 ],
 "quiz": [
   {
     "q": "string",
     "options": ["A","B","C","D"],
     "correctIndex": 0
   }
 ]
}
```

## 8. Подписка

**Free**

```
3 лекции в месяц
10 минут максимум
summary + outline
```

**Pro**

```
$4.99 / month

50 лекций
60 минут максимум

flashcards
quiz
glossary
```

## 9. Безопасность

Правила:

```
Firestore access только владельцу uid
Storage доступ только владельцу
AI API ключи только на backend
```

## 10. Критерии MVP

MVP считается готовым если:

• пользователь может записать лекцию

• лекция загружается на сервер

• AI генерирует конспект

• появляются flashcards

• появляется quiz

• можно пройти practice режим

• работает paywall

• приложение стабильно на iOS 17+

## 11. AI Stack (используемые модели)

В приложении используются 2 типа моделей:

1. Speech-to-Text

2. LLM для анализа текста

### 11.1 Speech-to-Text модель

Используется:

OpenAI Transcription API

модель:

```
gpt-4o-mini-transcribe
```

Функции:

• преобразование аудио лекции в текст

• автоопределение языка

Pipeline:

```
audio (.m4a)
↓
speech-to-text
↓
transcript
```

Пример запроса:

```
POST /v1/audio/transcriptions
```

### 11.2 LLM модель

Используется:

```
GPT-4.1 mini
```

Причины выбора:

• низкая стоимость

• хорошее качество структурирования текста

• быстрый отклик

Модель используется для:

```
summary
outline
glossary
flashcards
quiz generation
```

### 11.3 AI Pipeline

Полный pipeline обработки лекции:

```
audio recording
↓
upload to Firebase Storage
↓
speech-to-text (gpt-4o-mini-transcribe)
↓
transcript
↓
LLM processing (GPT-4.1 mini)
↓
JSON structured output
↓
save to Firestore
```

### 11.4 LLM prompt (пример)

```
You are an educational AI assistant.

From the lecture transcript generate:

1. Title
2. Short summary
3. Detailed summary
4. Lecture outline
5. Key terms glossary
6. 10 flashcards (question-answer)
7. 5 quiz questions (multiple choice)

Return ONLY valid JSON.
```

### 11.5 Формат ответа модели

```
{
 "title": "string",
 "summaryShort": "string",
 "summaryLong": "string",
 "outline": ["string"],
 "glossary":[
   {"term":"string","definition":"string"}
 ],
 "flashcards":[
   {"q":"string","a":"string"}
 ],
 "quiz":[
   {
     "q":"string",
     "options":["A","B","C","D"],
     "correctIndex":0
   }
 ]
}
```

### 11.6 Оптимизация стоимости

Для уменьшения расходов:

1️⃣ LLM вызывается 1 раз на лекцию
2️⃣ transcript не отправляется повторно
3️⃣ flashcards и quiz генерируются в том же запросе

### 11.7 Будущие улучшения (V1)

Возможные улучшения:

**Speaker diarization**

```
кто говорит на лекции
```

**Semantic search**

```
lecture knowledge base
```

через embeddings.

**AI tutor**

чат с лекцией.
