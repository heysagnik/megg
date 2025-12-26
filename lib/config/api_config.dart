class ApiConfig {
  // Primary API - Fast, edge-cached endpoints (use for most requests)
  static const String baseUrl = 'https://api.megg.workers.dev/api';
  
  // Secondary API - For auth and user-specific operations
  static const String vercelUrl = 'https://megg-api.vercel.app';

  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 15);
}
