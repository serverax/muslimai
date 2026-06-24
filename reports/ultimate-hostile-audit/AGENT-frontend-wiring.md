# AGENT — Frontend Wiring Audit (SakinaAL Flutter)

Auditor mode: hostile / guilty-until-proven-wired. Static analysis only (flutter CLI not installed).
Scope: `sakina-frontend/lib`. Scans saved:
- `reports/ultimate-hostile-audit/030-frontend-api-calls.txt` (80 lines)
- `reports/ultimate-hostile-audit/041-frontend-json-models.txt` (264 lines)

Build / analyze / runtime: **UNPROVEN** (no `flutter` toolchain in environment; could not compile, run, or hit a live backend).

---

## 1. Base URL finding

| File:line | Value | Verdict |
|---|---|---|
| `sakina-frontend/lib/config/api_config.dart:2-5` | `String.fromEnvironment('SAKINA_API_BASE_URL', defaultValue: 'https://api.7jzi.com/v1')` | **CONFIG-DRIVEN (build-time `--dart-define`)**. Default is a public HTTPS host, **NOT** localhost/10.0.2.2/127.0.0.1. Safe on a real device. |
| `sakina-frontend/lib/config/staging_client_config.dart:3-6` | `String.fromEnvironment('SAKINA_API_BASE_URL', defaultValue: 'https://api.sakina-mobile-staging.example')` | Config-driven; placeholder `.example` default. `StagingClientConfig` appears **unused** by runtime screens (no references found outside the file) — dead/secondary config. |

No hardcoded localhost/loopback found anywhere in `lib`. Base URL is reused by `ApiService` (`api_service.dart:10`), `ModuleApiClient` (`module_service.dart:303`), `AuthService` (`auth_service.dart:23`) — all default to `ApiConfig.baseUrl`. **PASS.**

Note (`api_service.dart:866-871`, `module_service.dart:367-370`): `_endpoint`/`_endpointBase` append `/v1` only if `baseUrl` does not already end in `/v1`. The default already ends in `/v1`, so paths resolve to `https://api.7jzi.com/v1/...`. Consistent.

---

## 2. Screen matrix

Navigation chain: `main.dart:62-66` → WelcomeScreen → (Get Started) OnboardingScreen → AccountIntroScreen → HomeShellScreen. HomeShell is an 8-tab `NavigationBar` (`home_shell_screen.dart:39-108`).

