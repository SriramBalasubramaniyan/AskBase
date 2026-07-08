# AskBase

**Natural language query interface over any structured SQLite database, powered by an on-device SLM.**

---

## What it does

AskBase lets you ask plain-language questions about a SQLite database and get clear, summarized answers.

```
User:    Which farmer harvested the most in 2024?
AskBase: Ravi Kumar had the highest harvest in 2024,
         collecting 1,842 kg of Paddy (IR64, Grade-A)
         from his North Field farm in January.
```

Under the hood:
1. The schema you define tells the model what tables and columns exist
2. **SchemaSelector** picks only the relevant tables using keyword scoring
3. The model generates a SQLite SELECT query using only those tables
4. The query runs against the local database (with a case-insensitivity safety net — see below)
5. The model summarizes the results in plain language

---

## Architecture

```
User Question
     │
     ▼
SchemaSelector.select()           ← word-boundary keyword scoring against 50-table
     │                               schema, with generic-token dampening;
     │                               returns ~1-5 relevant tables + FK deps
     ▼
LlmService.generateSql()          ← compact schema injected (selected tables only)
     │
     ▼
SQL query (validated, SELECT only)
     │
     ▼
DbService.runSelect()             ← sqflite, read-only enforcement via validation,
     │                               text comparisons rewritten to COLLATE NOCASE
     ▼
JSON rows (capped at 50)
     │
     ▼
LlmService.summarizeResults()     ← streaming tokens, appended incrementally
     │
     ▼
Natural language answer
```

### Semantic schema selection

The full 50-table schema is too large to fit in the model's 1280-token context window. `SchemaSelector` solves this by scoring each table against the user's question using:

- **Table name match** (weight: 10, whole-word) — the question mentions the table itself
- **Table description match** (weight: 3, whole-word)
- **Field name match** (weight: 5, whole-word) — the question mentions a specific column
- **Field description match** (weight: 2, whole-word)
- **Basic singular/plural stemming** — "farmers" also matches "farmer", "loans" also matches "loan", etc.
- **Generic-token dampening** — if a token matches more than ~30% of all tables in the schema (e.g. "name", "date", "id" — present almost everywhere), its match weight is automatically reduced for that query. This is computed fresh per-question from whatever schema is loaded, so it isn't a hardcoded stopword list and keeps working if you swap in a different domain.
- **Minimum score of 4** — a table needs either a real name match or more than one corroborating signal to be selected; a single incidental word appearing somewhere in a table's description is no longer enough on its own.
- **FK dependency inclusion** — any table referenced by a FK in a selected table is automatically included so JOINs remain valid.

Top 5 scoring tables are selected, plus their FK dependencies. This keeps prompt tokens well under the 1280-token limit regardless of total schema size.

In **debug builds**, the SQL disclosure panel shows which tables were selected for each query.

### On-device model

| Item | Value |
|---|---|
| Model | Qwen 2.5 0.5B Instruct |
| Format | MediaPipe `.task` |
| Filename | `Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task` |
| File size | ~547 MB |
| Max tokens (input + output) | 1280 (set by `ekv1280` in filename — hard limit) |
| Inference engine | flutter_gemma (core) + flutter_gemma_mediapipe (engine) |
| Android ABIs | armeabi-v7a ✅  arm64-v8a ✅  x86_64 ✅ |
| Download source | HuggingFace (litert-community) |
| Internet after setup | Not required |

**Why flutter_gemma + MediaPipe `.task`?**

Every other Flutter on-device LLM package only ships `arm64-v8a` and `x86_64` native binaries. Many budget Android devices — particularly Samsung M-series and other low-cost field devices — run a 32-bit `armeabi-v7a` Android image. Google's MediaPipe `tasks-genai` is the only runtime that explicitly ships all three ABI variants, making it the correct choice for maximum device compatibility. `android/app/build.gradle`'s `ndk.abiFilters` includes all three for this reason.

