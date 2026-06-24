import 'package:flutter/material.dart';
import '../config/brand_config.dart';

class BrandHeader extends StatelessWidget {
  final bool isArabic;

  const BrandHeader({super.key, this.isArabic = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(SakinaBrand.colorPrimary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            SakinaBrand.brandName,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily:
                  isArabic ? SakinaBrand.fontArabic : SakinaBrand.fontEnglish,
            ),
          ),
          const SizedBox(height: 8),
          if (isArabic)
            const Text(
              SakinaBrand.brandArabic,
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontFamily: SakinaBrand.fontArabic,
              ),
            ),
          const SizedBox(height: 12),
          Text(
            SakinaBrand.tagline,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
              fontFamily:
                  isArabic ? SakinaBrand.fontArabic : SakinaBrand.fontEnglish,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class BrandValuesList extends StatelessWidget {
  final bool isArabic;

  const BrandValuesList({super.key, this.isArabic = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'قيمنا' : 'Our Values',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...SakinaBrand.values.map((value) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(SakinaBrand.colorPrimary)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
