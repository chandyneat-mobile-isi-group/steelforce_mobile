// category_icon.dart
// Renders one catalogue icon with the house micro-interactions:
//   appear  fade + 0.96 -> 1.0 over 300ms
//   press   1.0 -> 0.96 over 140ms
//   active  colour, well and stroke weight cross-fade over 220ms
//   ambient a 3.6s breath that runs ONLY while selected
//
// The SVGs are duotone on `currentColor`, so one asset covers light, dark,
// active and inactive — SvgTheme supplies the hue.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'category_icon_tokens.dart';
import 'category_icons.dart';

class CategoryIcon extends StatefulWidget {
  const CategoryIcon({
    super.key,
    required this.code,
    this.name,
    this.active = false,
    this.size = CategoryIconTokens.sizeGrid,
    this.chipSize = CategoryIconTokens.chipGrid,
    this.showChip = true,
    this.onTap,
  });

  final String code;
  final String? name;
  final bool active;
  final double size;
  final double chipSize;
  final bool showChip;
  final VoidCallback? onTap;

  @override
  State<CategoryIcon> createState() => _CategoryIconState();
}

class _CategoryIconState extends State<CategoryIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: CategoryIconTokens.ambient,
  );
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _ambient.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant CategoryIcon old) {
    super.didUpdateWidget(old);
    if (widget.active && !_ambient.isAnimating) {
      _ambient.repeat(reverse: true);
    } else if (!widget.active && _ambient.isAnimating) {
      _ambient.animateTo(0, duration: CategoryIconTokens.state);
    }
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = specFor(widget.code, name: widget.name);
    final colour = CategoryIconTokens.of(context, spec.family);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    Widget glyph = SvgPicture.asset(
      widget.active ? spec.activeAsset : spec.asset,
      width: widget.size,
      height: widget.size,
      theme: SvgTheme(currentColor: colour),
      semanticsLabel: spec.label,
    );

    // Ambient breath: a 1.5% scale, nothing more. Off when not selected.
    if (!reduceMotion) {
      glyph = ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 1.015).animate(
          CurvedAnimation(parent: _ambient, curve: Curves.easeInOut),
        ),
        child: glyph,
      );
    }

    if (widget.showChip) {
      glyph = AnimatedContainer(
        duration: CategoryIconTokens.state,
        curve: CategoryIconTokens.easeSoft,
        width: widget.chipSize,
        height: widget.chipSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: CategoryIconTokens.chip(context, spec.family,
              active: widget.active),
          shape: BoxShape.circle,
        ),
        child: glyph,
      );
    }

    return Semantics(
      button: widget.onTap != null,
      selected: widget.active,
      label: spec.label,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: CategoryIconTokens.press,
          curve: CategoryIconTokens.easeOut,
          child: glyph,
        ),
      ),
    );
  }
}

/// Grid tile: icon over a code, matching the catalogue screens.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.code,
    this.active = false,
    this.onTap,
  });

  final String code;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final spec = specFor(code);
    final colour = CategoryIconTokens.of(context, spec.family);
    final theme = Theme.of(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1.0),
      duration: CategoryIconTokens.appear,
      curve: CategoryIconTokens.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: ((t - 0.96) / 0.04).clamp(0.0, 1.0),
        child: Transform.scale(scale: t, child: child),
      ),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 18, 10, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active
                    ? colour.withOpacity(0.38)
                    : theme.dividerColor.withOpacity(0.6),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CategoryIcon(code: code, active: active, onTap: onTap),
                const SizedBox(height: 10),
                Text(
                  spec.label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.3,
                    height: 1.35,
                    color: active ? colour : theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