**Engine registration (flutter_gemma 1.0+):** as of the 1.0 line, `flutter_gemma` core registers *no* inference engine by itself — it's a thin dispatch layer. The engine package (`flutter_gemma_mediapipe`, which handles `.task`/`.bin` files) must be explicitly registered once at startup, before any model is installed or loaded:

```dart
// lib/main.dart
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterGemma.initialize(inferenceEngines: [const MediaPipeEngine()]);
  // ... rest of startup, including AppState.initialize()
  runApp(...);
}
```

Skipping this produces: `Bad state: No inference engine can handle this model (ModelFileType.task). ... Registered engines: .` at model-load time — the download itself still succeeds, since that's handled separately, but nothing can load the file afterward.

### Response streaming

`LlmService.summarizeResults()` streams the summary token-by-token via `chat.generateChatResponseAsync()`. Per `flutter_gemma`'s documented contract, each `TextResponse.token` is already the *incremental* chunk for that stream event — it should be appended directly:

```dart
await for (final response in chat.generateChatResponseAsync()) {
  if (response is TextResponse) {
    buffer.write(response.token);
    onToken(response.token);
  }
}
```

> **Why this matters:** an earlier version of this method incorrectly treated `.token` as a *cumulative* string and tried to slice a "delta" out of it on every event. That mismatch corrupted the streamed output into scrambled, truncated text (e.g. a correct SQL answer would render as a summary like "Thereerered" or "Noatching") — a software bug, not a sign the model itself was incapable of summarizing.

### Database

The bundled `agri.db` is a comprehensive agricultural management database with **50 tables** and **1047 records** covering the full farming lifecycle:

| Domain | Tables |
|---|---|
| Geography | `state`, `district`, `village` |
| Land & Soil | `soil_type`, `land_document`, `soil_test` |
| Farmer & Farm | `farmer`, `farm` |
| Crops | `crop`, `variety`, `grade`, `season` |
| Production | `sowing`, `harvest` |
| Inputs | `fertilizer`, `fertilizer_application`, `pesticide`, `pesticide_application`, `input_supplier`, `input_purchase` |
| Water & Weather | `irrigation`, `weather_log` |
| Machinery & Labour | `equipment`, `equipment_usage`, `labour`, `labour_attendance` |
| Storage & Trade | `warehouse`, `stock`, `buyer`, `sale`, `market_price`, `delivery`, `transport` |
| Finance | `bank_account`, `loan`, `insurance`, `payment`, `subsidy` |
| Government | `government_scheme`, `scheme_enrollment` |
| Pest & Disease | `crop_disease`, `disease_report` |
| Advisory & Compliance | `advisory`, `inspection`, `certification` |
| Community | `cooperative`, `cooperative_member`, `training`, `training_attendance`, `feedback` |

---

## Project structure

```
askbase/
├── assets/
│   └── agri.db                        ← bundled database (replace to swap domain)
│
├── lib/
│   ├── main.dart                      ← entry point, engine registration, routing
│   │
│   ├── models/
│   │   ├── db_schema_model.dart       ← FieldDef, TableSchema, DatabaseSchema
│   │   └── chat_message.dart          ← ChatMessage (includes selectedTableNames)
│   │
│   ├── schema/
│   │   └── agri_schema.dart           ← swappable schema definition
│   │
│   ├── services/
│   │   ├── db_service.dart            ← sqflite access, SQL validation, case-insensitive rewrite
│   │   ├── schema_selector.dart       ← keyword-scoring table selection
│   │   ├── llm_service.dart           ← model download, load, SQL gen, summarize
│   │   └── query_service.dart         ← pipeline orchestrator
│   │
│   └── ui/
│       ├── app_theme.dart             ← colors, typography, theme
│       ├── app_state.dart             ← ChangeNotifier, all app state
│       ├── screens/
│       │   ├── splash_screen.dart
│       │   ├── download_screen.dart
│       │   └── chat_screen.dart
│       └── widgets/
│           ├── chat_bubble.dart       ← SQL disclosure + debug table panel
│           ├── input_bar.dart
│           ├── empty_chat.dart
│           ├── thinking_indicator.dart
│           └── error_screen.dart
```

