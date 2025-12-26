import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class OfflineModeDialog extends StatefulWidget {
  final VoidCallback? onEnablePressed;
  final VoidCallback? onSkipPressed;

  const OfflineModeDialog({
    super.key,
    this.onEnablePressed,
    this.onSkipPressed,
  });

  /// Show the offline mode dialog
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => OfflineModeDialog(
        onEnablePressed: () {
          Navigator.of(context).pop(true);
        },
        onSkipPressed: () {
          Navigator.of(context).pop(false);
        },
      ),
    );
  }

  @override
  State<OfflineModeDialog> createState() => _OfflineModeDialogState();
}

class _OfflineModeDialogState extends State<OfflineModeDialog> {
  bool _isEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon header
            _buildIconHeader(),
            const SizedBox(height: 28),

            // Title
            const Text(
              'OFFLINE MODE',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.5,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              'Download style inspiration and reels to browse without internet connection.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.3,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),

            // Storage info
            Text(
              'Estimated download: ~250 MB',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 28),

            // Toggle switch
            _buildToggleRow(),
            const SizedBox(height: 32),

            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildIconHeader() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Cloud icon
            Icon(
              PhosphorIconsRegular.cloudArrowDown,
              size: 28,
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'ENABLE OFFLINE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
              color: Colors.black,
            ),
          ),
          SizedBox(
            height: 24,
            child: Switch(
              value: _isEnabled,
              onChanged: (value) {
                setState(() => _isEnabled = value);
              },
              activeThumbColor: Colors.black,
              activeTrackColor: Colors.black.withValues(alpha: 0.3),
              inactiveThumbColor: Colors.grey[400],
              inactiveTrackColor: Colors.grey[200],
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Skip button
        Expanded(
          child: TextButton(
            onPressed: widget.onSkipPressed,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              foregroundColor: Colors.grey[600],
            ),
            child: const Text(
              'SKIP',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Download button
        Expanded(
          child: ElevatedButton(
            onPressed: _isEnabled ? widget.onEnablePressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              disabledForegroundColor: Colors.grey[500],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              elevation: 0,
            ),
            child: const Text(
              'DOWNLOAD',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
