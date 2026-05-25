import 'package:flutter/material.dart';

import '../services/api_service.dart' show Citation;

/// Step 13 (Phase 3): a tappable source-citation badge (brand accent green) that
/// opens a dialog with the full source metadata.
class CitationBadge extends StatelessWidget {
  final Citation source;

  const CitationBadge({super.key, required this.source});

  static const _primary = Color(0xFF1B6B5E);
  static const _accent = Color(0xFFE8F5E9);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCitationDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _primary),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              source.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _primary,
              ),
            ),
            if (source.author.isNotEmpty)
              Text(
                'by ${source.author}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF666666),
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCitationDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(source.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field('Author', source.author),
            if (source.chapter != null) _field('Chapter', source.chapter!),
            if (source.authenticityGrade != null)
              _field('Grade', source.authenticityGrade!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(value),
          ],
        ),
      );
}