---

## Getting started

### Prerequisites

- Flutter 3.41.1 (stable), Dart 3.8.x
- Android SDK 24+ (Android 7.0 minimum)
- ~600 MB free storage on device for the model

### 1. Clone and install dependencies

```bash
git clone https://github.com/SriramBalasubramaniyan/AskBase.git
cd askbase
flutter pub get
```

### 2. Build and run

```bash
flutter run          # debug — shows selected tables in SQL panel
flutter run --release # release — selected tables hidden
flutter build apk --release
```

---

## Swapping to a different database

AskBase is domain-agnostic. To use it with any other SQLite database:

### Step 1 — Replace the database file

```bash
cp your_new_database.db assets/agri.db
```

### Step 2 — Create a new schema file

Create `lib/schema/your_schema.dart`. Follow the same structure as `agri_schema.dart`. The `SchemaSelector` works automatically with any schema — no changes needed there (its generic-token dampening recalculates itself against whatever schema is loaded).

### Step 3 — Update main.dart (one line)

```dart
import 'schema/your_schema.dart';
create: (_) => AppState(yourSchema)..initialize(),
```

### Step 4 — Update suggestions in empty_chat.dart

Edit the `_suggestions` list in `lib/ui/widgets/empty_chat.dart`.

---

## Schema definition guide

### FieldDef parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `name` | `String` | ✅ | Exact column name in SQLite |
| `type` | `FieldType` | ✅ | `integer`, `text`, `real`, `blob` |
| `description` | `String` | ✅ | Used by SchemaSelector for keyword matching AND injected into LLM prompt |
| `isPrimaryKey` | `bool` | ❌ | Marks field as PK |
| `foreignKeyRef` | `String?` | ❌ | `"table.column"` — used for JOIN awareness and FK dependency resolution |

### Writing good descriptions

Descriptions serve two purposes: they help `SchemaSelector` find the right tables, and they help the model understand column semantics.

```dart
// ❌ Vague — selector won't find it, model won't understand it
FieldDef(name: 'qty', type: FieldType.real, description: 'Quantity')

// ✅ Specific — selector finds "loan" queries, model writes correct SQL
FieldDef(
  name: 'sanctioned_amount',
  type: FieldType.real,
  description: 'Amount sanctioned for the loan in rupees.',
)
```

For enum/status-style text columns, list the exact stored values in the description (e.g. `"Loan status (Active, Repaid, Overdue, NPA)."`) — the model uses this to pick a plausible value, and `DbService`'s `COLLATE NOCASE` rewrite covers you if the casing still doesn't match exactly.

### Token budget

The model has a hard limit of **1280 tokens**. SchemaSelector ensures only a handful of tables are sent per query, leaving most of the budget for SQL output. You can safely have 100+ tables in the schema — only the relevant subset is ever sent to the model.

---

## Security

- Only `SELECT` statements are allowed. `DROP`, `DELETE`, `UPDATE`, `INSERT`, `ALTER`, `CREATE`, `REPLACE`, `TRUNCATE`, `ATTACH`, `DETACH`, `PRAGMA` are all rejected.
- The database is opened and protected at the query validation layer via `validateSql()`.
- The model file is stored in the app's private documents directory.
- No data is sent to any server. Fully offline after setup — no API keys anywhere in the codebase.

---

## Troubleshooting

### Wrong tables selected for a query
- The SchemaSelector uses keyword matching. If results are wrong, improve field/table descriptions in the schema file — specific, distinctive wording scores better than generic terms (generic terms that appear in most tables are automatically dampened).
- In debug mode, expand the SQL panel to see which tables were selected, or call `SchemaSelector.instance.debugSelectionInfo(question, schema)` directly to see per-table scores and matched tokens.

