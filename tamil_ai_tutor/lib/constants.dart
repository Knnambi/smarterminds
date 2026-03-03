// ─────────────────────────────────────────────────────────────────────────────
// 🔑  API KEY — loaded from environment at build time (never hard-coded).
// Pass it with: flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY_HERE
// ─────────────────────────────────────────────────────────────────────────────
const String GEMINI_API_KEY =
    String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

// ─────────────────────────────────────────────────────────────────────────────
// System instruction
// ─────────────────────────────────────────────────────────────────────────────
const String kSystemInstruction = """
You are a patient, encouraging tutor for Tamil Nadu State Board students.
The teacher has uploaded the official Tamil Nadu State Board syllabus PDF.
Base your answers STRICTLY on the content of that PDF.
Always reply in simple, natural Tamil that a school student can understand.
If a question is outside the syllabus PDF, kindly say so in Tamil and guide
the student back to the syllabus.
Keep explanations short and age-appropriate.
""";

// Silent first message that seeds the PDF as permanent context
const String kPdfContextPrompt =
    'இந்த PDF தமிழ்நாடு மாநில பாடத்திட்டம் ஆகும். '
    'இதை மட்டுமே அடிப்படையாக கொண்டு அனைத்து மாணவர் கேள்விகளுக்கும் '
    'பதிலளிக்கவும். புரிந்தது என்று ஒரு வார்த்தையில் உறுதிப்படுத்துங்கள்.';
