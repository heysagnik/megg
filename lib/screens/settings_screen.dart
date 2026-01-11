import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/aesthetic_app_bar.dart';
import '../services/notification_service.dart';
// import '../services/offline_download_service.dart'; // OFFLINE FEATURE DISABLED
// import '../widgets/download_progress_sheet.dart'; // OFFLINE FEATURE DISABLED

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _notificationService = NotificationService();
  // final _offlineService = OfflineDownloadService(); // OFFLINE FEATURE DISABLED
  bool _notificationsEnabled = true;
  // String _offlineStorageSize = '0 MB'; // OFFLINE FEATURE DISABLED

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
    // _loadOfflineInfo(); // OFFLINE FEATURE DISABLED
  }

  Future<void> _loadNotificationPreference() async {
    setState(() {
      _notificationsEnabled = _notificationService.notificationsEnabled;
    });
  }

  /* OFFLINE FEATURE DISABLED
  Future<void> _loadOfflineInfo() async {
    ...
  }
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AestheticAppBar(title: 'SETTINGS', showBackButton: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          _buildSection('PREFERENCES'),
          const SizedBox(height: 16),
          _buildSettingsTile(
            icon: PhosphorIconsRegular.bell,
            title: 'NOTIFICATIONS',
            subtitle: _notificationsEnabled
                ? 'Receive updates about new arrivals'
                : 'You won\'t receive any notifications',
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) async {
                setState(() {
                  _notificationsEnabled = value;
                });
                await _notificationService.setNotificationsEnabled(value);
              },
              activeThumbColor: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          // _buildOfflineDataTile(), // OFFLINE FEATURE DISABLED
          const SizedBox(height: 40),
          _buildSection('SUPPORT'),
          const SizedBox(height: 16),
          _buildSettingsTile(
            icon: PhosphorIconsRegular.star,
            title: 'WRITE A REVIEW',
            subtitle: 'Share your experience with us',
            onTap: _showReviewDialog,
            trailing: Icon(
              PhosphorIconsRegular.caretRight,
              size: 16,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: PhosphorIconsRegular.info,
            title: 'ABOUT US',
            subtitle: 'Learn more about MEGG',
            onTap: _showAboutDialog,
            trailing: Icon(
              PhosphorIconsRegular.caretRight,
              size: 16,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 40),
          _buildSection('LEGAL'),
          const SizedBox(height: 16),
          _buildSettingsTile(
            icon: PhosphorIconsRegular.shieldCheck,
            title: 'PRIVACY POLICY',
            subtitle: 'How we protect your data',
            onTap: () {
              // TODO: Navigate to privacy policy
            },
            trailing: Icon(
              PhosphorIconsRegular.caretRight,
              size: 16,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: PhosphorIconsRegular.fileText,
            title: 'TERMS OF SERVICE',
            subtitle: 'Our terms and conditions',
            onTap: () {
              // TODO: Navigate to terms of service
            },
            trailing: Icon(
              PhosphorIconsRegular.caretRight,
              size: 16,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'VERSION 1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                color: Colors.grey[400],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.0,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.05), width: 1),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: Colors.black),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing],
            ],
          ),
        ),
      ),
    );
  }

  /* OFFLINE FEATURE DISABLED
  Widget _buildOfflineDataTile() {
    ...
  }

  void _showOfflineOptions() {
    ...
  }

  void _showDownloadProgress() {
    ...
  }
  */

  void _showReviewDialog() {
    int rating = 0;
    final feedbackController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Title
                    const Text(
                      'WRITE A REVIEW',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Share your experience with MEGG',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Divider
                    Container(height: 1, color: Colors.grey[200]),
                    const SizedBox(height: 32),
                    // Rating section
                    Text(
                      'Your Rating',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              rating = index + 1;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Icon(
                              index < rating
                                  ? PhosphorIconsFill.star
                                  : PhosphorIconsRegular.star,
                              size: 36,
                              color: index < rating
                                  ? Colors.amber[700]
                                  : Colors.grey[300],
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),
                    // Feedback section
                    Text(
                      'Feedback (Optional)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border.all(
                          color: Colors.black.withOpacity(0.08),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: feedbackController,
                        maxLines: 5,
                        maxLength: 500,
                        decoration: InputDecoration(
                          hintText: 'Tell us what you think...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[400],
                            letterSpacing: 0.3,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          border: InputBorder.none,
                          counterStyle: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          letterSpacing: 0.3,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black,
                                side: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                              ),
                              child: const Text(
                                'CANCEL',
                                style: TextStyle(
                                  letterSpacing: 1.5,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (rating == 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Please select a rating',
                                        style: TextStyle(letterSpacing: 0.5),
                                      ),
                                      backgroundColor: Colors.black,
                                      behavior: SnackBarBehavior.floating,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.zero,
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                final stars = '⭐' * rating;
                                final feedback = feedbackController.text.trim();
                                final message = feedback.isNotEmpty
                                    ? 'Rating: $stars\n\nFeedback: $feedback'
                                    : 'Rating: $stars';

                                final encodedMessage = Uri.encodeComponent(
                                  message,
                                );
                                final whatsappUrl =
                                    'https://wa.me/918435648444?text=$encodedMessage';

                                if (await canLaunchUrl(
                                  Uri.parse(whatsappUrl),
                                )) {
                                  await launchUrl(
                                    Uri.parse(whatsappUrl),
                                    mode: LaunchMode.externalApplication,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'Could not open WhatsApp',
                                          style: TextStyle(letterSpacing: 0.5),
                                        ),
                                        backgroundColor: Colors.black,
                                        behavior: SnackBarBehavior.floating,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.zero,
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                              ),
                              child: const Text(
                                'SEND REVIEW',
                                style: TextStyle(
                                  letterSpacing: 1.5,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Logo/Title
                  const Text(
                    'MEGG',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 1,
                    width: 60,
                    color: Colors.black.withOpacity(0.2),
                  ),
                  const SizedBox(height: 32),
                  // Description
                  Text(
                    'MEGG is a premium fashion platform designed to bring timeless elegance to your wardrobe. Discover curated collections that blend contemporary style with classic sophistication.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.8,
                      color: Colors.grey[800],
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Developer info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border.all(
                        color: Colors.black.withOpacity(0.08),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'DEVELOPED BY',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'SAGNIK SAHOO',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 2.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Version
                  Text(
                    'VERSION 1.0.0',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.5,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Close button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      child: const Text(
                        'CLOSE',
                        style: TextStyle(
                          letterSpacing: 2.5,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
