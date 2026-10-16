import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Shape-matched placeholders for the guided flow.
///
/// Each variant mirrors the layout of the content it stands in for, so the
/// switch from loading to loaded is a fill, not a relayout — which is what
/// keeps the stage transitions from stuttering on a slow catalog read.
class LoadingProducts extends StatelessWidget {
  const LoadingProducts._({required this.child});

  /// Placeholder for a row of selectable chips.
  factory LoadingProducts.chips({int count = 4}) =>
      LoadingProducts._(child: _ChipSkeletons(count: count));

  /// Placeholder for the option grid (thickness, length, size…).
  factory LoadingProducts.grid({int count = 6}) =>
      LoadingProducts._(child: _GridSkeletons(count: count));

  /// Placeholder for the family list rows.
  factory LoadingProducts.list({int count = 3}) =>
      LoadingProducts._(child: _ListSkeletons(count: count));

  /// Placeholder for the resolved product cards.
  factory LoadingProducts.products({int count = 4}) =>
      LoadingProducts._(child: _ListSkeletons(count: count, height: 76));

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _Shimmer extends StatefulWidget {
  const _Shimmer({this.width, required this.height, this.radius = 12});

  final double? width;
  final double height;
  final double radius;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
            colors.surfaceSoft,
            colors.border,
            _controller.value * 0.6,
          ),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

class _ChipSkeletons extends StatelessWidget {
  const _ChipSkeletons({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < count; i++)
            _Shimmer(width: 78.0 + (i % 3) * 22, height: 38, radius: 19),
        ],
      );
}

class _GridSkeletons extends StatelessWidget {
  const _GridSkeletons({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.9,
        children: [
          for (var i = 0; i < count; i++) const _Shimmer(height: 52),
        ],
      );
}

class _ListSkeletons extends StatelessWidget {
  const _ListSkeletons({required this.count, this.height = 60});
  final int count;
  final double height;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Shimmer(height: height),
            ),
        ],
      );
}
