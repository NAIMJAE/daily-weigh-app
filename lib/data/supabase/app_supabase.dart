import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';

SupabaseClient? get supabaseOrNull {
  if (!AppConfig.isConfigured) return null;
  return Supabase.instance.client;
}

SupabaseClient requireSupabase() {
  final client = supabaseOrNull;
  if (client == null) {
    throw StateError('앱 전용 Supabase가 아직 연결되지 않았습니다.');
  }
  return client;
}
