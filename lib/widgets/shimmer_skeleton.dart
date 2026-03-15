import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme.dart';

class SubjectsSkeleton extends StatelessWidget {
  const SubjectsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
      child: Column(
        children: [
          Shimmer.fromColors(
            baseColor: const Color(0xFFE9E9F0),
            highlightColor: const Color(0xFFF4F4F8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.primary.withOpacity(0.10), width: 2),
              ),
              child: Column(
                children: [
                  Container(height: 18, width: 140, decoration: _pill()),
                  const SizedBox(height: 12),
                  Container(height: 12, width: 220, decoration: _pill()),
                  const SizedBox(height: 18),
                  Container(height: 44, width: 140, decoration: _pill(radius: 999)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Shimmer.fromColors(
            baseColor: const Color(0xFFE9E9F0),
            highlightColor: const Color(0xFFF4F4F8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(height: 16, width: 160, decoration: _pill()),
                Container(height: 12, width: 60, decoration: _pill()),
              ],
            ),
          ),
          const SizedBox(height: 10),

          ...List.generate(4, (i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Shimmer.fromColors(
                  baseColor: const Color(0xFFE9E9F0),
                  highlightColor: const Color(0xFFF4F4F8),
                  child: Container(
                    height: 88,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFEFEFF6)),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  static BoxDecoration _pill({double radius = 12}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      );
}
