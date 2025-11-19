# PDF Translation Feature Guide

## Overview
این قابلیت به کاربران اجازه می‌دهد که متن‌های PDF را انتخاب کرده و با استفاده از Google ML Kit Translation ترجمه کنند.

## Features
- ✅ انتخاب متن دلخواه در PDF
- ✅ ترجمه خودکار با Google ML Kit
- ✅ دانلود آفلاین مدل ترجمه
- ✅ نمایش متن اصلی و ترجمه شده
- ✅ UI زیبا و کاربرپسند

## Usage

### 1. باز کردن فایل PDF
1. به صفحه Backpack بروید
2. روی یک فایل PDF کلیک کنید
3. گزینه "Open PDF" را انتخاب کنید

### 2. دانلود مدل ترجمه (اولین بار)
در اولین استفاده، باید مدل ترجمه را دانلود کنید:
1. آیکون Download (⬇️) در AppBar را کلیک کنید
2. منتظر بمانید تا دانلود تکمیل شود
3. پس از دانلود، آماده استفاده است

### 3. انتخاب و ترجمه متن
1. متن دلخواه خود را در PDF انتخاب کنید (long press و drag)
2. دکمه "Translate to فارسی" در پایین صفحه ظاهر می‌شود
3. روی دکمه کلیک کنید
4. ترجمه در یک پنجره زیبا نمایش داده می‌شود

### 4. پاک کردن انتخاب
- آیکون Clear (✕) در AppBar را کلیک کنید

## Configuration

### تغییر زبان‌ها
برای تغییر زبان مبدا و مقصد، فایل زیر را ویرایش کنید:

**File:** `lib/config/translation_config.dart`

```dart
class TranslationConfig {
  // Source language (زبان متن PDF)
  static const TranslateLanguage sourceLanguage = TranslateLanguage.english;

  // Target language (زبان ترجمه)
  static const TranslateLanguage targetLanguage = TranslateLanguage.persian;
}
```

### زبان‌های پشتیبانی شده
Google ML Kit از زبان‌های زیادی پشتیبانی می‌کند:
- English
- Persian (فارسی)
- Arabic (العربية)
- French (Français)
- German (Deutsch)
- Spanish (Español)
- Chinese
- Japanese
- Korean
- و بسیاری دیگر...

برای لیست کامل، [مستندات Google ML Kit](https://developers.google.com/ml-kit/language/translation/translation-language-support) را ببینید.

## Technical Details

### Files Created
1. **lib/config/translation_config.dart** - تنظیمات زبان
2. **lib/services/translation_service.dart** - سرویس ترجمه
3. **lib/frontend/screens/pdf_viewer_screen.dart** - صفحه نمایش PDF با قابلیت ترجمه

### Dependencies
```yaml
google_mlkit_translation: ^0.13.0
pdfrx: ^1.3.5
```

### Architecture
```
┌─────────────────────────────────────┐
│     PDF Viewer Screen               │
│  (User selects text)                │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│   Translation Service                │
│  - Initialize translator             │
│  - Download model                    │
│  - Translate text                    │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│   Google ML Kit Translation          │
│  (On-device translation)             │
└─────────────────────────────────────┘
```

## Features in Detail

### Text Selection
- استفاده از قابلیت `enableTextSelection` در pdfrx
- انتخاب متن با long press و drag
- نمایش دکمه ترجمه به صورت خودکار

### Translation Dialog
- نمایش متن اصلی و ترجمه شده
- نمایش زبان‌های مبدا و مقصد
- UI زیبا با theme تیره
- Draggable sheet برای راحتی استفاده

### Model Management
- دانلود خودکار مدل در صورت نیاز
- نمایش پیشرفت دانلود
- بررسی وضعیت مدل قبل از ترجمه
- امکان حذف مدل برای آزادسازی فضا

## Tips
- مدل ترجمه فقط یک بار دانلود می‌شود و برای همیشه ذخیره می‌ماند
- ترجمه کاملاً آفلاین انجام می‌شود
- برای بهترین نتیجه، متن‌های کوتاه‌تر را انتخاب کنید
- می‌توانید چندین ترجمه پشت سر هم انجام دهید

## Future Enhancements
- [ ] امکان تغییر زبان از UI
- [ ] کپی کردن ترجمه به clipboard
- [ ] ذخیره ترجمه‌ها
- [ ] نمایش تاریخچه ترجمه‌ها
- [ ] پشتیبانی از چند زبان مقصد همزمان
- [ ] تنظیمات پیشرفته‌تر ترجمه

## Troubleshooting

### مدل دانلود نمی‌شود
- اتصال اینترنت خود را بررسی کنید
- فضای کافی روی دستگاه داشته باشید
- اپلیکیشن را ریستارت کنید

### ترجمه انجام نمی‌شود
- مطمئن شوید مدل دانلود شده است
- متن انتخاب شده خالی نباشد
- زبان متن با sourceLanguage در config مطابقت داشته باشد

### متن قابل انتخاب نیست
- بعضی PDF‌ها به صورت تصویری هستند و متن ندارند
- در این صورت باید از OCR استفاده کنید

## Support
برای گزارش مشکل یا پیشنهاد، Issue ایجاد کنید.
