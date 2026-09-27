import 'package:flutter/material.dart';

List<String> feedbackTips(Object? value) {
  if (value is Iterable) return value.expand(feedbackTips).toList();
  if (value is! String) return [];
  return value
      .split(RegExp(r'\n+|[•]+|(?<=[.!?])\s+(?=[A-Z])'))
      .map(
        (tip) =>
            tip.replaceFirst(RegExp(r'^\s*(?:[-*]|\d+[.)])\s*'), '').trim(),
      )
      .where((tip) => tip.isNotEmpty)
      .toList();
}

class FeedbackTips extends StatelessWidget {
  final Object? tips;
  const FeedbackTips({super.key, required this.tips});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Tips', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      for (final tip in feedbackTips(tips))
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(color: Colors.grey)),
              Expanded(
                child: Text(
                  tip,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