### Query returns "No records found" but the data should exist
- Check for a **casing mismatch** first — `DbService` now applies `COLLATE NOCASE` automatically to `=`/`!=`/`<>` string comparisons, but not to `IN (...)` lists.
- Check whether the question uses a **relative date** (e.g. "last 3 months") against **static seed data** — `DATE('now', '-3 months')` resolves against the real device clock, so if your seed data's dates don't extend into the actual present, relative-date queries will legitimately return nothing. Either refresh the seed data's date range periodically, or ask with an explicit date range instead of a relative one.
- Confirm exact names first: "what farmers are there?" before filtering by a specific name.

### Summary text looks garbled or scrambled
- This was a known streaming bug (see "Response streaming" above) — confirm you're on the current `llm_service.dart`, which appends `TextResponse.token` directly instead of delta-slicing a wrongly-assumed cumulative string.

### App crashes with OUT_OF_RANGE error
- Selected tables + question exceeded 1280 tokens.
- Shorten field descriptions or reduce FK chains. The compact prompt format is already optimised.

### `Bad state: No inference engine can handle this model` at load time
- `FlutterGemma.initialize(inferenceEngines: [...])` wasn't called, or was called without `MediaPipeEngine()`. See "Engine registration" above. This must run before `AppState(...)..initialize()`.

### SQL shown as `TextResponse("SELECT ...")` instead of plain SQL
- Unwrap with `response is TextResponse ? response.token : response.toString()` in `llm_service.dart`.

### "The generated query was not safe to run"
- Usually the `TextResponse` wrapping issue above.
- Check if model output prose before the SQL — `_extractSql` strips markdown fences but not preamble.

### App crashes during inference (out of memory)
- At least 1.5 GB free RAM required. Close background apps.
- MediaPipe runs CPU-only on armeabi-v7a devices.

---

## Dependencies

| Package | Version | Purpose |
|---|---|---|
| `sqflite` | ^2.3.3 | SQLite access |
| `flutter_gemma` | ^1.0.0-rc.1 | On-device inference orchestration (core, engine-agnostic as of 1.0) |
| `flutter_gemma_mediapipe` | ^1.0.0-rc.1 | MediaPipe engine — must be registered via `FlutterGemma.initialize(inferenceEngines: [MediaPipeEngine()])` at startup |
| `path_provider` | ^2.1.3 | App documents directory |
| `provider` | ^6.1.2 | State management |
| `google_fonts` | ^6.3.3 | DM Sans |
| `flutter_markdown` | ^0.7.3 | Markdown rendering |
| `shared_preferences` | ^2.2.3 | Model-ready flag |
| `intl` | ^0.19.0 | Timestamp formatting |

Note: this app is fully offline by design — no cloud/API-key-based LLM dependency is used anywhere (nothing like `google_generative_ai`, `dio`, or `connectivity_plus` is required and none are in `pubspec.yaml`).

---

## Flutter SDK

**Required: Flutter 3.41.1 (stable), Dart 3.8.x**

- `flutter_gemma`/`flutter_gemma_mediapipe` are on the `1.0.0-rc.1` pre-release line — pin versions explicitly rather than leaving them unconstrained, since this package's API has changed meaningfully release to release (most recently the engine-registration split). Check the changelog before bumping.
- Android `minSdk 24` required by flutter_gemma's MediaPipe engine.

---

## Credits

- Model: [Qwen2.5-0.5B-Instruct](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct) by Alibaba Cloud
- MediaPipe task format: [litert-community](https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct)
- Inference runtime: [Google MediaPipe tasks-genai](https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference)
- Flutter plugin: [flutter_gemma](https://pub.dev/packages/flutter_gemma) by Volodymyr Khlinovskyi
