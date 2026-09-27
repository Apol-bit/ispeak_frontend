import 'package:flutter/material.dart';

/// Reserves space for the back control; the title and content scroll beneath it.
class FixedBackLayout extends StatelessWidget {
  final Widget child;
  final VoidCallback? onBack;
  final Color backgroundColor;
  final Color foregroundColor;

  const FixedBackLayout({
    super.key,
    required this.child,
    this.onBack,
    this.backgroundColor = const Color(0xFF3F7CF4),
    this.foregroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ColoredBox(
        color: backgroundColor,
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextButton.icon(
                key: const ValueKey('fixed-back-button'),
                style: TextButton.styleFrom(
                  foregroundColor: foregroundColor,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: onBack ?? () => Navigator.maybePop(context),
                icon: const Icon(Icons.chevron_left),
                label: const Text('Back'),
              ),
            ),
          ),
        ),
      ),
      Expanded(
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: SafeArea(top: false, child: child),
        ),
      ),
    ],
  );
}
