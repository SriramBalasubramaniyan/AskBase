/// API Configuration
/// ─────────────────────────────────────────────────────────────────────────────
/// Replace the value below with your Gemini API key.
///
/// Get a free key at: https://aistudio.google.com/app/apikey
/// Free tier: 15 requests/min, 1 million tokens/day — sufficient for field use.
///
/// IMPORTANT: Do not commit your API key to version control.
/// For production, use --dart-define or a secrets manager.
/// ─────────────────────────────────────────────────────────────────────────────

class ApiConfig {
  /// Your Gemini API key from https://aistudio.google.com/app/apikey
  static const String geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';

  /// Model to use for both SQL generation and summarization.
  /// gemini-2.0-flash is fast, cheap, and excellent at structured output.
  static const String geminiModel = 'gemini-2.0-flash';

  /// Request timeout — generous for slow field connections
  static const Duration requestTimeout = Duration(seconds: 30);
}
