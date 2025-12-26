import 'package:flutter/foundation.dart';
import 'trending_service.dart';
import 'offer_service.dart';

class StartupService {
  final TrendingService _trendingService = TrendingService();
  final OfferService _offerService = OfferService();

  Future<void> prefetchData() async {
    try {
      await Future.wait([
        _trendingService.getTrendingProducts(),
        _offerService.getOffers(),
      ]);
    } catch (e) {
      debugPrint('Prefetch error: $e');
    }
  }
}
