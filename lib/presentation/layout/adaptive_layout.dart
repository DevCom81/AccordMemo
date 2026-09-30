import 'package:flutter/material.dart';

abstract final class AppLayout {
  static const compactWidth = 680.0;
  static const masterDetailWidth = 960.0;
  static const sidebarWidth = 232.0;
}

/// Les enfants restent bornés horizontalement, même une fois empilés.
class AdaptiveRow extends StatelessWidget {
  const AdaptiveRow({
    super.key,
    required this.children,
    this.flexible = const {0},
    this.spacing = 16,
  });

  final List<Widget> children;
  final Set<int> flexible;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < AppLayout.compactWidth;
        return Flex(
          direction: stacked ? Axis.vertical : Axis.horizontal,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: stacked
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                SizedBox(
                  width: stacked ? 0 : spacing,
                  height: stacked ? spacing : 0,
                ),
              if (!stacked && flexible.contains(i))
                Expanded(child: children[i])
              else
                children[i],
            ],
          ],
        );
      },
    );
  }
}

/// États courts centrés, mais accessibles quand le clavier réduit la hauteur.
class ScrollableStatus extends StatelessWidget {
  const ScrollableStatus({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}
