import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String supabaseUrl = '';
  static String supabaseAnonKey = '';

  static bool get isConfigured {
    return supabaseUrl.startsWith('https://') &&
        !supabaseUrl.contains('your-app-project') &&
        supabaseAnonKey.length > 20 &&
        !supabaseAnonKey.startsWith('your-');
  }

  static Future<void> load() async {
    const defineUrl = String.fromEnvironment('SUPABASE_URL');
    const defineKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    var loadedEnv = false;
    try {
      await dotenv.load(fileName: 'assets/env/.env');
      loadedEnv = true;
    } catch (_) {}
    if (!loadedEnv) {
      try {
        await dotenv.load(fileName: 'assets/env/.env.example');
      } catch (_) {}
    }

    supabaseUrl = defineUrl.isNotEmpty
        ? defineUrl
        : (dotenv.maybeGet('SUPABASE_URL') ?? '');
    supabaseAnonKey = defineKey.isNotEmpty
        ? defineKey
        : (dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '');
  }
}
