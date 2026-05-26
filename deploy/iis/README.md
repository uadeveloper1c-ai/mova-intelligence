# MOVA Intelligence IIS deploy

## 1. Build Flutter Web

Run from the Flutter project root:

```powershell
flutter build web --base-href /app/ --dart-define=API_BASE_URL=/hs/api
```

## 2. IIS application

Create a new IIS Application inside the existing `intelligence.mova.beer` site:

```text
Alias: app
Physical path: C:\inetpub\mova-intelligence-app
```

Copy everything from:

```text
C:\MobileProjects\Mova\mova_intelligence_app\build\web
```

to:

```text
C:\inetpub\mova-intelligence-app
```

Then copy:

```text
deploy\iis\app\web.config
```

to:

```text
C:\inetpub\mova-intelligence-app\web.config
```

## 3. Root landing page button

Add the contents of:

```text
deploy\iis\root-index-web-button-snippet.html
```

to the button block in the existing root `index.html`, near the APK, TestFlight, and instruction links.

The intended URL layout:

```text
https://intelligence.mova.beer/        existing landing page
https://intelligence.mova.beer/app/    Flutter Web app
https://intelligence.mova.beer/hs/api  1C API
```
