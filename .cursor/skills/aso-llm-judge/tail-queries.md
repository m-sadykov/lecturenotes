# Tail Query Bank — Lectra: AI Study Notes

Default query set for LLM-as-judge runs. Adapt phrasing per locale; keep intent equivalent.

**Mix:** 12 head + 18 tail (niche / long-tail)

**Keyword seed (en-US):** `lecture notes`, `flashcards`, `quiz`, `exam prep`, `transcription`, `speech to text`, `pdf notes`, `youtube`, `class notes`

Title/subtitle already cover: *Lectra*, *AI*, *Study*, *Notes*, *Lectures*, *Quizzes* — prefer long-tail phrasing that expands keyword intent rather than repeating title alone. Recording intent lives mainly in description.

## Head queries (volume)

1. lecture notes ai
2. lecture recorder
3. ai study notes
4. lecture transcription
5. flashcards from lectures
6. exam prep app
7. speech to text notes
8. ai note taker
9. study quiz app
10. record lecture notes
11. pdf to notes ai
12. youtube to notes

## Tail queries (niche — highest ASO leverage)

13. record college lecture to flashcards
14. ai transcript summary quiz from lecture
15. turn lecture audio into study notes
16. speech to text lecture notes app
17. generate flashcards from recorded lecture
18. youtube lecture to flashcards quiz
19. pdf lecture slides to summary notes
20. ai class notes from audio recording
21. active recall flashcards from lectures
22. student exam prep from lecture recordings
23. import youtube video study notes
24. lecture voice notes to quiz
25. university lecture transcription study app
26. summarize lecture recording for exam
27. ai notes from pdf and youtube
28. convert lecture recording to flashcards
29. classroom lecture recorder with quizzes
30. audio to text study notes flashcards

## Optional extras (swap in if user removes head queries)

- record class and make flashcards
- lecture summary generator for students
- youtube video to quiz study app
- pdf textbook to flashcards ai
- voice lecture to transcript and notes
- revise lectures with quizzes
- meeting? (only if metadata claims it — currently no)
- offline? (only if metadata claims it — currently no)

## Intent theme mapping

| Theme | Keyword seeds | Queries |
|-------|---------------|---------|
| Lecture record / note taking | lecture notes, lecture recorder | 1, 2, 3, 8, 10, 15, 20, 24, 29 |
| Transcription / speech-to-text | transcription, speech to text | 4, 7, 16, 25, 30 |
| Summaries & study notes | summarize, pdf notes | 11, 15, 19, 26, 27 |
| Flashcards / quiz / active recall | flashcards, quiz | 5, 9, 13, 17, 18, 21, 28 |
| Exam prep / student workflow | exam prep | 6, 14, 22, 26 |
| Multi-import (PDF / YouTube / audio) | pdf notes, youtube | 11, 12, 18, 19, 23, 27 |

When scoring, track average per theme to guide metadata recommendations.

## Locale: ar-SA (intent-equivalent)

Use these when judging `metadata/app-info/ar-SA.json` + `metadata/version/{version}/ar-SA.json`.

### Head

1. ملاحظات محاضرات ai
2. مسجل محاضرات
3. ملاحظات دراسة ai
4. تفريغ محاضرات
5. بطاقات تعليمية من المحاضرات
6. تطبيق تحضير امتحان
7. تحويل كلام إلى نص ملاحظات
8. كاتب ملاحظات بالذكاء الاصطناعي
9. تطبيق اختبارات دراسية
10. تسجيل ملاحظات محاضرة
11. pdf إلى ملاحظات ai
12. youtube إلى ملاحظات

### Tail

13. سجل محاضرة كلية إلى بطاقات تعليمية
14. تفريغ وملخص واختبار من محاضرة بالذكاء الاصطناعي
15. حول صوت المحاضرة إلى ملاحظات دراسة
16. تطبيق تحويل كلام إلى نص لملاحظات المحاضرات
17. أنشئ بطاقات من محاضرة مسجلة
18. محاضرة يوتيوب إلى بطاقات واختبارات
19. شرائح محاضرة pdf إلى ملخص وملاحظات
20. ملاحظات صف بالذكاء الاصطناعي من تسجيل صوتي
21. بطاقات استرجاع نشط من المحاضرات
22. تحضير امتحان للطلاب من تسجيلات المحاضرات
23. استيراد فيديو يوتيوب لملاحظات دراسة
24. ملاحظات صوتية للمحاضرة إلى اختبار
25. تطبيق تفريغ محاضرات الجامعة للدراسة
26. لخص تسجيل محاضرة للامتحان
27. ملاحظات ai من pdf وyoutube
28. حول تسجيل المحاضرة إلى بطاقات تعليمية
29. مسجل محاضرات الصف مع اختبارات
30. صوت إلى نص ملاحظات دراسة وبطاقات

