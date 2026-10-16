part of '../stops_check_in_screen.dart';

class _CameraDropzone extends StatelessWidget {
  const _CameraDropzone({
    required this.photos,
    required this.capturing,
    required this.isLocked,
    required this.onTap,
  });

  final List<VisitPhoto> photos;
  final bool capturing;
  final bool isLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final borderColor = isLocked
        ? colors.border
        : (photos.isNotEmpty
            ? colors.success
            : scheme.primary.withValues(alpha: 0.5));

    return GestureDetector(
      onTap: (capturing || isLocked) ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isLocked ? 0.55 : 1.0,
        child: CustomPaint(
          painter: _DashedBorderPainter(color: borderColor, radius: 16),
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isLocked
                  ? colors.surfaceSoft
                  : scheme.primary.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
            ),
            child: capturing
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: scheme.primary,
                    ),
                  )
                : photos.isEmpty
                    ? _DropzonePlaceholder(isLocked: isLocked)
                    : _ProofGallery(photos: photos),
          ),
        ),
      ),
    );
  }
}

class _DropzonePlaceholder extends StatelessWidget {
  const _DropzonePlaceholder({required this.isLocked});
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 48,
          height: context.rh(48),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (isLocked ? colors.textSecondary : scheme.primary)
                .withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isLocked ? Icons.lock_outline_rounded : Icons.camera_alt_rounded,
            color: isLocked ? colors.textSecondary : scheme.primary,
            size: context.rr(22),
          ),
        ),
        SizedBox(height: context.rh(10)),
        Text(
          isLocked
              ? 'my_visits.flow.transit_banner_locked'.tr
              : 'my_visits.flow.take_photo'.tr,
          style: TextStyle(
            color: isLocked ? colors.textSecondary : colors.textPrimary,
            fontSize: context.rsp(13.5),
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: context.rh(3)),
        Text(
          'my_visits.flow.fit_frame'.tr,
          style: TextStyle(
              color: colors.textSecondary, fontSize: context.rsp(11.5)),
        ),
      ],
    );
  }
}

class _ProofGallery extends StatelessWidget {
  const _ProofGallery({required this.photos});
  final List<VisitPhoto> photos;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.all(context.rr(10)),
          itemCount: photos.length,
          separatorBuilder: (_, __) => SizedBox(width: context.rw(10)),
          itemBuilder: (context, index) => ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 1,
              child: localFileImage(photos[index].url, fit: BoxFit.cover),
            ),
          ),
        ),
        Positioned(
          right: 14,
          top: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_a_photo_rounded,
                  color: Colors.white,
                  size: context.rr(13),
                ),
                SizedBox(width: context.rw(5)),
                Text(
                  '${photos.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: context.rsp(11.5),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PulseIndicator extends StatefulWidget {
  @override
  State<_PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.1 + (_controller.value * 0.15)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'REQUIRED',
          style: TextStyle(
            color: primary.withValues(alpha: 0.75 + (_controller.value * 0.25)),
            fontSize: context.rsp(9.5),
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final rrect =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    // PathMetrics.extractPath per dash overflows the stack on web; the
    // polyline walker draws the same border with no lazy Path involved.
    drawDashedRRect(canvas, rrect, paint, dash: 6.0, gap: 4.0);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
