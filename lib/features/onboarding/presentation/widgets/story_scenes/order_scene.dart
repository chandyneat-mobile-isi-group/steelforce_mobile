import 'package:flutter/material.dart';
import 'package:steelforce/features/onboarding/presentation/widgets/story_scenes/scene_parts.dart';

/// Products chosen, priced, discounted, approved.
class OrderScene extends StatelessWidget {
  const OrderScene({
    super.key,
    required this.t,
    required this.accent,
    required this.success,
  });

  final double t;
  final Color accent, success;

  static const _rows = [
    ('Deformed Bar D12', 'x 120', r'$ 8,640'),
    ('H-Beam 200×100', 'x 24', r'$ 5,280'),
    ('Steel Sheet 4mm', 'x 60', r'$ 3,150'),
  ];

  @override
  Widget build(BuildContext context) {
    return SceneShell(
      t: t,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SceneText('CREATE QUOTATION',
                  size: 9, color: sceneMuted, weight: FontWeight.w800),
              const SizedBox(height: 16),
              // Rows arrive one at a time — three of them, well inside the ≤6
              // the motion standard allows before a stagger reads as broken.
              for (var i = 0; i < _rows.length; i++)
                _ProductRow(
                  t: sceneUnit((t - 0.08 - i * 0.15) / 0.34),
                  name: _rows[i].$1,
                  qty: _rows[i].$2,
                  price: _rows[i].$3,
                ),
              const SizedBox(height: 14),
              // The approval branch of the brief's two workflows, compressed to
              // its one legible beat.
              Opacity(
                opacity: sceneUnit((t - 0.66) / 0.20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Chip('Discount 6%', accent),
                    const SizedBox(width: 8),
                    _Chip('Approved', success),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.t,
    required this.name,
    required this.qty,
    required this.price,
  });

  final double t;
  final String name, qty, price;

  @override
  Widget build(BuildContext context) {
    if (t <= 0) return const SizedBox.shrink();
    final eased = Curves.easeOutCubic.transform(t);
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(24 * (1 - eased), 0),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: SceneCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: sceneBlockFill,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.layers_rounded,
                      size: 15, color: sceneMuted),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: SceneText(name,
                      size: 12,
                      color: sceneInk,
                      weight: FontWeight.w700,
                      align: TextAlign.left),
                ),
                SceneText(qty, size: 11, color: sceneMuted),
                const SizedBox(width: 10),
                SceneText(price,
                    size: 12, color: sceneInk, weight: FontWeight.w800),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: SceneText(text, size: 10, color: color, weight: FontWeight.w800),
    );
  }
}