| Screen (file) | Reachable? | Service method (file:line) | Backend route | Shows real data? | Status |
|---|---|---|---|---|---|
| `welcome_screen.dart` | YES (`main.dart:65`) | none (static hero + nav) | — | static intro | WIRED (intent: nav only) |
| `onboarding_screen.dart` | YES (`welcome_screen.dart:92`) | none (local consent UI) | — | local only | WIRED (nav only) |
| `account_intro_screen.dart` | YES (`main.dart:63`, `welcome:122`) | `AuthService.login/register` → `api_service.dart:48,25` | `/auth/login`, `/auth/register` (`phase2.rs:785`) | YES (real auth, persists tokens) | WIRED |
| `home_shell_screen.dart` | YES (`account_intro:60,141`) | hosts `ModuleService` (`:30`) | — | shell | WIRED |
| `chat_screen.dart` | YES — tab 0 (`home_shell:40`) | `api.askSakina` (`chat_screen.dart:114` → `api_service.dart:101-121`) | `POST /api/sakina/ask` (`main.rs:692`) | YES — posts real msg, parses real `answer`+`citations` | **WIRED** (caveats hidden — see §4) |
| Quran tab (`ModuleReadOnlyStateScreen` via `home_shell:41`) | YES — tab 1 | `ModuleService.quran` → `module_service.dart:455-478` → `/modules/quran/overview` (`module_service.dart:312`) | `/modules/quran/overview` | Gated: defaults to FAKE state text (see note) | **PARTIAL** |
| Prayer tab (`home_shell:45`) | YES — tab 2 | `ModuleService.prayer` (`module_service.dart:480`) | `/modules/prayer/overview` | Gated | **PARTIAL** |
| Community tab (`home_shell:49`) | YES — tab 3 | `ModuleService.community` (`module_service.dart:531`) | `/modules/community/overview` | Gated | **PARTIAL** |
| `islamic_library_screen.dart` | YES — tab 4 (labeled "knowledge"!) (`home_shell:53`) | `getIslamicSources/Documents/searchIslamic/askIslamic` (`api_service.dart:347,371,407,433`) | `/islamic/sources`,`/documents`,`/search`,`/ask` | YES — real fetch + ask + citation badges | **WIRED** |
| `iman_journey_screen.dart` | YES — tab 5 (`home_shell:54`) | `getImanJourney/addDuaItem/updateImanJourneyPrivacy` (`api_service.dart:668,749,720`) | `/iman-journey/{id}` (`iman_journey.rs:17`) | YES — real load/save | **WIRED** |
| `multimodal_analysis_screen.dart` | YES — tab 6 (`home_shell:55`) | `analyzeMultimodal` (`api_service.dart:811`) | `POST /api/multimodal/analyze` (`main.rs:779`) | YES — real multipart upload | **WIRED** |
| `compliance_screen.dart` | YES — tab 7 (`home_shell:56`) | `requestDataExport/requestAccountDeletion` (`api_service.dart:337,327`) | `/account/export-request`,`/account/delete-request` | Static policy text + 2 real buttons | **WIRED** (text static; actions wired) |
| `knowledge_module_screen.dart` | **NO** | wraps `moduleService.knowledge` | `/modules/knowledge/overview` | n/a | **UNREACHABLE / dead code** (not referenced; the "knowledge" nav tab routes to IslamicLibraryScreen instead) |
| `prayer_module_screen.dart` | **NO** | wraps `moduleService.prayer` | — | n/a | **UNREACHABLE / dead** (HomeShell builds `ModuleReadOnlyStateScreen` inline instead) |
| `quran_module_screen.dart` | **NO** | wraps `moduleService.quran` | — | n/a | **UNREACHABLE / dead** |
| `community_module_screen.dart` | **NO** | wraps `moduleService.community` | — | n/a | **UNREACHABLE / dead** |

### Module-tab PARTIAL / FAKE note (important)
`feature_flags.dart:4-11`: `quran/prayer/community/knowledge` all default to **`false`** (`bool.fromEnvironment(..., defaultValue: false)`). `module_service.dart:456-462,481,532` short-circuit to `ModuleAccessState.featureDisabled` **before any network call** when the flag is off. So in a default build, the Quran/Prayer/Community tabs render the static string **"feature unavailable in this release"** / "is disabled by feature flag" (`module_read_only_state_screen.dart:55-56`) and **never hit the backend**. They only become live with `--dart-define=SAKINA_FEATURE_*=true` AND a premium tier (`module_service.dart:463-468`, `SAKINA_SUBSCRIPTION_TIER` default `free`). This is feature-gated, not hardcoded fake content, but in a default build it is effectively non-functional.

### Nav label/screen mismatch (bug)
`home_shell_screen.dart:88-92` — tab index 4 has label `app.t('knowledge')` + school icon, but `screens[4]` is `IslamicLibraryScreen()` (`:53`), not the knowledge module. The true Knowledge module screen is the unreachable dead code above. Mislabeled tab.

---

## 3. Contract mismatches (frontend vs backend, snake_case serde)

Backend `SakinaAskResponse` (`sakina-backend/src/models/mod.rs:417-433`) vs frontend `SakinaAskResponse.fromJson` (`api_service.dart:1095-1119`):

| Field | Backend (mod.rs) | Frontend (api_service.dart) | Verdict |
|---|---|---|---|
| `answer`,`language`,`intent`,`trace_id`,`safety_state` | sent | parsed (`:1097-1101`) | OK |
| `source_path` (struct) | sent (`:424`) | parsed as `Map` (`:1102`) | OK |
| `safety` (struct: `pii_removed`,`guardrails_passed`,`crisis_detected`,`out_of_scope_blocked`) | sent (`mod.rs:409-415,425`) | parsed as `Map` (`:1105-1107`) then **NOT displayed** | **Parsed but dropped — see §4** |
| `citations` (`serde_json::Value`) | sent (`:426`) | parsed via `Citation.fromJson` (`:1108-1111`) | OK |
| `graph_path` | `Vec<String>` (`:427`) | `List<dynamic>` (`:1112`) | OK |
| `local_db_context` | sent (`:428`) | **NOT parsed by frontend** (frontend only reads `rag_context`, `:1113`) | Backend field IGNORED (low impact) |
| `rag_context`,`graph_context` | sent (`:429-430`) | only `rag_context` parsed (`:1113`); `graph_context` ignored | `graph_context` IGNORED (low impact) |
| `model_provider`,`llm_model` | sent (`:431-432`) | parsed (`:1116-1117`) | OK |

