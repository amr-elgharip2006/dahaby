# Dahaby App

تطبيق Flutter. بيكلم الـ backend بس.

## التشغيل

شغّل الـ backend الأول (شوف `../backend/README.md`)، وبعدين:

```bash
cd app
flutter pub get
flutter run --dart-define=BACKEND_URL=http://10.0.2.2:8080
```

- على Android emulator استخدم `http://10.0.2.2:8080`.
- على موبايل حقيقي استخدم IP الجهاز اللي عليه السيرفر، مثلاً `http://192.168.1.10:8080`.
- من غير `BACKEND_URL` التطبيق بيستخدم `http://localhost:8080`.

## الاختبارات

```bash
flutter analyze
flutter test
```

## هيكل الكود

```
lib/
  config.dart   عنوان السيرفر
  data/         الاتصال بالسيرفر والتخزين المحلي
  logic/        الـ Cubits
  ui/           الشاشات
```
