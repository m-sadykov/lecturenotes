# Мини-ТЗ 08: Интеграция AI и валидация JSON-схемы

## Цель
Подключить STT и LLM для генерации структурированных учебных материалов по транскрипту.

## Scope
- STT: `gpt-4o-mini-transcribe` для получения transcript.
- LLM: `GPT-4.1 mini` для генерации JSON.
- Валидация структуры ответа перед сохранением.
- Нормализация данных `outline/glossary/flashcards/quiz`.

## Артефакты
- AI-клиент на backend.
- Prompt-template для LLM.
- JSON schema validator.

## Критерии приемки
- Ответ модели валидируется и парсится без падений pipeline.
- Сохраняются поля: `title`, `summaryShort`, `summaryLong`, `outline`, `glossary`, `flashcards`, `quiz`.
- Генерируется минимум 10 карточек и 5 quiz-вопросов.

## Зависимости
- Мини-ТЗ 07.
