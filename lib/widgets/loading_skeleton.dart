import 'package:flutter/material.dart';

/// Static, neutral placeholders: no fake data, focus targets or animation timers.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  const SkeletonBox({super.key, this.width, this.height = 14});
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF253041)
          : const Color(0xFFEEF0F4),
      borderRadius: BorderRadius.circular(6),
    ),
  );
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E293B)
          : Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        SkeletonBox(width: 40, height: 40),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(),
              SizedBox(height: 12),
              FractionallySizedBox(
                widthFactor: .65,
                child: SkeletonBox(height: 10),
              ),
              SizedBox(height: 10),
              FractionallySizedBox(
                widthFactor: .4,
                child: SkeletonBox(height: 10),
              ),
            ],
          ),
        ),
        SizedBox(width: 12),
        SkeletonBox(width: 28, height: 22),
      ],
    ),
  );
}

class SkeletonList extends StatelessWidget {
  final int count;
  final bool grouped;
  final bool table;
  const SkeletonList({
    super.key,
    this.count = 4,
    this.grouped = false,
    this.table = false,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading content',
    child: ExcludeSemantics(
      child: IgnorePointer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (grouped)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SkeletonBox(width: 140, height: 22),
                ),
              ),
            for (var i = 0; i < count; i++)
              if (table)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 12,
                  ),
                  child: Row(
                    children: [
                      for (var column = 0; column < 5; column++)
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: SkeletonBox(),
                          ),
                        ),
                    ],
                  ),
                )
              else
                const SkeletonCard(),
          ],
        ),
      ),
    ),
  );
}

class SkeletonSummaryCards extends StatelessWidget {
  const SkeletonSummaryCards({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading summary',
    child: ExcludeSemantics(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 800) {
              return const Column(
                children: [SkeletonCard(), SkeletonCard(), SkeletonCard()],
              );
            }
            return const Row(
              children: [
                Expanded(child: SkeletonCard()),
                SizedBox(width: 20),
                Expanded(child: SkeletonCard()),
                SizedBox(width: 20),
                Expanded(child: SkeletonCard()),
              ],
            );
          },
        ),
      ),
    ),
  );
}