## Locale: ca (intent-equivalent)

Use when judging `metadata/app-info/ca.json` + `metadata/version/{version}/ca.json`.

### Head

1. apunts de classe ia
2. enregistrador de classes
3. apunts d'estudi ia
4. transcripció de classes
5. targetes d'estudi a partir de classes
6. app preparar exàmens
7. veu a text apunts
8. prenedor d'apunts ia
9. app qüestionaris estudi
10. enregistra apunts de classe
11. pdf a apunts ia
12. youtube a apunts

### Tail

13. enregistra classe universitat a targetes
14. transcripció resum qüestionari de classe ia
15. converteix àudio de classe en apunts
16. app veu a text apunts de classes
17. genera targetes d'una classe enregistrada
18. classe youtube a targetes i qüestionaris
19. diapositives pdf a resum i apunts
20. apunts de classe ia des d'àudio
21. targetes active recall de classes
22. preparar exàmens estudiants des d'enregistraments
23. importa vídeo youtube apunts estudi
24. notes de veu de classe a qüestionari
25. app transcripció classes universitat
26. resumeix enregistrament de classe per a examen
27. apunts ia de pdf i youtube
28. converteix enregistrament a targetes
29. enregistrador aula amb qüestionaris
30. àudio a text apunts i targetes

## Locale: cs (intent-equivalent)

Use when judging `metadata/app-info/cs.json` + `metadata/version/{version}/cs.json`.

### Head

1. poznámky z přednášek ai
2. nahrávač přednášek
3. ai studijní poznámky
4. přepis přednášek
5. kartičky z přednášek
6. app příprava na zkoušky
7. řeč na text poznámky
8. ai zapisovač poznámek
9. studijní kvíz app
10. nahraj poznámky z přednášky
11. pdf na poznámky ai
12. youtube na poznámky

### Tail

13. nahraj univerzitní přednášku na kartičky
14. přepis shrnutí kvíz z přednášky ai
15. převeď audio přednášky na studijní poznámky
16. app řeč na text poznámky z přednášek
17. vygeneruj kartičky z nahrané přednášky
18. youtube přednáška na kartičky a kvízy
19. pdf slidů přednášky na shrnutí a poznámky
20. ai třídní poznámky z audionahrávky
21. kartičky active recall z přednášek
22. příprava na zkoušky pro studenty z nahrávek
23. import youtube video studijní poznámky
24. hlasové poznámky z přednášky na kvíz
25. app přepis univerzitních přednášek
26. shrň nahrávku přednášky ke zkoušce
27. ai poznámky z pdf a youtube
28. převeď nahrávku přednášky na kartičky
29. nahrávač přednášek ve třídě s kvízy
30. audio na text studijní poznámky a kartičky

## Locale: da (intent-equivalent)

Use when judging `metadata/app-info/da.json` + `metadata/version/{version}/da.json`.

### Head

1. forelæsningsnoter ai
2. forelæsningsoptager
3. ai studienoter
4. transskription af forelæsninger
5. flashcards fra forelæsninger
6. app eksamensforberedelse
7. tale til tekst noter
8. ai notetager
9. studiequiz app
10. optag forelæsningsnoter
11. pdf til noter ai
12. youtube til noter

### Tail

13. optag universitetsforelæsning til flashcards
14. ai transskription resumé quiz fra forelæsning
15. gør forelæsningslyd til studienoter
16. app tale til tekst forelæsningsnoter
17. generer flashcards fra optaget forelæsning
18. youtube-forelæsning til flashcards og quizzer
19. pdf slides fra forelæsning til resumé og noter
20. ai klassenoter fra lydoptagelse
21. active recall flashcards fra forelæsninger
22. eksamensforberedelse for studerende fra optagelser
23. importer youtube-video studienoter
24. stemmenoter fra forelæsning til quiz
25. app transskription af universitetsforelæsninger
26. opsummer forelæsningsoptagelse til eksamen
27. ai noter fra pdf og youtube
28. konverter forelæsningsoptagelse til flashcards
29. klasseværelsesoptager med quizzer
30. lyd til tekst studienoter og flashcards
