import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/animations/press_scale.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/about/domain/info_topic.dart';
import 'package:steelforce/features/about/presentation/screens/info_detail_screen.dart';

/// The About & Information centre, reached by tapping the SteelForce logo.
///
/// Deliberately not a settings screen: every row here navigates to something
/// to *read*, and none of them changes state. That is why there are no
/// switches, no trailing values and no grouped-inset list — those are the
/// vocabulary of settings, and borrowing them would invite users to expect
/// controls that do not exist.
class AboutHubScreen extends StatelessWidget {
  const AboutHubScreen({super.key});

  /// Lays the topic cards out in [columns] per row.
  ///
  /// `IntrinsicHeight` so both cards in a row match the taller of the two —
  /// without it a one-line subtitle sits beside a two-line one and the row
  /// looks broken. Khmer runs longer than English for the same sentence, so
  /// that mismatch is the common case, not the rare one.
  static List<Widget> _topicRows(BuildContext context) {
    final columns = context.responsive(compact: 1, medium: 2, expanded: 2);
    if (columns == 1) {
      return [
        for (final topic in kInfoTopics) ...[
          _TopicCard(topic: topic),
          SizedBox(height: context.rh(12)),
        ],
      ];
    }

    final rows = <Widget>[];
    for (var i = 0; i < kInfoTopics.length; i += columns) {
      final slice = kInfoTopics.skip(i).take(columns).toList();
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var c = 0; c < columns; c++) ...[
              // A trailing gap on the last row keeps the final card the same
              // width as the others instead of stretching it across the row.
              Expanded(
                child: c < slice.length
                    ? _TopicCard(topic: slice[c])
                    : const SizedBox.shrink(),
              ),
              if (c < columns - 1) SizedBox(width: context.rw(12)),
            ],
          ],
        ),
      ));
      rows.add(SizedBox(height: context.rh(12)));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        iconTheme: IconThemeData(color: colors.textPrimary),
        centerTitle: true,
        title: Text(
          'about.title'.tr,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: context.rsp(17),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          // Capped and centred rather than edge-to-edge. A phone layout simply
          // stretched across a tablet gives cards a metre of empty middle and
          // subtitles that run the full width — technically responsive,
          // practically unreadable.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              // Widened alongside the type. These caps existed to stop a
              // phone layout stretching across a tablet, but they were set
              // against phone-sized text; now that type scales 1.5x, the old
              // 720 boxed the larger cards into a narrow ribbon down the
              // middle. The cap should grow with what it contains.
              maxWidth: context.responsive(
                compact: double.infinity,
                medium: 940.0,
                expanded: 1120.0,
              ),
            ),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  context.pagePadding, 4, context.pagePadding, 28),
              children: [
                const _BrandHeader(),
                SizedBox(height: context.rh(24)),
                // One column on a phone, two once there is width for them.
                // Density earned by width, rather than a longer scroll.
                ..._topicRows(context),
                SizedBox(height: context.rh(16)),
                const _Footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo, then what SteelForce is in one short paragraph, then the version.
///
/// The description lives here rather than behind an "About SteelForce" card:
/// it is two sentences, and a page of its own made the rep tap through to
/// read them.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: context.rw(20), vertical: context.rh(26)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.rr(20)),
        border: Border.all(color: colors.border),
        // The "metallic" accent, kept to a whisper: a cool wash across the
        // card rather than a literal chrome gradient, which at phone size
        // reads as a gradient bug rather than as steel.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(colors.card, scheme.primary, 0.06)!,
            colors.card,
            Color.lerp(colors.card, colors.slate, 0.04)!,
          ],
        ),
      ),
      child: Column(
        children: [
          // The launcher icon itself, rounded in its own artwork, so it reads
          // as the same mark the rep taps to open the app. Decorative: the
          // description below names SteelForce, so announcing the mark as
          // well adds noise.
          ExcludeSemantics(
            child: SvgPicture.asset(
              'assets/logos/steelforce/steelforce_icon.svg',
              width: context.rr(80),
              height: context.rr(80),
            ),
          ),
          SizedBox(height: context.rh(18)),
          Text(
            'about.detail.about.s1.b1'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: context.rsp(14.5),
              height: context.rh(1.6),
            ),
          ),
          SizedBox(height: context.rh(14)),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: context.rw(12), vertical: context.rh(5)),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(context.rr(20)),
            ),
            child: Text(
              '${'about.version_label'.tr} $kAppVersion',
              style: TextStyle(
                color: scheme.primary,
                fontSize: context.rsp(11.5),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic});

  final InfoTopic topic;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return PressScale(
      onTap: () => Navigator.of(context).push(
        PageRouteBuilder(
          transitionDuration: AppDurations.page,
          reverseTransitionDuration: AppDurations.page,
          pageBuilder: (_, __, ___) => InfoDetailScreen(topic: topic),
          // Slide in from the trailing edge — the platform idiom for moving
          // deeper into a hierarchy, and it reverses correctly on back.
          transitionsBuilder: (_, animation, __, child) => SlideTransition(
            position: Tween(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: AppCurves.emphasized,
            )),
            child: child,
          ),
        ),
      ),
      child: Semantics(
        button: true,
        label: topic.titleKey.tr,
        hint: topic.descKey.tr,
        child: Container(
          // 76dp minimum on a phone, scaling with the box scale on larger
          // screens — comfortably past the 48dp floor for a row people tap
          // while walking a warehouse, and it grows with the type inside it.
          constraints: BoxConstraints(minHeight: context.rh(76)),
          padding: EdgeInsets.symmetric(
              horizontal: context.rw(16), vertical: context.rh(14)),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(context.rr(18)),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: colors.shadowColor.withValues(alpha: 0.05),
                blurRadius: context.rr(18),
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: context.rw(42),
                height: context.rh(42),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(context.rr(13)),
                ),
                child: Icon(topic.icon,
                    size: context.rr(20), color: scheme.primary),
              ),
              SizedBox(width: context.rw(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      topic.titleKey.tr,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: context.rsp(15),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: context.rh(4)),
                    Text(
                      topic.descKey.tr,
                      // Two lines, then ellipsis: Khmer runs longer than
                      // English for the same sentence, and an unbounded
                      // subtitle would make the cards different heights
                      // depending on the language.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: context.rsp(12.5),
                        height: context.rh(1.4),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: context.rw(8)),
              Icon(Icons.chevron_right_rounded,
                  size: context.rr(22), color: colors.iconMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      children: [
        Text(
          'SteelForce',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: context.rsp(14),
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
        SizedBox(height: context.rh(6)),
        Text(
          'Version $kAppVersion',
          style: TextStyle(color: colors.textHint, fontSize: context.rsp(12)),
        ),
        SizedBox(height: context.rh(4)),
        Text(
          'about.copyright'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textHint, fontSize: context.rsp(11.5)),
        ),
      ],
    );
  }
}
