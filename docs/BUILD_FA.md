# بیلد با مایکت، امضای ثابت و انتقال اطلاعات

پیش‌نیاز: Flutter 3.44.2، Java 17 یا 21، Android SDK 36 و NDK موردنیاز Flutter.
از ریشه پروژه در PowerShell اجرا کن:

```powershell
.\scripts\build-myket.ps1 -UseWindowsCertificates
```

اسکریپت دریافت وابستگی‌ها، تولید ترجمه‌ها، تحلیل، تست و بیلد release را انجام می‌دهد.
بعد از اجرای موفق بررسی‌ها می‌توانی `-SkipChecks` بدهی.
اگر همه وابستگی‌ها از قبل در کش هستند، `-Offline` دریافت و بررسی شبکه Gradle/Pub را
حذف می‌کند؛ در کش ناقص خطای وابستگی گم‌شده می‌گیری و باید بدون این گزینه اجرا کنی.
فایل نصب: `build/app/outputs/flutter-apk/app-release.apk`.

تنظیم متغیرهای دریافت پکیج، اگر فقط `pub get` را دستی اجرا می‌کنی:

```powershell
$env:PUB_HOSTED_URL = 'https://pub.myket.ir'
$env:FLUTTER_STORAGE_BASE_URL = 'https://pub.myket.ir'
flutter pub get
```

برای بیلد کامل محلی از اسکریپت بالا استفاده کن؛ آن اسکریپت تنظیم مخازن Gradle،
Wrapper محلی، تولید ترجمه‌ها، تحلیل، تست و امضا را هم انجام می‌دهد.

