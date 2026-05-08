# Day 07 — StreamingResponse & Server-Sent Events (SSE)

**Date:** 2026-05-09  
**Developer:** Anshika Dixit  
**Repo:** [github.com/AnshikaDixit/FastAI-Notes](https://github.com/AnshikaDixit/FastAI-Notes)

---

## 🎯 What We Set Out to Do

Learn and implement **StreamingResponse** and **SSE (Server-Sent Events)** in FastAPI. We wanted to:
- Understand how responses can be **streamed** chunk-by-chunk instead of sent all at once.
- Implement the SSE protocol — a standard for real-time server → client push.
- Build a **streaming export** — the real-time counterpart to Day 06's fire-and-forget export.
- Understand when to use SSE vs WebSocket vs BackgroundTasks.

---

## 🏗️ What Was Built

**`GET /stream/export`** — Streams the Markdown note export as SSE events in real time. The client watches progress updates and receives the Markdown content chunk-by-chunk.

This is the **streaming counterpart** to Day 06's `POST /export/notes`:

| | Day 06: Fire-and-Forget | Day 07: Streamed Export |
|---|---|---|
| **Endpoint** | `POST /export/notes` | `GET /stream/export` |
| **Client experience** | Returns 202 instantly, poll `/export/history` later | Watches the export happen live |
| **Output** | Markdown file saved on server | Markdown streamed to client |
| **Use case** | Heavy work, client doesn't need to watch | Client wants real-time progress |

---

## 📦 Feature — Streamed Export via SSE

### What is StreamingResponse?

Normally, FastAPI builds the **entire** response body in memory, then sends it. `StreamingResponse` is different — it takes a **generator function** and sends data chunk-by-chunk as it's produced:

```
Normal Response:        StreamingResponse:
┌──────────┐            ┌──────────┐
│ Build    │            │ yield #1 │ → send to client
│ entire   │            │ yield #2 │ → send to client
│ response │            │ yield #3 │ → send to client
│ in memory│            │   ...    │
└────┬─────┘            └──────────┘
     │
     ▼
Send everything
at once
```

### What is SSE (Server-Sent Events)?

SSE is a **standard protocol** (part of HTML5) for pushing events from server to client over a single HTTP connection. It's built on top of regular HTTP — no WebSocket upgrade needed.

### The SSE Protocol Format:

Each event is a block of text with specific fields:
```
event: progress        ← type of event (optional, names the event)
id: 3                  ← unique ID (optional, helps with reconnection)
data: {"message":"..."}← the payload (required, JSON-serialized)
                       ← blank line = end of this event
```

### How Our Endpoint Works:

```
1. Client → GET /stream/export  (with Bearer token)
2. Server → Responds with Content-Type: text/event-stream
3. Server → Connection stays OPEN, starts yielding events:

   event: progress
   id: 0
   data: {"step": "start", "message": "Preparing export...", "total_notes": 3}

   event: chunk
   id: 1
   data: {"content": "# 📝 Notes Export\n**User:** user@example.com\n..."}

   event: progress          ← 0.4s delay
   id: progress-1
   data: {"step": "exporting", "message": "Exporting note 1 of 3: My Note", "current": 1}

   event: chunk
   id: chunk-1
   data: {"content": "## 1. My Note\n\nDescription here...\n\n---\n\n"}

   ... (repeats for each note) ...

   event: complete
   id: done
   data: {"message": "Export finished!", "total_notes": 3}

4. Connection closes after all events are sent.
```

### Three Event Types:

| Event | Purpose | Data payload |
|-------|---------|-------------|
| `progress` | Status updates for the client | `step`, `message`, `current`, `total_notes` |
| `chunk` | Actual Markdown content | `content` (Markdown string) |
| `complete` | Export finished | `message`, `total_notes` |

---

## 🧠 Key Concepts Explained

### Why `async` generators + `asyncio.sleep()` instead of `time.sleep()`?

```python
# ❌ BAD: Blocks the entire server — no other requests can be served
time.sleep(1)

# ✅ GOOD: Only pauses this coroutine — other requests continue normally
await asyncio.sleep(1)
```

`time.sleep()` freezes the event loop. `asyncio.sleep()` yields control back to the loop, letting FastAPI handle other requests while this one waits.

### Critical Headers for SSE:

| Header | Why it's needed |
|--------|----------------|
| `Content-Type: text/event-stream` | **Mandatory.** Tells the client to parse the stream as SSE events |
| `Cache-Control: no-cache` | Prevents proxies/CDNs from buffering the entire response |
| `Connection: keep-alive` | Keeps the TCP connection open (default in HTTP/1.1, explicit for clarity) |
| `X-Accel-Buffering: no` | Disables **Nginx's** response buffering — critical for our Docker setup |

### SSE vs WebSocket vs BackgroundTasks:

| Feature | BackgroundTasks (Day 06) | SSE (Day 07) | WebSocket |
|---------|--------------------------|--------------|-----------|
| Direction | Fire-and-forget | Server → Client | Server ↔ Client |
| Client waits? | ❌ No (polls later) | ✅ Yes (watches live) | ✅ Yes (bidirectional) |
| Protocol | Regular HTTP | HTTP (text/event-stream) | WS upgrade |
| Reconnection | N/A (check history) | Built-in auto-reconnect | Manual |
| Complexity | Simplest | Simple | Complex |
| Best for | Heavy tasks, email, exports | Live feeds, progress | Chat, games |

### Day 06 vs Day 07 — The Contrast:

```
Day 06 (BackgroundTasks):              Day 07 (SSE):
Client: "Export my notes"              Client: "Stream-export my notes"
Server: "Got it, check back later"     Server: "Here they come, watch..."
         ↓                                       ↓
(Client leaves, task runs silently)    "Preparing export..." (progress)
         ↓                             "Exporting note 1 of 3..." (progress)
Client: "Is it done yet?"              ## 1. My Note (chunk)
Server: "Yes! File is at exports/"     "Exporting note 2 of 3..." (progress)
                                        ## 2. Another Note (chunk)
                                        "Export finished!" (complete)
```

---

## 📱 Flutter Client Example

How a Flutter app would consume this SSE endpoint:

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

final request = http.Request('GET', Uri.parse('$baseUrl/stream/export'));
request.headers['Authorization'] = 'Bearer $token';

final client = http.Client();
final response = await client.send(request);

String fullMarkdown = '';

response.stream
    .transform(utf8.decoder)
    .transform(const LineSplitter())
    .listen(
      (line) {
        if (line.startsWith('data: ')) {
          final data = jsonDecode(line.substring(6));

          if (data.containsKey('content')) {
            // "chunk" event — append Markdown to the export
            fullMarkdown += data['content'];
          } else if (data.containsKey('message')) {
            // "progress" or "complete" event — show status to user
            print(data['message']);
          }
        }
      },
      onDone: () {
        print('Export complete! Markdown length: ${fullMarkdown.length}');
        client.close();
      },
    );
```

---

## 🔄 How to Test

```bash
# 1. Login to get a token
TOKEN=$(curl -s -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"your@email.com","password":"yourpassword"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['access_token'])")

# 2. Stream export via SSE (use -N to disable buffering)
curl -N http://localhost:8000/stream/export \
  -H "Authorization: Bearer $TOKEN"

# You'll see events arriving one by one:
#   event: progress
#   id: 0
#   data: {"step": "start", "message": "Preparing export...", "total_notes": 2}
#
#   event: chunk
#   id: 1
#   data: {"content": "# 📝 Notes Export\n**User:** ..."}
#
#   event: progress
#   id: progress-1
#   data: {"step": "exporting", "message": "Exporting note 1 of 2: My Note"}
#
#   event: chunk
#   id: chunk-1
#   data: {"content": "## 1. My Note\n\nDescription...\n\n---\n\n"}
#
#   event: complete
#   id: done
#   data: {"message": "Export finished!", "total_notes": 2}
```

> ⚠️ **Swagger UI will NOT stream!** Swagger buffers the entire response before displaying it, so all events appear at once. This is a Swagger limitation, not a bug. Use `curl -N` to see real-time streaming.

### Where does streaming actually work?

| Tool | Streams in real time? | Why? |
|------|----------------------|------|
| **Swagger UI** | ❌ No — shows all at once | Swagger waits for the full response before rendering |
| **`curl -N`** | ✅ Yes — events appear one-by-one | `-N` disables output buffering |
| **Flutter `http.Client().send()`** | ✅ Yes — `.listen()` fires per event | Dart's streamed response processes chunks as they arrive |
| **Browser (direct URL)** | ✅ Yes — text appears progressively | Browsers natively handle `text/event-stream` |

---

## 📁 New Files Created

| File | Purpose |
|------|---------|
| `services/stream_service.py` | Async SSE generator for streaming export + `format_sse_event()` helper |
| `routers/stream.py` | SSE endpoint: `GET /stream/export` |

## 📁 Files Modified

| File | Change |
|------|--------|
| `main.py` | Added `stream` router import + `include_router` |

---

## ✅ End of Day 07 — What Works

| Feature | Status |
|---------|--------|
| `GET /stream/export` returns SSE events | ✅ Works |
| Progress events arrive in real time | ✅ Works |
| Markdown chunks streamed one-by-one | ✅ Works |
| SSE format (`event:` + `id:` + `data:`) | ✅ Works |
| `progress` → `chunk` × N → `complete` flow | ✅ Works |
| Protected by JWT (same as all endpoints) | ✅ Works |
| No duplicate code (reuses same Markdown format as Day 06) | ✅ Clean |

---

## 📌 Concepts Introduced on Day 07

| Concept | Introduced in |
|---------|--------------|
| `StreamingResponse` | `routers/stream.py` |
| SSE (Server-Sent Events) | `routers/stream.py` |
| `text/event-stream` Content-Type | `routers/stream.py` |
| Async generators (`async def` + `yield`) | `services/stream_service.py` |
| `asyncio.sleep()` vs `time.sleep()` | `services/stream_service.py` |
| `X-Accel-Buffering: no` (Nginx SSE fix) | `routers/stream.py` |
| SSE event format (`event:`, `id:`, `data:`) | `services/stream_service.py` |
| SSE vs WebSocket comparison | Documentation |
