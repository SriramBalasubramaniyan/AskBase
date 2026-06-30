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
2. The model generates a SQLite SELECT query
3. The query runs against the local database
4. The model summarizes the results in plain language

---

## Architecture

```
User Question
     │
     ▼
LlmService.generateSql()          ← schema injected into system prompt
     │
     ▼
SQL query (validated, SELECT only)
     │
     ▼
DbService.runSelect()             ← sqflite, read-only
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

### On-device model

| Item | Value |
|---|---|
| Model | Qwen2.5-Coder-1.5B-Instruct |
| Quantization | Q4_K_M (GGUF) |
| File size | ~986 MB |
| RAM at runtime | ~1.3 GB |
| Inference engine | fllama (llama.cpp) |
| Download source | HuggingFace (bartowski) |

The model is **not bundled** with the APK. On first launch the app shows a one-time download screen. After download the model lives in the app's private documents directory and is never re-downloaded.

### Database

The bundled `agri.db` tracks an agricultural domain:

| Table | Description |
|---|---|
| `farmer` | Registered farmers |
| `farm` | Farms owned by farmers |
| `crop` | Crop types (Paddy, Wheat, Maize…) |
| `variety` | Crop varieties (IR64, HD2967…) |
| `grade` | Quality grades per variety |
| `sowing` | Sowing events (who, where, what, when, how much) |
| `harvest` | Harvest events (who, where, what, when, how much) |

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
│   │   └── chat_message.dart          ← ChatMessage, MessageRole, MessageState
│   │
│   ├── schema/
│   │   └── agri_schema.dart           ← ★ SWAP THIS FILE to change domain ★
│   │
│   ├── services/
│   │   ├── db_service.dart            ← DB copy from assets, query execution
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
│           ├── chat_bubble.dart       ← message bubble + SQL disclosure
│           ├── input_bar.dart         ← text input + send button
│           ├── empty_chat.dart        ← suggestions + schema summary
│           ├── thinking_indicator.dart
│           └── error_screen.dart
```

---

## Getting started

### Prerequisites

- Flutter 3.22+ with Dart 3.3+
- Android SDK 23+ (Android 5.0 minimum)
- ~2 GB free storage on the device for the model

### 1. Clone and install dependencies

```bash
git clone https://github.com/SriramBalasubramaniyan/AskBase.git
cd askbase
flutter pub get
```

### 2. Add the database

Copy your SQLite database to the assets folder:

```bash
cp your_database.db assets/agri.db
```

The file is already declared in `pubspec.yaml`. If you rename it, update both `pubspec.yaml` and your schema file.

### 3. Build and run

```bash
# Debug
flutter run

# Release APK
flutter build apk --release

# Release AAB (for Play Store)
flutter build appbundle --release
```

---

## Swapping to a different database

AskBase is domain-agnostic. To use it with any other SQLite database:

### Step 1 — Replace the database file

```bash
cp your_new_database.db assets/agri.db
# Or rename and update pubspec.yaml + schema
```

### Step 2 — Create a new schema file

Create `lib/schema/your_schema.dart`:

```dart
import '../models/db_schema_model.dart';

final yourSchema = DatabaseSchema(
  databaseName: 'YourApp',
  dbFileName: 'your.db',
  assetPath: 'assets/your.db',
  databaseDescription: 'One paragraph describing what this database contains.',
  tables: [
    TableSchema(
      tableName: 'your_table',
      tableDescription: 'What this table stores.',
      fields: [
        FieldDef(
          name: 'id',
          type: FieldType.integer,
          description: 'Unique identifier.',
          isPrimaryKey: true,
        ),
        FieldDef(
          name: 'name',
          type: FieldType.text,
          description: 'Name of the entity.',
        ),
        FieldDef(
          name: 'parent_id',
          type: FieldType.integer,
          description: 'Reference to parent record.',
          foreignKeyRef: 'parent_table.id',
        ),
      ],
    ),
    // add more tables...
  ],
);
```

### Step 3 — Update main.dart (one line)

