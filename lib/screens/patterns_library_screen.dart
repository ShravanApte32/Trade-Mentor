import 'package:flutter/material.dart';
import 'package:trading_app/themes/app_theme.dart';

class PatternsLibraryScreen extends StatelessWidget {
  const PatternsLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        _buildPatternCategory(
          context,
          'Bullish Patterns',
          Icons.trending_up,
          AppTheme.accentGreen,
        ),
        _buildPatternCategory(
          context,
          'Bearish Patterns',
          Icons.trending_down,
          AppTheme.accentRed,
        ),
        _buildPatternCategory(
          context,
          'Neutral Patterns',
          Icons.remove,
          AppTheme.accentYellow,
        ),
        _buildPatternCategory(
          context,
          'Continuation Patterns',
          Icons.timeline,
          AppTheme.primaryColor,
        ),
        _buildPatternCategory(
          context,
          'Reversal Patterns',
          Icons.swap_vert,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildPatternCategory(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(icon, color: color, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          _showPatternCategoryDetails(context, title);
        },
      ),
    );
  }

  void _showPatternCategoryDetails(BuildContext context, String category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Coming Soon!', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 20),
              Text('Detailed patterns for $category will be available soon.'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }
}
