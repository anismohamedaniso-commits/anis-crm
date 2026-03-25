# Ollama FastAPI proxy for Anis CRM

This proxy forwards requests from the web app to a local Ollama server and supports an optional API key.

Quick start (Python):

1. Create a virtualenv and install deps:

```bash
cd server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

2. Create a `.env` file (optional):

```
API_KEY=your-secret-key
OLLAMA_URL=http://127.0.0.1:11434
PORT=3000
```

3. Run the server (development):

```bash
export OLLAMA_URL=http://127.0.0.1:11434
export API_KEY=yourkey   # optional
uvicorn main:app --host 127.0.0.1 --port 3000 --reload
```

4. Endpoints:
- `GET /api/ai/models` — list models
- `POST /api/ai/chat` — { model, messages, prompt, options }
- `POST /api/ai/embeddings` — { model, input }
- `GET /api/crm/summary` — returns a short CRM summary (dev-only)
- `POST /api/ai/assistant` — { model, message, stream=false } — assistant endpoint that includes CRM context and can request tool actions (create_lead, update_lead, add_note). If `stream=true` the model stream is proxied directly. **Note:** assistant will NOT auto‑execute tool requests. If the model returns a tool call the endpoint will return a JSON payload `{ "assistant": "...", "tool": { "tool": "name", "args": { ... } } }` so the client can request user confirmation.
- `POST /api/ai/tools/<tool_name>` — run a safe internal tool (requires API key). Tools: `create_lead`, `update_lead`, `add_note` — tool executions are recorded to `server/logs/audit.log` as newline-delimited JSON for auditing.

Security notes:
- Do NOT expose this proxy publicly without auth, rate-limits, and HTTPS.
- You can set `API_KEY` and call with `x-api-key` header for basic protection.

Assistant notes:
- The `/api/ai/assistant` endpoint injects a concise CRM summary into the model's system prompt to give the model context. The assistant may respond with a JSON `{"tool": "<name>", "args": {...}}` block to request a safe server-side action; the server will execute allowed tools and send the result back to the model to produce a final reply. This is a simple, auditable pattern for allowing the assistant to interact with the system.
- This is a development scaffold. For production you should implement: permissions, robust audit logs, rate limits, user scoping (so assistants only see data they are allowed to), and a vector store for large-context retrieval instead of injecting raw summaries.

Quick example (non-streaming assistant):

```bash
curl -sS -X POST http://127.0.0.1:3000/api/ai/assistant \
  -H 'Content-Type: application/json' \
  -H 'x-api-key: yourkey' \
  -d '{"model":"gemma3:4b", "message":"Create a lead for Foo Inc with contact foo@inc and owner Anis"}'
```

The assistant may reply with a JSON tool call that the server executes and then return a final message with next steps.



Docker (optional): create a simple image with Python and run `uvicorn`.

## ManyChat -> Google Sheets -> CRM (without Zapier)

If your Zapier subscription ended, you can still send leads into CRM through Google Sheets automation.

1. Configure API key for Google Sheets webhook:

```bash
export GOOGLE_SHEETS_API_KEY=your-secret-key
```

2. Send rows to this endpoint:

```text
POST /api/webhooks/google-sheets
Header: x-api-key: your-secret-key
```

3. Supported payloads:

- single row object
- array of row objects
- `{ "row": { ... } }`
- `{ "rows": [ ... ] }`
- `{ "values": { ... } }`

Common fields:

- `name` or `full_name` or `first_name` + `last_name`
- `email`
- `phone` / `phone_number` / `mobile`
- `campaign`
- `country`
- `deal_value`
- `notes`

4. Optional migration shortcut:

- If `GOOGLE_SHEETS_API_KEY` is not set, the endpoint accepts `ZAPIER_API_KEY` as fallback.