**Citation contract** — backend `Citation` (`mod.rs:30-34`): `id,title,author,chapter,authenticity_grade` all **required `String`** (always present). Frontend `Citation.fromJson` (`api_service.dart:1289-1295`) treats `chapter`/`authenticity_grade` as **nullable** (`as String?`). Frontend is stricter-safe; no break. Frontend `isVerifiedShape` (`:1297-1301`) requires non-empty chapter+grade — matches backend always-populated contract.

No field the frontend *requires* is missing from the backend. The only mismatches are backend-sent fields the frontend silently ignores (`local_db_context`, `graph_context`) — non-breaking.

`BrainChatResponse.fromJson` (`api_service.dart:1193-1229`) maps backend `CoreChatResponse` (`mod.rs:368-389`) — shapes align (snake_case). It is reachable only via `sendBrainChat` (`:123`), which is **not called by any screen** (dead path; the live `/api/sakina/ask` is used directly).

---

## 4. Are citations & safety caveats rendered, or hidden?

### Citations — RENDERED (varies by screen)
- **Islamic Library** (`islamic_library_screen.dart:246-256`): renders `CitationBadge` widget (`citation_widget.dart:7-51`) — tappable, opens dialog with title/author/chapter/grade (`:53-76`). Plus a fallback banner (`:226-237`) and fatwa-sensitive caveat (`:238-245`). **Best citation+caveat surfacing in the app.**
- **Chat** (`chat_screen.dart:305-312`): renders citations as **plain `Text` lines** (`'- title | chapter | grade'`), NOT the `CitationBadge` widget. Only `isVerifiedShape` citations shown; malformed ones discarded with a warning banner (`:228-235`). Functional but downgraded UI vs library.
- **Multimodal** (`multimodal_analysis_screen.dart:182-192`): citations rendered as plain `Text`.
- **Iman Journey** (`iman_journey_screen.dart:244-258`): renders `religiousReminder.evidenceBundle` + safe-fallback message (`:259-264`). Good.

### Safety caveats — HIDDEN on the main Ask-AI/chat screen (FINDING)
The backend emits structured safety signals in `SakinaAskResponse.safety` (`crisis_detected`, `out_of_scope_blocked`, `guardrails_passed`) and `safety_state` enum values: `ALLOWED_WITH_GUARDRAILS`, `CAVEATED_SHORT_CIRCUIT`, `CRISIS_ESCALATION`, `ESCALATED_TO_HUMAN`, `SCHOLAR_REVIEW...` (`sakina_ask.rs:384,425,447,457,464`).

In `chat_screen.dart:128-138`, after `askSakina` the screen sets `_status` to only:
`'Trace {traceId} | {source_path.answer_source} | {modelProvider}'` (`:137`).
It **does NOT read `response.safetyState` or `response.safety`** to render a crisis/escalation/caveat banner. The `safety` map is parsed (`api_service.dart:1105-1107`) and then ignored by the UI. The crisis/escalation guidance is only present **inside the `answer` string** the backend bakes in (`sakina_ask.rs:426-464`); there is no distinct, visible safety/caveat UI element on the primary chat flow.
- Verdict: **Safety caveats are NOT surfaced as structured UI on the chat screen** (hidden). The Islamic Library screen DOES surface fatwa-sensitive + fallback caveats; the chat screen does not. Inconsistent and a hardening gap for the highest-traffic flow.

---

## 5. Fake / local / demo responses

