import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class LecturesSkeleton extends StatelessWidget {
  const LecturesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Section header shimmer
        Shimmer.fromColors(
          baseColor: const Color(0xFFE9E9F0),
          highlightColor: const Color(0xFFF4F4F8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              height: 18,
              width: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        ...List.generate(4, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Shimmer.fromColors(
                baseColor: const Color(0xFFE9E9F0),
                highlightColor: const Color(0xFFF4F4F8),
                child: Container(
                  height: 92,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFEFEFF6)),
                  ),
                ),
              ),
            )),
      ],
    );
  }
}
