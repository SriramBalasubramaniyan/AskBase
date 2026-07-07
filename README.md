# AskBase

**Natural language query interface over any structured SQLite database, powered by an on-device SLM. No internet required after setup. No data leaves the device.**

---

## What it does

AskBase lets you ask plain-language questions about a SQLite database and get clear, summarized answers — entirely offline, on the device.

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
4. The query runs against the local database
5. The model summarizes the results in plain language

---

## Architecture

```
User Question
     │
     ▼
SchemaSelector.select()           ← keyword scoring against 50-table schema
     │                               returns 5-8 relevant tables + FK deps
     ▼
LlmService.generateSql()          ← compact schema injected (selected tables only)
     │
     ▼
SQL query (validated, SELECT only)
     │
     ▼
DbService.runSelect()             ← sqflite, read-only enforcement via validation
     │
     ▼
JSON rows (capped at 50)
     │
     ▼
LlmService.summarizeResults()     ← streaming tokens
     │
     ▼
Natural language answer
```

### Semantic schema selection

The full 50-table schema is too large to fit in the model's 1280-token context window. `SchemaSelector` solves this by scoring each table against the user's question using:

- **Table name match** (weight: 10) — exact word match in table name
- **Table description match** (weight: 3) — keyword found in description
- **Field name match** (weight: 5) — keyword matches a column name
- **Field description match** (weight: 2) — keyword found in field description
- **FK dependency inclusion** — any table referenced by a FK in a selected table is automatically included so JOINs remain valid

Top 5 scoring tables are selected, plus their FK dependencies. This keeps prompt tokens under ~400, leaving ~880 tokens for SQL output — well within the 1280-token limit regardless of total schema size.

In **debug builds**, the SQL disclosure panel shows which tables were selected for each query.

### On-device model

| Item | Value |
|---|---|
| Model | Qwen 2.5 0.5B Instruct |
| Format | MediaPipe `.task` |
| Filename | `Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task` |
| File size | ~547 MB |
| Max tokens (input + output) | 1280 (set by `ekv1280` in filename — hard limit) |
| Inference engine | flutter_gemma + MediaPipe tasks-genai |
| Android ABIs | armeabi-v7a ✅  arm64-v8a ✅  x86_64 ✅ |
| Download source | HuggingFace (litert-community) |
| Internet after setup | Not required |

**Why flutter_gemma + MediaPipe `.task`?**

Every other Flutter on-device LLM package (nobodywho, llama_cpp_dart, fllama) only ships `arm64-v8a` and `x86_64` native binaries. Many budget Android devices — particularly Samsung M-series and other low-cost field devices — run a 32-bit `armeabi-v7a` Android image. Google's MediaPipe `tasks-genai` is the only runtime that explicitly ships all three ABI variants, making it the correct choice for maximum device compatibility.

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
│   ├── main.dart                      ← entry point + routing
│   │
│   ├── models/
│   │   ├── db_schema_model.dart       ← FieldDef, TableSchema, DatabaseSchema
│   │   └── chat_message.dart          ← ChatMessage (includes selectedTableNames)
│   │
│   ├── schema/
│   │   └── agri_schema.dart            ← Semantic table selection
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
git clone https://github.com/your-org/askbase.git
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

Create `lib/schema/your_schema.dart`. Follow the same structure as `agri_schema.dart`. The `SchemaSelector` works automatically with any schema — no changes needed there.

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

### Token budget

The model has a hard limit of **1280 tokens**. SchemaSelector ensures only 5-8 tables are sent per query (~300-400 tokens), leaving ~880 tokens for SQL output. You can safely have 100+ tables in the schema — only the relevant subset is ever sent to the model.

---

## Security

- Only `SELECT` statements are allowed. `DROP`, `DELETE`, `UPDATE`, `INSERT`, `ALTER`, `CREATE`, `REPLACE`, `TRUNCATE`, `ATTACH`, `DETACH`, `PRAGMA` are all rejected.
- The database is opened and protected at the query validation layer via `validateSql()`.
- The model file is stored in the app's private documents directory.
- No data is sent to any server. Fully offline after setup.

---

## Troubleshooting

### Wrong tables selected for a query
- The SchemaSelector uses keyword matching. If results are wrong, improve field/table descriptions in the schema file.
- In debug mode, expand the SQL panel to see which tables were selected.

### App crashes with OUT_OF_RANGE error
- Selected tables + question exceeded 1280 tokens.
- Shorten field descriptions or reduce FK chains. The compact prompt format is already optimised.

### SQL shown as `TextResponse("SELECT ...")` instead of plain SQL
- Unwrap with `response is TextResponse ? response.token : response.toString()` in `llm_service.dart`.

### "The generated query was not safe to run"
- Usually the `TextResponse` wrapping issue above.
- Check if model output prose before the SQL — `_extractSql` strips markdown fences but not preamble.

### App crashes during inference (out of memory)
- At least 1.5 GB free RAM required. Close background apps.
- MediaPipe runs CPU-only on armeabi-v7a devices.

### "No records found" for valid questions
- Confirm exact names first: "what farmers are there?" before filtering by name.

---

## Dependencies

| Package | Version | Purpose |
|---|---|---|
| `sqflite` | ^2.3.3 | SQLite access |
| `flutter_gemma` | ^0.15.0 | On-device inference orchestration |
| `flutter_gemma_mediapipe` | ^0.15.0 | MediaPipe engine (ships armeabi-v7a binaries) |
| `dio` | ^5.4.3 | Model download with progress |
| `path_provider` | ^2.1.3 | App documents directory |
| `provider` | ^6.1.2 | State management |
| `google_fonts` | 6.3.2 | DM Sans — pinned; 6.3.0/6.3.1 broken on Dart 3.8 |
| `flutter_markdown` | ^0.7.3 | Markdown rendering |
| `connectivity_plus` | ^6.0.3 | WiFi check before download |
| `shared_preferences` | ^2.2.3 | Model-ready flag |
| `intl` | ^0.19.0 | Timestamp formatting |

---

## Flutter SDK

**Required: Flutter 3.41.1 (stable), Dart 3.8.x**

- `google_fonts` pinned to `6.3.2` — 6.3.0/6.3.1 broken on Dart 3.8
- `flutter_gemma ^0.15.0` requires Dart 3.8+
- Android `minSdk 24` required by flutter_gemma MediaPipe engine

---

## Credits

- Model: [Qwen2.5-0.5B-Instruct](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct) by Alibaba Cloud
- MediaPipe task format: [litert-community](https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct)
- Inference runtime: [Google MediaPipe tasks-genai](https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference)
- Flutter plugin: [flutter_gemma](https://pub.dev/packages/flutter_gemma) by Volodymyr Khlinovskyi
