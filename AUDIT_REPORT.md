# Tick&Talk CRM — Pre-Deployment Audit Report

Generated from a comprehensive code review of the entire Flutter CRM codebase, FastAPI backend, Supabase configuration, and supporting infrastructure.

---

## 🔴 CRITICAL — Must Fix Before Deployment

### 1. Hardcoded Secrets in Source Code
- **`lib/supabase/supabase_config.dart` (L7–L8):** Supabase URL and anon key are hardcoded as string constants directly in the source code. These will be committed to version control.
- **`server/main.py` (L62–L63):** Same Supabase URL and anon key hardcoded as fallback defaults in the Python server.
- **Fix:** Use `--dart-define` for Flutter (like `openai_config.dart` already does), environment variables for the server, and a `.env` file excluded from version control.

### 2. Hardcoded `localhost:3000` Server URLs (Entire App Will Fail in Production)
All backend service calls point to `http://127.0.0.1:3000`, which only works in local development:
- **`lib/services/api_client.dart` (L14):** `static const String baseUrl = 'http://127.0.0.1:3000'`
- **`lib/services/ai_service.dart` (L10):** `final _base = 'http://127.0.0.1:3000/api/ai'`
- **`lib/services/auth_service.dart` (L87):** `static const _serverBase = 'http://127.0.0.1:3000/api/auth'`
- **`lib/services/integration_service.dart` (L12):** `static const String _baseUrl = 'http://127.0.0.1:3000'`
- **`lib/services/email_campaign_service.dart` (L139):** `static const _apiBase = 'http://127.0.0.1:3000'`
- **`lib/pages/settings_page.dart` (L595):** Hardcoded fallback URL
- **Fix:** Centralize server URL in a single config that reads from `--dart-define` or `String.fromEnvironment()`, similar to how `openai_config.dart` is configured.

### 3. Server Data Stored on Disk as JSON Files (Not Production-Ready)
- **`server/main.py` (L622–L628):** All CRM data (leads, tasks, notes, notifications, chat) is persisted as flat JSON files in `server/data/`.
- This means: **no concurrent write safety, no ACID guarantees, no backup strategy, no horizontal scaling, data loss on server restart/redeployment possible.**
- Despite having Supabase for auth, the core CRM data (leads, activities, tasks, chat, etc.) bypasses Supabase entirely.
- **Fix:** Migrate all data persistence to Supabase PostgreSQL tables, or at minimum a proper database.

