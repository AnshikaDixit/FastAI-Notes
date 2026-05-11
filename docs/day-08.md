# Day 08 — Flutter Client: Connecting to FastAPI & SSE Streaming

**Date:** 2026-05-10  
**Developer:** Anshika Dixit  
**Repo:** [github.com/AnshikaDixit/FastAI-Notes](https://github.com/AnshikaDixit/FastAI-Notes)

---

## 🎯 What We Set Out to Do

Connect a Flutter app to the FastAPI backend built across Days 1–7. We wanted to:
- Build a clean, production-grade Flutter service layer for all API endpoints.
- Implement a **sealed Result pattern** for structured error handling.
- Connect to the **SSE streaming endpoint** (`GET /stream/export`) built on Day 07 and show notes appearing in real time.
- Establish the Flutter project architecture for future features.

---

## 🏗️ What Was Built

**`flutter_client/`** — A complete Flutter app at `my-fastapi-app/flutter_client/` covering:

| Feature | Screen/File |
|---------|-------------|
| Login + Signup | `screens/login_screen.dart`, `screens/signup_screen.dart` |
| Notes list (CRUD) | `screens/notes_screen.dart`, `screens/note_form_screen.dart` |
| Background export | `services/export_service.dart` (trigger + history) |
| ⭐ SSE Live Streaming | `screens/stream_export_screen.dart` |

---

## 📦 Architecture

### Pattern: Feature-first, Provider + Dio

```
flutter_client/lib/
├── config/          → AppConfig (base URL, keys)
├── core/            → DioClient, Result<T>, ApiException
├── utils/           → AppStrings, AppColors, AppTextStyles
├── models/          → Dart mirrors of Pydantic schemas
├── services/        → API call layer (Result<T> returns)
├── providers/       → ChangeNotifier state
└── screens/         → UI screens
```

---

## 📦 Feature 1 — Dio HTTP Client with Interceptors

### Why Dio over `http` package?
| Feature | `http` package | Dio |
|---------|---------------|-----|
| Interceptors | ❌ Manual per call | ✅ Middleware chain |
| Auto auth headers | ❌ Manual | ✅ `AuthInterceptor` |
| Error normalization | ❌ Manual | ✅ `ErrorInterceptor` |
| Typed errors | ❌ Exceptions mix | ✅ `DioException` types |

### Our Interceptor Chain (`core/dio_client.dart`):

```
Request → AuthInterceptor → ErrorInterceptor → Server
              ↓                    ↓
   Adds "Bearer <token>"   Catches DioException
   from SharedPrefs        → converts to ApiException
```

```dart
// Auth interceptor: runs on EVERY request automatically
class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(options, handler) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConfig.kAccessToken);
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }
}
```

---

## 📦 Feature 2 — Sealed Result\<T\> Pattern

### Problem with raw try/catch:
```dart
// ❌ BAD: Every caller must know what exceptions to expect
try {
  final response = await dio.get('/notes/');
  // ...
} on DioException catch (e) {
  // handle network error
} on FormatException catch (e) {
  // handle JSON error
} catch (e) {
  // handle unknown
}
```

### Our Result<T> pattern:
```dart
// ✅ GOOD: Service handles all errors, UI only sees Success/Failure
// In service:
Future<Result<List<Note>>> getNotes() async {
  try {
    final response = await _dio.get('/notes/');
    return Success(parseNotes(response.data));
  } on DioException catch (e) {
    return Failure(ApiException.fromDioError(e));
  }
}

// In provider:
final result = await noteService.getNotes();
switch (result) {
  case Success(:final data) => _notes = data;
  case Failure(:final exception) => _errorMessage = exception.message;
}
```

**Benefits:**
- Zero unhandled exceptions — all errors are typed and explicit
- UI never needs to `try/catch` — just pattern-matches on `Success`/`Failure`
- `ApiException` has `statusCode`, `message`, and `data` — consistent shape

---

## 📦 Feature 3 — SSE Streaming Consumer

### Why NOT Dio for SSE?

Dio is great for REST calls, but it buffers the entire response body before returning. For SSE, the connection stays open indefinitely. We need `http.Client().send()` which returns a `StreamedResponse` — a live byte stream.

```
Dio:   Request → ... waits for complete response ... → returns data
http:  Request → returns ByteStream immediately → data arrives chunk-by-chunk
```

### SSE consumer (`services/stream_service.dart`):

```dart
Stream<SseEvent> streamExport() async* {
  final request = http.Request('GET', Uri.parse('.../stream/export'));
  request.headers['Authorization'] = 'Bearer $token';
  
  final response = await http.Client().send(request);
  
  // Parse SSE line-by-line:
  // - "event: progress" → capture event type
  // - "data: {...}"     → capture JSON payload
  // - ""  (blank line)  → dispatch complete event
  
  String currentEvent = '';
  String currentData = '';
  
  await for (final line in response.stream
      .transform(utf8.decoder)
      .transform(const LineSplitter())) {
    if (line.startsWith('event: ')) {
      currentEvent = line.substring(7).trim();
    } else if (line.startsWith('data: ')) {
      currentData = line.substring(6).trim();
    } else if (line.isEmpty) {
      yield SseEvent(type: currentEvent, data: jsonDecode(currentData));
      currentEvent = '';
      currentData = '';
    }
  }
}
```

### Data flow through layers:

```
GET /stream/export (SSE connection open)
        ↓
StreamService.streamExport() → Stream<SseEvent>
        ↓
NoteStreamProvider.listen() → handles each SseEvent
  • isProgress → update statusMessage + progress counters
  • isChunk    → append to fullMarkdown
  • isComplete → set status = complete, fill progress bar
        ↓
StreamExportScreen (Consumer) → rebuilds on each notifyListeners()
  • Shows live status message
  • Progress bar fills from 0 → 1
  • Markdown content appears chunk by chunk
```

---

## 📱 Stream Export Screen Flow

```
┌─────────────────────────────────┐
│  Live Stream Export             │ ← AppBar (Copy button appears when done)
├─────────────────────────────────┤
│ ● Exporting note 2 of 3: ...   │ ← Live status message
│ ████████░░░░░░░ 2 / 3 notes   │ ← Progress bar
├─────────────────────────────────┤
│                                 │
│ # 📝 Notes Export              │ ← Markdown fills in chunk by chunk
│ **User:** user@example.com     │
│ **Exported at:** 2026-05-10    │
│                                 │
│ ## 1. My First Note            │
│ Description here...            │
│ _Created: 2026-05-09..._       │
│                                 │
│ ## 2. ...                      │ ← Auto-scrolls as content arrives
│                                 │
├─────────────────────────────────┤
│ [▶ Start Stream]               │ ← Button state: Start → Cancel → Stream Again
└─────────────────────────────────┘
```

---

## 🧠 Key Concepts Introduced on Day 08

| Concept | Where |
|---------|-------|
| `Result<T>` sealed class (Success/Failure) | `core/result.dart` |
| `ApiException` typed errors | `core/api_exception.dart` |
| Dio interceptor chain (auth + error) | `core/dio_client.dart` |
| Why Dio can't stream SSE | `services/stream_service.dart` |
| `http.Client().send()` for streaming | `services/stream_service.dart` |
| SSE line parsing in Dart | `services/stream_service.dart` |
| `ChangeNotifier` Provider pattern | `providers/*.dart` |
| Auth state with SharedPreferences | `providers/auth_provider.dart` |
| `ChangeNotifierProvider.value` scoped provider | `screens/stream_export_screen.dart` |

---

## 📁 New Files Created

| File | Purpose |
|------|---------|
| `flutter_client/lib/config/app_config.dart` | Base URL + env constants |
| `flutter_client/lib/core/result.dart` | Sealed `Result<T>` type |
| `flutter_client/lib/core/api_exception.dart` | Typed API exception |
| `flutter_client/lib/core/dio_client.dart` | Dio singleton with interceptors |
| `flutter_client/lib/utils/app_strings.dart` | All UI strings |
| `flutter_client/lib/utils/app_colors.dart` | Dark-mode color palette |
| `flutter_client/lib/utils/app_text_styles.dart` | Inter typography system |
| `flutter_client/lib/models/api_response.dart` | Generic APIResponse model |
| `flutter_client/lib/models/user.dart` | UserResponse + Token |
| `flutter_client/lib/models/note.dart` | Note + NoteCreate + NoteUpdate |
| `flutter_client/lib/models/activity_log.dart` | ActivityLog for export history |
| `flutter_client/lib/services/auth_service.dart` | signup, login, getMe |
| `flutter_client/lib/services/note_service.dart` | getNotes, createNote, updateNote, deleteNote |
| `flutter_client/lib/services/export_service.dart` | triggerExport, getHistory |
| `flutter_client/lib/services/stream_service.dart` | ⭐ SSE consumer via `http.Client` |
| `flutter_client/lib/providers/auth_provider.dart` | Auth state + token persistence |
| `flutter_client/lib/providers/note_provider.dart` | Notes CRUD state |
| `flutter_client/lib/providers/stream_provider.dart` | SSE streaming state |
| `flutter_client/lib/screens/login_screen.dart` | Login UI |
| `flutter_client/lib/screens/signup_screen.dart` | Signup UI |
| `flutter_client/lib/screens/notes_screen.dart` | Notes list + actions |
| `flutter_client/lib/screens/note_form_screen.dart` | Create/Edit form |
| `flutter_client/lib/screens/stream_export_screen.dart` | ⭐ Live SSE streaming UI |
| `flutter_client/lib/main.dart` | App entry + theme + routing |

---

## ✅ End of Day 08 — What Works

| Feature | Status |
|---------|--------|
| Flutter project compiles (`flutter analyze` — 0 issues) | ✅ |
| Dio singleton with auth + error interceptors | ✅ |
| `Result<T>` pattern across all services | ✅ |
| Login / Signup / Logout screens | ✅ |
| Notes CRUD (list, create, edit, delete) | ✅ |
| Background export trigger + history polling | ✅ |
| ⭐ SSE streaming via `http.Client().send()` | ✅ |
| Live progress bar + Markdown chunk-by-chunk | ✅ |
| Token persisted in SharedPreferences | ✅ |
| Dark-mode design with Inter font (Google Fonts) | ✅ |

---

## 🔄 How to Configure and Run

```bash
# 1. Update base URL in flutter_client/lib/config/app_config.dart
#    Replace <YOUR_EC2_IP> with your actual EC2 IP or domain

# 2. Get dependencies
cd flutter_client
flutter pub get

# 3. Run on a device/emulator (with FastAPI server running on EC2)
flutter run
```

> ⚠️ **EC2 note**: Android apps require `http://` connections to be explicitly allowed.
> For production, serve the API over HTTPS via Nginx + SSL (already in our Docker setup).
