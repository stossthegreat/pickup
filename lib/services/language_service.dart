import 'package:shared_preferences/shared_preferences.dart';

/// One supported roleplay language.
class AppLanguage {
  final String code; // BCP-47 primary tag sent to the AI backend
  final String native; // shown in the picker — people find their own
  final String flag;
  const AppLanguage(this.code, this.native, this.flag);
}

/// The user's language — the single highest-impact retention lever for
/// non-English markets (the wingman app's data: big non-English install
/// volume, instant trial churn without language support).
///
/// English is ALWAYS the default. The picked code rides every AI
/// request (realtime voice body's `language` field) so she flirts,
/// pushes back and coaches in the user's own language. The app chrome
/// stays English for now — the AI speaking your language is 90% of the
/// value; full UI l10n comes later.
class LanguageService {
  static const _key = 'app_language';

  /// Ordered by market size for this product. English first, always.
  static const supported = <AppLanguage>[
    AppLanguage('en', 'English', '🇬🇧'),
    AppLanguage('es', 'Español', '🇪🇸'),
    AppLanguage('pt', 'Português', '🇧🇷'),
    AppLanguage('fr', 'Français', '🇫🇷'),
    AppLanguage('de', 'Deutsch', '🇩🇪'),
    AppLanguage('it', 'Italiano', '🇮🇹'),
    AppLanguage('nl', 'Nederlands', '🇳🇱'),
    AppLanguage('tr', 'Türkçe', '🇹🇷'),
    AppLanguage('pl', 'Polski', '🇵🇱'),
    AppLanguage('ru', 'Русский', '🇷🇺'),
    AppLanguage('ar', 'العربية', '🇸🇦'),
    AppLanguage('hi', 'हिन्दी', '🇮🇳'),
    AppLanguage('id', 'Bahasa Indonesia', '🇮🇩'),
    AppLanguage('ja', '日本語', '🇯🇵'),
    AppLanguage('ko', '한국어', '🇰🇷'),
  ];

  /// Synchronous cache so hot paths (session connect) never await a
  /// prefs read. Hydrated at app launch + on every set().
  static String cachedCode = 'en';

  static AppLanguage get current => supported.firstWhere(
        (l) => l.code == cachedCode,
        orElse: () => supported.first,
      );

  /// Call once from main() — cheap, resolves before any session starts.
  static Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    cachedCode = prefs.getString(_key) ?? 'en';
  }

  static Future<void> set(String code) async {
    cachedCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }
}
