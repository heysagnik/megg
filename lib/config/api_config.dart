import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  // Base URLs and keys loaded from .env with safe fallbacks
  static String get baseUrl => dotenv.maybeGet('BASE_URL') ?? '';
  
  static String get apiBaseUrl => '$baseUrl/api';

  static String get supabaseUrl => dotenv.maybeGet('SUPABASE_URL') ?? '';

  static String get supabaseAnonKey =>
      dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '';

  // Constants remain compile-time where appropriate
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 15);
}
