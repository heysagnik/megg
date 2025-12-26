import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/connectivity_service.dart';

/// Slim offline banner shown at top of screens when device is offline.
/// Follows DESIGN_SYSTEM.md guidelines for minimal aesthetic.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ConnectivityService(),
      builder: (context, _) {
        final isOffline = ConnectivityService().isOffline;
        
        if (!isOffline) return const SizedBox.shrink();
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[100],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIconsRegular.cloudSlash,
                size: 14,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                'OFFLINE MODE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Wrap a screen body with offline banner at top
  static Widget wrapWithBanner(Widget child) {
    return Column(
      children: [
        const OfflineBanner(),
        Expanded(child: child),
      ],
    );
  }
}
