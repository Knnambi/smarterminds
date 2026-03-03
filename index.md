# Tamil AI Tutor

**தமிழ்நாடு மாநில பாட வாரிய AI ஆசிரியர்**

A free AI-powered tutor for Tamil Nadu State Board students, built with Flutter and Google Gemini.

---

## What it does

- Teachers upload the official **Tamil Nadu State Board syllabus PDF**
- Students ask questions in **Tamil** — by typing or speaking
- Gemini reads the PDF and answers **strictly from the syllabus**
- Responses are read aloud in **Tamil voice**

## Features

| Feature | Details |
|---|---|
| AI Model | Gemini 1.5 Flash (long-context PDF reading) |
| Language | Tamil (தமிழ்) |
| Voice input | Speech-to-Text via microphone |
| Voice output | Text-to-Speech in Tamil |
| Platform | Android + Web |

## Run it

**Android (local):**
```bash
cd tamil_ai_tutor
flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY
```

**Web (local):**
```bash
cd tamil_ai_tutor
flutter run -d chrome --dart-define=GEMINI_API_KEY=YOUR_KEY
```

**Deploy to GitHub Pages:**

1. Go to **Settings → Secrets → Actions** in this repo
2. Add a secret named `GEMINI_API_KEY` with your Gemini API key
3. Push to `master` — GitHub Actions will build and deploy automatically
4. The live app will appear at `https://knnambi.github.io/smarterminds/`

## Project structure

```
tamil_ai_tutor/
  lib/
    main.dart                      ← App entry point
    constants.dart                 ← API key + AI prompts
    models/
      chat_message.dart            ← Data model
    screens/
      syllabus_loader_screen.dart  ← PDF upload screen
      chat_screen.dart             ← Chat + voice screen
    widgets/
      bouncing_dot.dart            ← Typing indicator dot
```

---

*Powered by [Google Gemini](https://ai.google.dev/) · Built with [Flutter](https://flutter.dev/)*
