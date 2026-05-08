import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:trading_app/models/patterns.dart';
import 'package:trading_app/themes/app_theme.dart';

class PatternDetailScreen extends StatelessWidget {
  final PatternInfo patternInfo;

  const PatternDetailScreen({super.key, required this.patternInfo});

  String _extractAndDecodeSvg(String imageDataUrl) {
    try {
      String svgContent = imageDataUrl;

      // Handle data URL with utf8 prefix
      if (imageDataUrl.startsWith('data:image/svg+xml;utf8,')) {
        svgContent = imageDataUrl.substring('data:image/svg+xml;utf8,'.length);
      }
      // Handle data URL with charset=utf8
      else if (imageDataUrl.startsWith('data:image/svg+xml;charset=utf-8,')) {
        svgContent =
            imageDataUrl.substring('data:image/svg+xml;charset=utf-8,'.length);
      }
      // Handle base64 encoded
      else if (imageDataUrl.startsWith('data:image/svg+xml;base64,')) {
        final base64String =
            imageDataUrl.substring('data:image/svg+xml;base64,'.length);
        svgContent = String.fromCharCodes(base64.decode(base64String));
      }

      // Decode URL-encoded characters (like %3C for <, %3E for >)
      svgContent = Uri.decodeComponent(svgContent);

      print('Decoded SVG length: ${svgContent.length}');
      print(
          'SVG starts with: ${svgContent.substring(0, svgContent.length > 100 ? 100 : svgContent.length)}');

      return svgContent;
    } catch (e) {
      print('Error extracting SVG: $e');
      return '<svg width="120" height="100" xmlns="http://www.w3.org/2000/svg"><rect width="120" height="100" fill="#1a1a2e"/><text x="60" y="50" text-anchor="middle" fill="#cfd8dc" font-size="12">Pattern Image</text></svg>';
    }
  }

  @override
  Widget build(BuildContext context) {
    final svgContent = _extractAndDecodeSvg(patternInfo.image);

    return Scaffold(
      appBar: AppBar(
        title: Text(patternInfo.title),
        backgroundColor: AppTheme.surfaceColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pattern Image (SVG)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SvgPicture.string(
                  svgContent,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.contain,
                  placeholderBuilder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorBuilder: (context, error, stackTrace) {
                    print('SVG Error Details: $error');
                    print('Stack trace: $stackTrace');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image,
                              color: Colors.red, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            'Unable to display pattern',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                          Text(
                            'Pattern: ${patternInfo.title}',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Pattern Type Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: patternInfo.type.contains('Bull') == true
                    ? AppTheme.accentGreen.withOpacity(0.2)
                    : patternInfo.type.contains('Bear') == true
                        ? AppTheme.accentRed.withOpacity(0.2)
                        : AppTheme.accentYellow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                patternInfo.type,
                style: TextStyle(
                  color: patternInfo.type.contains('Bull') == true
                      ? AppTheme.accentGreen
                      : patternInfo.type.contains('Bear') == true
                          ? AppTheme.accentRed
                          : AppTheme.accentYellow,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Description Section
            const Text(
              '📖 Description',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              patternInfo.description,
              style: const TextStyle(height: 1.5, fontSize: 15),
            ),
            const SizedBox(height: 20),

            // Trading Tip Section
            const Text(
              '💡 Trading Tip',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                ),
              ),
              child: Text(
                patternInfo.tradeTip,
                style: const TextStyle(height: 1.5, fontSize: 15),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