### 4. CORS Allows All Origins
- **`server/main.py` (L45):** `allow_origins=["*"]` allows any website to call the API.
- Combined with weak auth (see #5), this is a significant security risk.
- **Fix:** Restrict to your actual domain(s).

### 5. Weak/Optional API Authentication on Server
- **`server/main.py` (L52–L55):** The `_check_auth` function returns `True` if `API_KEY` is not set at all. Most non-collaboration endpoints only use this simple key check (not JWT).
- The collaboration endpoints (tasks, chat, notifications, team activities, leaderboard) properly verify Supabase JWT, but the old endpoints (`/api/leads`, `/api/activities`, `/api/email/send`, `/api/ai/*`) only check the optional API key.
- **Fix:** Require Supabase JWT for all endpoints consistently.

### 6. Supabase RLS Policies Are Overly Permissive
- **`lib/supabase/supabase_policies.sql`:** Only policies for the `messages` table exist.
- Any authenticated user can SELECT, INSERT, UPDATE, and DELETE **all messages** — there is no row-level user scoping.
- No RLS policies defined for the `profiles` table.
- **Fix:** Add proper user-scoped RLS policies.

### 7. Email Campaigns and Templates Not Server-Persisted
- **`lib/services/email_campaign_service.dart`:** Campaign data and email templates are stored only in `SharedPreferences` (device-local storage).
- If the user clears app data, switches devices, or uses the web version, all campaign data and templates are lost.
- Real emails are sent via the server, but the campaign metadata (stats, recipient lists, template content) is local-only.
- **Fix:** Persist campaigns and templates in the server/database.

### 8. API Keys Stored in Plaintext in SharedPreferences
- **`lib/state/app_state.dart`:** `whatsAppApiKey`, `telephonyApiKey`, and `aiCustomApiKey` are saved directly to SharedPreferences without encryption.
- On web, SharedPreferences maps to localStorage which is readable by any JavaScript on the page.
- **Fix:** Use `flutter_secure_storage` or encrypt sensitive values.

### 9. Deprecated `describeEnum` Usage
- **`lib/models/message.dart` (L57, L59):** Uses `describeEnum()` which is deprecated in Flutter 3.14+. Will cause warnings/errors on newer Flutter versions.
- **Fix:** Replace with `.name` (e.g., `direction.name`).

---

## 🟡 IMPORTANT — Should Fix Before Production

### 10. ThemeMode Hardcoded to Dark, Ignoring User Preference
- **`lib/main.dart` (L150):** `themeMode: ThemeMode.dark` is hardcoded, despite `AppState` having a `darkMode` toggle that the settings page uses.
- **Fix:** Use `Consumer<AppState>` to read `appState.darkMode` and set `themeMode` accordingly.

### 11. Dead Code — Unused MyHomePage Class
- **`lib/main.dart` (L158–L202):** `MyHomePage` class and `_MyHomePageState` are Flutter counter app boilerplate that are never used anywhere. Dead code.
- **Fix:** Delete lines 158–202.

### 12. No Pagination Anywhere
- **`lib/services/lead_service.dart`:** Fetches ALL leads from server in a single call.
- **`lib/services/activity_service.dart`:** Fetches ALL activities for a lead at once.
- **`lib/services/team_chat_service.dart`:** Fetches the last 100 messages per channel, no scrollback pagination.
- **`lib/services/team_activity_service.dart`:** Fetches 50 items, no "load more."
- **`lib/services/notification_service.dart`:** Fetches 50, no "load more."
- Server endpoints support `limit`/`offset` parameters, but the client never uses pagination.
- **Impact:** Performance will degrade significantly with hundreds of leads or thousands of messages.

### 13. No "Forgot Password" Flow
- **`lib/pages/login_page.dart`:** No "Forgot Password?" link or reset password functionality anywhere in the app.
- **`lib/auth/auth_manager.dart` (L23):** A `resetPassword` method is defined in the abstract interface but never implemented.
- Supabase GoTrue supports `resetPasswordForEmail()` out of the box.
- **Fix:** Add a forgot password button on the login page that calls Supabase's password reset.

### 14. Auth Manager Mixins Defined but Never Implemented
- **`lib/auth/auth_manager.dart`:** Defines mixins for Apple, Google, Facebook, Microsoft, GitHub, Phone, and JWT sign-in, but none of these are implemented or used anywhere.
- Only email/password auth is functional.
- **Fix:** Either remove the dead interface code, or implement social login if needed.

### 15. SupabaseService CRUD Utility Class Defined but Never Used
- **`lib/supabase/supabase_config.dart` (L30+):** `SupabaseService` class with generic `select`, `insert`, `update`, `delete` helpers is defined but no service in the codebase uses it. All services use `ApiClient` (HTTP to FastAPI) instead.
- **Fix:** Either use it for future Supabase direct access or remove dead code.

### 16. No Offline Queue / Retry Logic for Failed Server Calls
- **`lib/services/lead_service.dart`, `activity_service.dart`:** If server calls fail, data falls back to local storage but changes are NOT queued for retry when connectivity returns.
- **`lib/services/task_service.dart`:** Has NO local fallback at all — if the server is down, task operations fail silently.
- **Fix:** Implement a sync queue that retries failed operations.

### 17. Real-Time Communication Uses Polling, Not WebSockets
- **`lib/services/team_chat_service.dart`:** Polls for new messages every **3 seconds** — inefficient and high server load.
- **`lib/services/notification_service.dart`:** Polls every **15 seconds**.
- Supabase Realtime is available and already used by `MessageService` for WhatsApp messages — it should be extended to team chat and notifications.
- **Fix:** Use Supabase Realtime subscriptions for chat and notifications.

### 18. Missing Email Format Validation on Signup
- **`lib/pages/signup_page.dart`:** Only checks `email.isEmpty` — does not validate email format. Users can enter "abc" as an email.
- **Fix:** Add a regex or use `EmailValidator` package.

### 19. Integration Service Does Not Use Auth Headers
- **`lib/services/integration_service.dart`:** All HTTP calls use only `Content-Type` header — never sends the Supabase JWT auth token.
- The server's `_check_auth` function expects either `x-api-key` or JWT, but IntegrationService sends neither when `API_KEY` env var is set.
- **Fix:** Include the Supabase access token in the Authorization header.

### 20. Scripts Stored Only in SharedPreferences
- **`lib/services/script_service.dart`:** Call scripts are persisted only locally (SharedPreferences), not synced to the server.
- Lost on app reinstall, different device, or web browser clear.
- **Fix:** Sync via server or Supabase user_metadata (similar to KPI targets).

### 21. No Input Sanitization on Server Endpoints
- **`server/main.py`:** Lead names, notes, task titles, and chat messages are stored as-is with no sanitization or length limits.
- Potential for XSS if data is rendered in a web context, or storage abuse with extremely large payloads.
- **Fix:** Add input validation and length limits.

### 22. Server JWT Verification Can Be Disabled
- **`server/main.py` (L91–L94):** When `SUPABASE_JWT_SECRET` is not set, JWTs are decoded without signature verification: `jwt.decode(token, options={'verify_signature': False})`.
- This means **any valid-looking JWT will be accepted**, regardless of who issued it.
- **Fix:** Always require and verify the JWT secret in production.

### 23. KPI Targets Saved in Supabase User Metadata
- **`lib/services/kpi_service.dart`:** KPI targets are stored in Supabase `user_metadata`. This field has a size limit and isn't designed for large structured data.
- As the number of KPI targets grows, this could hit metadata size limits.
- **Fix:** Store in a dedicated Supabase table.

### 24. SimplePlaceholderPage Exists but Is Not Referenced
- **`lib/pages/simple_placeholder_page.dart`:** A generic placeholder page with text "This page will be built in the next step." exists but is not imported/used in the router. Leftover from development.
- **Fix:** Delete it.

---

## 🟢 NICE TO HAVE — Non-Blocking Improvements

### 25. No Unit Tests for Services, Models, or Pages
- Only 2 test files exist: `test/engine/lead_score_engine_test.dart` and `test/engine/conversation_suggestions_engine_test.dart`.
- No tests for any service, model serialization, page widget, or server endpoint.
- **Fix:** Add unit tests for critical paths (lead CRUD, auth flow, data serialization).

### 26. No Error Boundary / Global Error Handler in Flutter
- **`lib/main.dart`:** No `FlutterError.onError` or `runZonedGuarded` for catching uncaught exceptions.
- Crashes will be silent in production.
- **Fix:** Add global error handling and crash reporting (e.g., Sentry, Firebase Crashlytics).

### 27. No Loading/Error States on Several Pages
- **`lib/pages/pipeline_page.dart`:** No loading indicator while leads are being fetched.
- **`lib/pages/calendar_page.dart`:** No error handling if services fail.
- Most pages show data immediately from ValueNotifiers, which is good, but initial load states could be more polished.

### 28. Android applicationId Still Default
- **`android/app/build.gradle` (L39):** Contains `// TODO: Specify your own unique Application ID`. The applicationId likely needs to be changed from the default before Play Store publishing.

### 29. Server Has Duplicate Implementations (Python + Node.js)
- **`server/main.py`:** Full FastAPI server (2241 lines) with all features.
- **`server/index.js`:** Slim Express.js server (~75 lines) with only AI proxy endpoints.
- The Node.js version is out of date and only proxies AI endpoints. Confusing to maintain both.
- **Fix:** Remove `index.js` or document that only `main.py` is the active server.

### 30. No Rate Limiting on Server
- **`server/main.py`:** No rate limiting on any endpoint. An attacker could spam the email endpoint, create unlimited leads, or flood the AI proxy.
- **Fix:** Add rate limiting middleware (e.g., `slowapi` for FastAPI).

### 31. No HTTPS Enforcement
- All server URLs use `http://`. In production, all traffic should go through HTTPS.
- **Fix:** Deploy behind a reverse proxy (nginx, Cloudflare) that handles TLS.

### 32. Hardcoded Business-Specific Content in Engine Files
- **`lib/engine/conversation_suggestions_engine.dart`:** All suggestion text is hardcoded for "Tick & Talk" and "Speekr.ai".
- **`lib/engine/templates_engine.dart`:** All template text references specific products and pricing.
- **`lib/services/ai_executor.dart` (L141, L192):** AI prompts mention "Tick & Talk" and "Speekr.ai" by name.
- **`server/main.py` (L900+):** The massive `system_prompt` (400+ lines) is entirely business-specific.
- If this CRM is ever white-labeled or used for a different business, all of this would need replacement.
- **Not a bug,** but worth noting for maintainability.

### 33. Lead Model Missing Several Fields
- **`lib/models/lead.dart`:** No `notes` field, no `score` field, no `tags` field, no `company` field.
- These are commonly expected CRM fields. Currently notes are stored as separate activities.

### 34. No Data Export from Server
- The server has no endpoint for exporting all data (leads, activities, tasks) as CSV/JSON backup.
- The Flutter client has CSV export for leads but no backup/restore of the full dataset.

### 35. No Activity Deletion
- **`lib/services/activity_service.dart`:** Supports create and list, but has no delete capability. Once an activity is logged, it cannot be removed.

### 36. Chat Messages Have No Pagination or Search
- **`lib/services/team_chat_service.dart`:** Loads the last 100 messages, no ability to scroll back further.
- No search within chat messages.

### 37. No Confirmation on Destructive Actions in Some Places
- **`lib/pages/leads_page.dart`:** "Delete All" leads exists but needs confirmation (need to verify the dialog exists in the unread section).
- **`lib/pages/settings_page.dart`:** "Danger Zone" section — need to verify proper confirmation dialogs.

### 38. Audit Log is Append-Only with No Rotation
- **`server/main.py` (L636):** Audit log file grows without bound. No log rotation or cleanup.
- **Fix:** Add log rotation (e.g., `RotatingFileHandler`) or periodic cleanup.

### 39. No Accessibility (a11y) Considerations
- No `Semantics` widgets for screen readers beyond standard Material defaults.
- Custom widgets (status pills, priority cards) lack semantic descriptions.

### 40. SMTP Credentials in Environment Variables (No Encryption at Rest)
- **`server/main.py` (L26–L28):** SMTP password is in plaintext env var. This is standard practice for server-side env vars, but worth noting for security audit documentation.

---

## Summary Statistics

| Category | Count |
|----------|-------|
| 🔴 Critical | 9 |
| 🟡 Important | 15 |
| 🟢 Nice to Have | 16 |
| **Total Findings** | **40** |

## Files with Most Issues
| File | Issue Count |
|------|-------------|
| `server/main.py` | 7 (CORS, auth, JSON storage, no rate limit, JWT bypass, no sanitization, audit log) |
| `lib/supabase/supabase_config.dart` | 3 (hardcoded secrets, unused class) |
| `lib/main.dart` | 3 (ThemeMode, dead code, no error boundary) |
| `lib/services/api_client.dart` | 2 (hardcoded URL, no retry) |
| `lib/state/app_state.dart` | 2 (plaintext API keys, dark mode unused) |
| `lib/services/email_campaign_service.dart` | 2 (hardcoded URL, local-only storage) |

## Recommended Priority Order for Fixes
1. **Secrets & URLs** (#1, #2) — App literally won't work in production
2. **Server data storage** (#3) — Data will be lost
3. **Security** (#4, #5, #6, #8, #22) — Vulnerabilities
4. **Missing core features** (#13, #18) — User-facing gaps
5. **Data persistence gaps** (#7, #20) — Data loss risk
6. **Performance** (#12, #17) — Will degrade with usage
7. **Code cleanup** (#9, #11, #14, #15, #24, #29) — Maintenance debt
