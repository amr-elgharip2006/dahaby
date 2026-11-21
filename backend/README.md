# Dahaby Backend

سيرفر Dart صغير. هو الوحيد اللي بيكلم المصادر الخارجية، والتطبيق بيكلمه هو بس.

## التشغيل

```bash
cd backend
dart pub get
dart run bin/server.dart
```

## الإعدادات (environment variables)

| المتغير | الوظيفة | الافتراضي |
|---|---|---|
| `PORT` | البورت | `8080` |
| `ANTHROPIC_API_KEY` | مفتاح Claude. من غيره مسارات الـ AI بترجع 503 | — |
| `CLAUDE_MODEL` | الموديل | `claude-opus-5-5` |
| `GLOBAL_POLL_SECONDS` | كل كام ثانية نسأل عن السعر العالمي (أقل حاجة 5) | `15` |

المفتاح بيتحط في الـ environment على السيرفر بس. ما يتكتبش في الكود وما يترفعش على الريبو.

## المسارات

| المسار | الوظيفة |
|---|---|
| `GET /health` | حالة السيرفر |
| `GET /prices` | آخر أسعار |
| `GET /history?asset=gold21` | تاريخ 30 يوم. القيم: `gold24` `gold21` `gold18` `goldPound` `silver` `usd` |
| `GET /ws` | WebSocket: بيبعت الأسعار عند الاتصال، وبعدها كل ما رقم يتغير |
| `POST /ai/summary` | ملخص للسوق والمحفظة. الجسم: `{"portfolio": ...}` |
| `POST /ai/chat` | شات. الجسم: `{"messages": [{"role": "user", "content": "..."}], "portfolio": ...}` |

مسارات الـ AI عليها حد 20 طلب في الساعة لكل عنوان IP.

### شكل رسالة الأسعار

```json
{
  "updatedAt": "2026-11-21T10:48:55Z",
  "usdEgp": 53.81,
  "global": {
    "goldOunceUsd": 3539.0, "silverOunceUsd": 41.08,
    "gold24": 6122.58, "gold21": 5357.26, "gold18": 4591.93, "silver": 71.07,
    "asOf": "2026-11-21T10:48:38Z"
  },
  "local": {
    "gold21": {"buy": 5450, "sell": 5442.17},
    "asOf": "2026-11-21T10:00:00Z"
  }
}
```

- `global`: السعر العالمي محوّل لجنيه للجرام.
- `local`: سعر السوق المصري. `buy` اللي بتدفعه لما تشتري، و`sell` اللي بتاخده لما تبيع.

## الاختبارات

```bash
dart test
```
