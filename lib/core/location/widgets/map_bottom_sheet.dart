import 'package:flutter/material.dart';

class MapBottomSheet extends StatelessWidget {
  final Widget child;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final bool useDraggableSheet;

  const MapBottomSheet({
    super.key,
    required this.child,
    this.initialChildSize = 0.4,
    this.minChildSize = 0.15,
    this.maxChildSize = 0.9,
    this.useDraggableSheet = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!useDraggableSheet) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: child,
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
