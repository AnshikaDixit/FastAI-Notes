# routers/stream.py
# Routes for streaming the note export via SSE — the real-time counterpart to /export/notes.
from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from database import get_db
from services.auth_service import get_current_user
from services.stream_service import stream_export_sse
from models.user_orm import UserORM

router = APIRouter(
    prefix="/stream",
    tags=["Streaming (SSE)"]   # groups them nicely in /docs
)


@router.get("/export")
def stream_export(
    db: Session = Depends(get_db),
    current_user: UserORM = Depends(get_current_user),
):
    """Stream the note export as SSE events — watch it happen in real time.

    This is the STREAMING version of POST /export/notes (Day 06):
        - POST /export/notes → Fire-and-forget. Returns 202 instantly, writes file in background.
        - GET /stream/export → Streams the Markdown export live via SSE. Client watches progress.

    What is StreamingResponse?
        Normally, FastAPI builds the ENTIRE response body in memory, then sends it.
        StreamingResponse is different — it takes a generator function and sends
        data chunk-by-chunk as it's produced. The client sees data appearing
        progressively instead of waiting for everything at once.

    What is SSE (Server-Sent Events)?
        SSE is a standard protocol (part of HTML5) for pushing events from
        server to client over a single HTTP connection. It's built on top of
        regular HTTP — no WebSocket upgrade needed.

    The SSE Protocol:
        1. Client connects with GET request.
        2. Server responds with Content-Type: text/event-stream.
        3. Server sends events in this format:
            event: progress
            id: 1
            data: {"message": "Exporting note 1 of 5...", "current": 1}

            (blank line = end of event)
        4. Connection stays open — server pushes more events over time.
        5. Client receives events and processes them.

    Event types in this endpoint:
        - "progress" → status updates ("Preparing...", "Exporting note 2 of 5...")
        - "chunk"    → actual Markdown content (header, individual notes)
        - "complete" → export finished, all notes delivered

    Client-side Flutter/Dart (how the app would consume this):
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

    SSE vs WebSocket:
        | Feature        | SSE                          | WebSocket                    |
        |----------------|------------------------------|------------------------------|
        | Direction      | Server → Client (one-way)    | Server ↔ Client (two-way)    |
        | Protocol       | HTTP (no upgrade)            | Needs WS upgrade handshake   |
        | Reconnection   | Built-in (auto-reconnect)    | Manual implementation        |
        | Data format    | Text only                    | Text or binary               |
        | Best for       | Feeds, dashboards, progress  | Chat, games, real-time collab|

    curl testing:
        curl -N http://localhost:8000/stream/export -H "Authorization: Bearer <token>"
        # -N flag disables output buffering so you see events in real time
    """
    return StreamingResponse(
        content=stream_export_sse(db, current_user.id, current_user.email),
        # content: The async generator whose yielded values become HTTP chunks.
        # Each yield sends one SSE event to the client immediately.
        media_type="text/event-stream",
        # text/event-stream: This Content-Type is MANDATORY for SSE.
        # It tells the client "this is an event stream, keep the connection
        # open and parse incoming data as SSE events."
        headers={
            "Cache-Control": "no-cache",
            # no-cache: Critical for SSE — proxies must NOT buffer the stream.
            # Without this, some proxies wait for the full response
            # before processing, which defeats the purpose of streaming.
            "Connection": "keep-alive",
            # keep-alive: Tells the client to keep the TCP connection open.
            # This is the default in HTTP/1.1 but we set it explicitly for clarity.
            "X-Accel-Buffering": "no",
            # X-Accel-Buffering: Disables Nginx's response buffering.
            # Without this, Nginx waits for the entire response before forwarding,
            # which kills SSE. This header tells Nginx to pass chunks immediately.
            # (This is specific to Nginx — which we use in our Docker setup!)
        }
    )