در بیلد محلی با این اسکریپت، Pub و فایل‌های Flutter از `pub.myket.ir` و وابستگی‌های
Gradle از `maven.myket.ir` دریافت می‌شوند. اسکریپت init وابستگی‌های Gradle خود SDK
را هم پوشش می‌دهد، بدون تغییر SDK. یک Wrapper محلی در `build/myket-wrapper/` از
`https://maven.myket.ir/gradle/distributions/gradle-8.13-bin.zip` دریافت می‌کند.
فایل Wrapper اصلی پروژه و مخازن Gradle برای GitHub رسمی باقی می‌مانند.
منابع: [راهنمای Flutter مایکت](https://maven.myket.ir/services/flutter.html)،
[راهنمای Wrapper](https://maven.myket.ir/services/gradle-wrapper.html).

اگر Java خطای `PKIX path building failed` داد و HTTPS با ویندوز معتبر است:

```powershell
# فقط ویندوز: استفاده از مخزن گواهی‌های معتبر سیستم، بدون خاموش‌کردن بررسی TLS
.\scripts\build-myket.ps1 -BuildNumber 2 -UseWindowsCertificates
```

## نگهداری امضا و آپدیت

کلید ثابت اکنون در `android/signing/study-release.jks` ساخته شده؛ رمز و alias در
`android/key.properties` هستند. **هر دو فایل را جداگانه در محل امن پشتیبان بگیر
و کلید را عوض نکن.** این فایل‌ها در Git و APK قرار نمی‌گیرند. فقط برای یک پروژه
فاقد کلید، `scripts/create-release-key.ps1` کلید جدید می‌سازد؛ فایل موجود را بازنویسی
نمی‌کند. Release بدون تنظیم امضا خطا می‌دهد و به debug برنمی‌گردد.

شناسه بسته `com.example.study` و نام دیتابیس `study.db` باید ثابت بمانند.
شماره بیلد هر نسخه را افزایش بده (`1.1.0+2` یعنی شماره ۲).
اسکریپت بیلد در حالت پیش‌فرض شماره را از ثانیه‌های سپری‌شده از ابتدای ۲۰۲۰ UTC
می‌سازد تا بیلد محلی و CI شماره افزایشی داشته باشند؛ `-BuildNumber` آن را دستی تعیین می‌کند.
APK سازگار روی اپ قبلی نصب می‌شود و داده داخلی و مهاجرت‌های SQLite حفظ می‌شوند:

```powershell
& "$env:ANDROID_HOME\platform-tools\adb.exe" install -r .\build\app\outputs\flutter-apk\app-release.apk
```

اگر خطای `INSTALL_FAILED_UPDATE_INCOMPATIBLE` دیدی، نسخه قبلی را بدون پشتیبان
حذف نکن. [مستندات امضای اندروید](https://developer.android.com/studio/publish/app-signing).

### نتیجه بررسی APK قبلی

- SHA-256 فایل: `dde92c64110e9a1b16acfe6b17f58a61db14d5365494f6746a7c44c0033c4516`
- بسته `com.example.study`، نسخه `1.0.0`، versionCode برابر ۱.
- گواهی debug: `6d088a3df1208496cde189a41c42503d92671765a50592bab8e80118da50036e`.
- کلید debug این کامپیوتر با آن متفاوت است.
- Workflow قبلی GitHub کلید debug موقت runner را نگه نمی‌داشت؛ کلید خصوصی را
  از APK نمی‌توان بازیابی کرد.

**بیلد جدید با کلید جدید نمی‌تواند APK قبلی ارسال‌شده را مستقیم آپدیت کند.**
اگر همان کی‌استور قبلی پیدا شد، تنظیمات امضا را با آن انجام بده. در غیر این صورت،
ابتدا در نسخه قدیمی از هر برنامه CSV بگیر و خارج از فضای داخلی اپ ذخیره کن.
نسخه جدید در منوی پشتیبان صفحه برنامه‌ها CSV را وارد می‌کند. عنوان، تاریخ، مدت
و هدف روزانه منتقل می‌شوند؛ بازه اصلی برنامه و تایمر ذخیره‌نشده در CSV نیستند.
بعد از انتقال، بازه برنامه را ویرایش کن. اگر نسخه قدیمی خروجی ندارد، ابتدا راه
استخراج داده آن نسخه بررسی شود؛ حذف اپ اطلاعات داخلی آن را از بین می‌برد.

پشتیبان JSON نسخه جدید کل برنامه‌ها، بازه‌ها، هدف‌ها و جلسه‌های ثبت‌شده را حفظ
می‌کند. ابتدا تایمر باقی‌مانده را ذخیره یا حذف کن. واردکردن فایل، داده فعلی را
حفظ می‌کند؛ واردکردن مجدد همان فایل جلسه تکراری نمی‌سازد. سقف فایل ۲۰ مگابایت است.
JSON رمزگذاری نشده است.

## GitHub

Workflow جدید به این چهار Secret نیاز دارد:

```text
ANDROID_KEYSTORE_BASE64
ANDROID_STORE_PASSWORD
ANDROID_KEY_PASSWORD
ANDROID_KEY_ALIAS
```

اولی Base64 همان کی‌استور محلی و بقیه از `android/key.properties` هستند.
در Settings → Secrets and variables → Actions ریپو تنظیم کن، یا با GitHub CLI
نصب‌شده و واردشده به حساب:

```powershell
.\scripts\set-github-signing.ps1 -Repository mehran-shabani/study
```

این اسکریپت مقادیر را به Secrets خصوصی ریپو می‌فرستد و چاپ نمی‌کند.
در این جلسه چهار Secret تنظیم شدند؛ مقادیر آماده کپی در فایل محلی
`release/github-secrets.txt` هستند. این فایل خصوصی است و در Git قرار نمی‌گیرد.
پشتیبان کلید و رمز هم در `release/study-signing-backup.zip` قرار دارد.
برای بازیابی ZIP روی کامپیوتر دیگر، `study-release.jks` را در
`android/signing/` و `key.properties` را در `android/` بگذار.
تغییر Workflow به‌تنهایی Secrets را ایجاد نمی‌کند. CI شماره بیلد را از تعداد ثانیه‌ها از ابتدای
سال ۲۰۲۰ UTC می‌گیرد؛ بیلد محلی بعد از نسخه CI باید `-BuildNumber` بزرگ‌تری داشته باشد.
PR فقط تست و تحلیل می‌شود. کلید محلی و CI باید یکسان باشند.

**GitHub از مخازن اصلی استفاده می‌کند:** `pub.dev` برای پکیج‌ها،
`storage.googleapis.com` برای Flutter، مخازن Google/Maven Central/Gradle Plugin
Portal برای Gradle و `services.gradle.org` برای Wrapper. مایکت فقط در اجرای محلی
`scripts/build-myket.ps1` فعال می‌شود. اسکریپت بعد از بیلد آدرس‌های lockfile را به
`pub.dev` برمی‌گرداند، بدون تغییر نسخه‌ها و checksumها. تغییر فایل‌های Workflow
هنوز محلی است و باید به GitHub push شود تا روی CI اعمال شود.

## هشدار آگاهی

۱۵ دقیقه مطالعه فعال یک بوق، ۳۰ دقیقه دو، ۴۵ دقیقه سه، ۶۰ دقیقه چهار و به همین
ترتیب؛ استراحت حساب نمی‌شود. تنظیم روشن/خاموش ذخیره می‌شود. دکمه آزمایش صدا یک
بوق می‌زند. صدا از صدای رسانه گوشی استفاده می‌کند.

سرویس اندروید با اعلان فعال و wake lock فقط هنگام مطالعه و روشن‌بودن هشدار
کار می‌کند تا خاموشی صفحه زمان‌بندی را متوقف نکند؛ باتری بیشتری مصرف می‌کند.
Pause، Stop و خاموش‌کردن هشدار سرویس و بوق در حال پخش را متوقف می‌کنند.
بازکردن مجدد یا روشن‌کردن هشدار، بوق‌های گذشته را پخش نمی‌کند؛ هشدار بعدی از مرز
۱۵ دقیقه بعدی ادامه می‌یابد. Force stop، ری‌استارت گوشی و محدودیت سختگیرانه باتری
می‌توانند سرویس را متوقف کنند؛ زمان مطالعه محفوظ است، برای ادامه هشدار اپ را باز کن.
