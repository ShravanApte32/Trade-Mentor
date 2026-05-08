import 'package:flutter/material.dart';
import 'package:trading_app/themes/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool useMockData = true;
  bool darkMode = true;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        _buildSwitchTile(
          title: 'Use Mock Data',
          subtitle: 'Use mock data for development (no API calls)',
          value: useMockData,
          onChanged: (value) {
            setState(() => useMockData = value);
          },
        ),
        _buildSwitchTile(
          title: 'Dark Mode',
          subtitle: 'Toggle dark/light theme',
          value: darkMode,
          onChanged: (value) {
            setState(() => darkMode = value);
          },
        ),
        const Divider(),
        _buildSectionTitle('About'),
        _buildInfoTile('Version', '1.0.0'),
        _buildInfoTile('Developer', 'Trade Mentor Team'),
        _buildInfoTile('API', 'Alpha Vantage (Mock mode active)'),
        const Divider(),
        _buildButtonTile(
          title: 'Clear Cache',
          color: Colors.orange,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cache cleared!')),
            );
          },
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.primaryColor,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return ListTile(
      title: Text(title),
      trailing:
          Text(value, style: const TextStyle(color: AppTheme.textSecondary)),
    );
  }

  Widget _buildButtonTile({
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(title, style: TextStyle(color: color)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