```dart
// Before
import 'schema/agri_schema.dart';
// ...
create: (_) => AppState(agriSchema)..initialize(),

// After
import 'schema/your_schema.dart';
// ...
create: (_) => AppState(yourSchema)..initialize(),
```

### Step 4 — Update suggestions in empty_chat.dart

Edit the `_suggestions` list in `lib/ui/widgets/empty_chat.dart` to reflect questions relevant to your new domain.

That's it. No other file needs to change.

---

## Schema definition guide

### FieldDef parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `name` | `String` | ✅ | Exact column name in SQLite |
| `type` | `FieldType` | ✅ | `integer`, `text`, `real`, `blob` |
| `description` | `String` | ✅ | Injected into LLM prompt — be specific |
| `isPrimaryKey` | `bool` | ❌ | Marks field as PK in prompt |
| `foreignKeyRef` | `String?` | ❌ | `"table.column"` format for JOIN awareness |

### Writing good field descriptions

The description is what the model reads to understand what each column means. Be specific:

```dart
// ❌ Too vague — model won't know what to do with this
FieldDef(name: 'qty', type: FieldType.real, description: 'Quantity')

// ✅ Specific — model generates accurate queries
FieldDef(
  name: 'quantity_kg',
  type: FieldType.real,
  description: 'Quantity of seed sown in kilograms.',
)
```

For date fields, always mention the format:

```dart
FieldDef(
  name: 'sow_date',
  type: FieldType.text,
  description: 'Date when sowing occurred, stored as ISO-8601 text (YYYY-MM-DD).',
)
```

---

## Security

- Only `SELECT` statements are allowed. Any query containing `DROP`, `DELETE`, `UPDATE`, `INSERT`, `ALTER`, `CREATE`, `REPLACE`, `TRUNCATE`, `ATTACH`, `DETACH`, or `PRAGMA` is rejected before execution.
- The database is opened in **read-only** mode via sqflite.
- The model file is stored in the app's private documents directory (not accessible to other apps).
- No data is sent to any server. The model runs 100% on-device.

---

## Troubleshooting

### Model download fails

- Check the device has internet access
- Confirm WiFi is connected (recommended for 986 MB download)
- The download resumes from scratch if cancelled — partial files are deleted automatically
- HuggingFace CDN occasionally has rate limits; retry after a few minutes

### App crashes during inference

- The device may not have enough free RAM (~1.3 GB required at runtime)
- Close background apps and retry
- On very low-end devices (< 2 GB RAM), consider testing on a device with more RAM

### Model gives wrong SQL

- Improve your field descriptions in the schema file — the more specific, the better
- Add `foreignKeyRef` to all foreign key fields so the model knows how to JOIN
- For complex multi-table queries, the 1.5B model may occasionally make mistakes; rephrase the question more specifically

### "No records found" for valid questions

- The question may be using a name or value that differs from what's in the database
- Ask "what farmers are there?" first to confirm exact names before filtering by name

---

## Dependencies

| Package | Version | Purpose |
|---|---|---|
| `sqflite` | ^2.3.3 | SQLite access |
| `fllama` | ^0.6.0 | On-device GGUF inference (llama.cpp) |
| `dio` | ^5.4.3 | Model download with progress |
| `path_provider` | ^2.1.3 | App documents directory |
| `provider` | ^6.1.2 | State management |
| `google_fonts` | ^6.2.1 | DM Sans typeface |
| `flutter_markdown` | ^0.7.3 | Markdown rendering in bubbles |
| `connectivity_plus` | ^6.0.3 | WiFi check before download |
| `shared_preferences` | ^2.2.3 | Model-ready flag persistence |
| `intl` | ^0.19.0 | Timestamp formatting |

---

## License

MIT License. See `LICENSE` for details.

---

## Credits

- Model: [Qwen2.5-Coder-1.5B-Instruct](https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct) by Alibaba Cloud
- GGUF quantization: [bartowski](https://huggingface.co/bartowski/Qwen2.5-Coder-1.5B-Instruct-GGUF)
- Inference engine: [llama.cpp](https://github.com/ggerganov/llama.cpp) via [fllama](https://pub.dev/packages/fllama)
