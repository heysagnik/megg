import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/offline_download_service.dart';

/// Download progress bottom sheet.
/// Shows download progress with item counts and size.
class DownloadProgressSheet extends StatelessWidget {
  final VoidCallback? onMinimizePressed;
  final VoidCallback? onCancelPressed;

  const DownloadProgressSheet({
    super.key,
    this.onMinimizePressed,
    this.onCancelPressed,
  });

  /// Show the progress sheet as a persistent bottom sheet
  static PersistentBottomSheetController? show(
    BuildContext context, {
    VoidCallback? onMinimize,
    VoidCallback? onCancel,
  }) {
    return Scaffold.of(context).showBottomSheet(
      (context) => DownloadProgressSheet(
        onMinimizePressed: () {
          Navigator.of(context).pop();
          onMinimize?.call();
        },
        onCancelPressed: () {
          OfflineDownloadService().cancelDownload();
          Navigator.of(context).pop();
          onCancel?.call();
        },
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  /// Show as modal bottom sheet
  static Future<void> showModal(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) => DownloadProgressSheet(
        onMinimizePressed: () => Navigator.of(context).pop(),
        onCancelPressed: () {
          OfflineDownloadService().cancelDownload();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: OfflineDownloadService(),
          builder: (context, _) {
            final progress = OfflineDownloadService().progress;
            return _buildContent(context, progress);
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, DownloadProgress progress) {
    final isComplete = progress.status == DownloadStatus.completed;
    final isError = progress.status == DownloadStatus.error;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                isComplete
                    ? PhosphorIconsBold.checkCircle
                    : isError
                        ? PhosphorIconsBold.warningCircle
                        : PhosphorIconsRegular.cloudArrowDown,
                size: 20,
                color: isError ? Colors.red : Colors.black,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isComplete
                      ? 'DOWNLOAD COMPLETE'
                      : isError
                          ? 'DOWNLOAD FAILED'
                          : 'DOWNLOADING FOR OFFLINE',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.5,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Progress bar
          if (!isComplete && !isError) ...[
            _buildProgressBar(progress),
            const SizedBox(height: 16),
          ],

          // Status items
          _buildStatusItem(
            'Color Combos',
            progress.colorCombosDownloaded,
            progress.colorCombosTotal,
            progress.colorCombosDownloaded >= progress.colorCombosTotal &&
                progress.colorCombosTotal > 0,
          ),
          const SizedBox(height: 8),
          _buildStatusItem(
            'Reels',
            progress.reelsDownloaded,
            progress.reelsTotal,
            progress.reelsDownloaded >= progress.reelsTotal &&
                progress.reelsTotal > 0,
          ),

          // Size info
          if (!isComplete && !isError) ...[
            const SizedBox(height: 16),
            Text(
              '${progress.downloadedMB} of ${progress.totalMB}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
                color: Colors.grey[500],
              ),
            ),
          ],

          // Error message
          if (isError && progress.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              progress.errorMessage!,
              style: TextStyle(
                fontSize: 11,
                color: Colors.red[400],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 24),

          // Action buttons
          _buildActionButtons(context, progress),
        ],
      ),
    );
  }

  Widget _buildProgressBar(DownloadProgress progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress track
        Container(
          height: 2,
          decoration: BoxDecoration(
            color: Colors.grey[200],
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.progress.clamp(0.0, 1.0),
            child: Container(
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Percentage
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              progress.currentItem,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.3,
                color: Colors.grey[600],
              ),
            ),
            Text(
              '${(progress.progress * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusItem(String label, int current, int total, bool isComplete) {
    return Row(
      children: [
        Icon(
          isComplete ? PhosphorIconsBold.check : PhosphorIconsRegular.circle,
          size: 14,
          color: isComplete ? Colors.black : Colors.grey[400],
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
            color: isComplete ? Colors.black : Colors.grey[600],
          ),
        ),
        const Spacer(),
        Text(
          isComplete ? 'Complete' : '$current / $total',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
            color: isComplete ? Colors.grey[600] : Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, DownloadProgress progress) {
    final isComplete = progress.status == DownloadStatus.completed;
    final isError = progress.status == DownloadStatus.error;

    if (isComplete) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onMinimizePressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            elevation: 0,
          ),
          child: const Text(
            'DONE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
        ),
      );
    }

    if (isError) {
      return Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: onCancelPressed,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: Colors.grey[600],
              ),
              child: const Text(
                'CLOSE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () => OfflineDownloadService().startDownload(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                elevation: 0,
              ),
              child: const Text(
                'RETRY',
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

    // Downloading state
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: onMinimizePressed,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: Colors.grey[600],
            ),
            child: const Text(
              'MINIMIZE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton(
            onPressed: onCancelPressed,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: Colors.red[400],
              side: BorderSide(color: Colors.red[400]!),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: const Text(
              'CANCEL',
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
