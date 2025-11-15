import 'package:flutter/material.dart';
import '../widgets/aesthetic_app_bar.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _notificationService = NotificationService();
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
    setState(() {
      _notificationsEnabled = _notificationService.notificationsEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AestheticAppBar(title: 'SETTINGS', showBackButton: true),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          _buildSection('PREFERENCES'),
          _buildNotificationTile(),
          const SizedBox(height: 32),
          _buildSection('ABOUT'),
          _buildAboutTile(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 2,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildNotificationTile() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withOpacity(0.08), width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        title: const Text(
          'NOTIFICATIONS',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            letterSpacing: 1.5,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            _notificationsEnabled
                ? 'Receive updates about new arrivals'
                : 'You won\'t receive any notifications',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              letterSpacing: 0.3,
            ),
          ),
        ),
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
    );
  }

  Widget _buildAboutTile() {
    return GestureDetector(
      onTap: () {
        _showAboutDialog();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black.withOpacity(0.08), width: 1),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          title: const Text(
            'ABOUT US',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.5,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Learn more about MEGG',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                letterSpacing: 0.3,
              ),
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'MEGG',
                style: TextStyle(
                  fontSize: 28,
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
              const SizedBox(height: 24),
              Text(
                'MEGG is a premium fashion platform designed to bring timeless elegance to your wardrobe. Discover curated collections that blend contemporary style with classic sophistication. Experience fashion that speaks to your refined taste.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.8,
                  color: Colors.grey[800],
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
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
                    const SizedBox(height: 8),
                    const Text(
                      'SAGNIK SAHOO',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
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
                    style: TextStyle(letterSpacing: 2.5, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
