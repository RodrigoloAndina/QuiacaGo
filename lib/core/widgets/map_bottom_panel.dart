import 'package:flutter/material.dart';

/// Keeps a map panel above Android's navigation area and lets it scroll when
/// the available height shrinks (small screens, large text or the keyboard).
class MapBottomPanel extends StatelessWidget {
  const MapBottomPanel({
    super.key,
    required this.child,
    this.horizontalMargin = 0,
    this.bottomMargin = 0,
    this.includeSystemBottomInset = true,
  });

  final Widget child;
  final double horizontalMargin;
  final double bottomMargin;
  final bool includeSystemBottomInset;

  @override
  Widget build(BuildContext context) {
    final systemBottomInset = includeSystemBottomInset
        ? MediaQuery.viewPaddingOf(context).bottom
        : 0.0;
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: constraints.maxWidth,
          child: SingleChildScrollView(
            reverse: true,
            padding: EdgeInsets.fromLTRB(
              horizontalMargin,
              0,
              horizontalMargin,
              bottomMargin + systemBottomInset,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