- **No client-side fabricated AI answers found.** The chat screen always calls the live backend (`chat_screen.dart:114`); on failure it shows an error system message (`:139-143`), it does NOT invent an answer. `ChatController.send` (`chat_controller.dart:228-245`) likewise only stores the real backend answer or marks the message pending on error. **PASS — no fake answers.**
- Local data that exists is legitimately local: chat history persistence via SQLCipher local DB (`chat_controller.dart:123-160`, key `SAKINA_DB_KEY` default `'sakina-local-db-key'` — weak default key, security note).
- **Module tabs render static "feature unavailable" strings by default** because all feature flags default `false` (`feature_flags.dart`) — see §2. Not fabricated content, but a default build shows no real module data.
- `compliance_screen.dart:93-117` policy/terms text is **static hardcoded copy** (acceptable for legal text); the export/delete buttons are wired to real endpoints.
- `StagingClientConfig` (`config/staging_client_config.dart`) and `BrainChatResponse.fromJson` path are **dead code** (unreferenced by screens).

---

## 6. Error handling & loading states

| Flow | Loading | Error | Verdict |
|---|---|---|---|
| Chat ask (`chat_screen.dart:101-148`) | `_sending` disables FAB (`:345`) | try/catch → system msg via `_humanizeError` (401/402/403/feature_disabled mapped, `:193-211`) | GOOD |
| Module tabs (`module_read_only_state_screen.dart:19-52`) | `CircularProgressIndicator` until done | FormatException / 401/403/402/feature_disabled state text | GOOD |
| Iman Journey (`iman_journey_screen.dart:38-110`) | `_loading` spinner (`:117-122`) + Retry button (`:132-135`) | error text + retry | GOOD |
| Islamic Library (`islamic_library_screen.dart:33-93`) | `_loading` spinner (`:264`) | red error text (`:200-206`) | GOOD |
| Multimodal (`multimodal_analysis_screen.dart:86-130`) | `LinearProgressIndicator` (`:165`) | `_humanize` maps 401/413/415/422/429/500 (`:118-130`) | GOOD |
| Compliance (`compliance_screen.dart:22-86`) | per-button busy flags | requires session else inline error; try/catch | GOOD |
| Auth (`account_intro_screen.dart:32-72`) | `_submitting` spinner in button | `_errorText` shown | GOOD |
| Network layer (`api_service.dart:873-925`) | — | `_withRetry`/`_withStreamRetry` 3 attempts, retries on 5xx; structured `ApiException` with code/message (`:996-1015`) | GOOD |

No silent-failure flows found. Error handling is consistent and reasonably specific.

---

## Summary of defects (priority)

1. **MEDIUM — Safety caveats hidden on chat screen.** Backend `safety`/`safety_state` (crisis/escalation/caveat) parsed but never rendered as structured UI on the primary Ask-AI flow (`chat_screen.dart:128-138`). Library screen does surface fatwa/fallback caveats; chat does not. Hardening gap.
2. **LOW/MEDIUM — Default build = dead module tabs.** Quran/Prayer/Community feature flags default `false` (`feature_flags.dart:4-11`) → tabs show static "feature unavailable" and never call the backend unless `--dart-define`+premium tier set.
3. **LOW — Nav label mismatch.** Tab 4 labeled "knowledge" but renders `IslamicLibraryScreen` (`home_shell_screen.dart:88-92` vs `:53`).
4. **LOW — Dead code.** `knowledge/prayer/quran/community_module_screen.dart` unreachable; `StagingClientConfig`, `BrainChatResponse.fromJson`, `sendBrainChat` unreferenced.
5. **LOW — Ignored backend fields.** `local_db_context`, `graph_context` from `/api/sakina/ask` are dropped by frontend (non-breaking).
6. **LOW (security) — Weak default local DB key** `'sakina-local-db-key'` (`chat_controller.dart:133-136`) when `SAKINA_DB_KEY` not defined.
7. **NOTE — chat feedback/report always disabled.** `_lastMessageId` is set to `null` immediately after every ask (`chat_screen.dart:122`), so the Feedback/Report buttons are permanently disabled (`_sendFeedbackUpDownDisabled`, `:365`); wired but never usable.

Build/analyze: **UNPROVEN** (no flutter toolchain). Live backend contract: **UNPROVEN** (static comparison against Rust structs only; no runtime response captured).
