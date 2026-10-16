import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/about/domain/info_topic.dart';

/// The detail page behind every card on the About hub.
class InfoDetailScreen extends StatelessWidget {
  const InfoDetailScreen({super.key, required this.topic});

  final InfoTopic topic;

  /// Security guidance carries a highlighted warning; nothing else does.
  bool get _hasSecurityCallout => topic.id == 'security';

  /// Check if this is the support topic to show contact options & feedback form.
  bool get _isSupport => topic.id == 'support' || topic.id == 'help';

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Text(
          topic.titleKey.tr,
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
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.responsive(
                compact: double.infinity,
                medium: 880.0,
                expanded: 960.0,
              ),
            ),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  context.pagePadding, 8, context.pagePadding, 32),
              children: [
                if (_hasSecurityCallout) ...[
                  _Callout(
                    title: 'about.stay_secure_title'.tr,
                    body: 'about.stay_secure_body'.tr,
                    color: scheme.primary,
                  ),
                  SizedBox(height: context.rh(20)),
                ],
                for (final section in topic.sections) ...[
                  _Section(topic: topic, section: section),
                  SizedBox(height: context.rh(22)),
                ],

                // Inject Support & Feedback options on the Help & Support page
                if (_isSupport) ...[
                  const _SupportContactSection(),
                  SizedBox(height: context.rh(32)),
                ],

                SizedBox(height: context.rh(4)),
                Center(
                  child: Text(
                    '${'about.last_updated'.tr} · 19 Aug 2026',
                    style: TextStyle(
                      color: colors.textHint,
                      fontSize: context.rsp(12),
                      fontWeight: FontWeight.w500,
                    ),
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

class _Section extends StatelessWidget {
  const _Section({required this.topic, required this.section});

  final InfoTopic topic;
  final InfoSection section;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final single = section.bulletCount == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          topic.sectionTitleKey(section).tr,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: context.rsp(16),
            fontWeight: FontWeight.w800,
            height: context.rh(1.3),
          ),
        ),
        SizedBox(height: context.rh(10)),
        for (var i = 1; i <= section.bulletCount; i++)
          Padding(
            padding: EdgeInsets.only(bottom: single ? 0 : context.rh(9)),
            child: single
                ? Text(
                    topic.bulletKey(section, i).tr,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(14.5),
                      height: context.rh(1.6),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: EdgeInsets.only(
                            top: context.rh(8), right: context.rw(10)),
                        width: context.rw(5),
                        height: context.rh(5),
                        decoration: BoxDecoration(
                          color: colors.textHint,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          topic.bulletKey(section, i).tr,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: context.rsp(14.5),
                            height: context.rh(1.55),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({
    required this.title,
    required this.body,
    required this.color,
  });

  final String title, body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.all(context.rr(16)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(context.rr(16)),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: color, size: context.rr(20)),
          SizedBox(width: context.rw(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: context.rsp(14),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: context.rh(5)),
                Text(
                  body,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: context.rsp(13.5),
                    height: context.rh(1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dedicated contact methods and Feedback trigger
class _SupportContactSection extends StatelessWidget {
  const _SupportContactSection();

  void _openFeedbackSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _FeedbackBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact & Support',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: context.rsp(16),
            fontWeight: FontWeight.w800,
            height: context.rh(1.3),
          ),
        ),
        SizedBox(height: context.rh(12)),

        // Mock Phone Call
        _ContactMethodCard(
          icon: Icons.phone_in_talk_rounded,
          title: 'Phone Hotline',
          subtitle: '+855 23 888 888 (Mon-Fri, 8AM - 5PM)',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Calling +855 23 888 888...')),
            );
          },
        ),
        SizedBox(height: context.rh(10)),

        // Mock Email
        _ContactMethodCard(
          icon: Icons.alternate_email_rounded,
          title: 'Email Support',
          subtitle: 'support@isisteel.com.kh',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Opening mail client...')),
            );
          },
        ),
        SizedBox(height: context.rh(10)),

        // Mock Telegram
        _ContactMethodCard(
          icon: Icons.send_rounded,
          title: 'Telegram Support',
          subtitle: '@isisteel_support',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Opening Telegram channel...')),
            );
          },
        ),
        SizedBox(height: context.rh(10)),

        // Feedback Form Launcher
        _ContactMethodCard(
          icon: Icons.rate_review_outlined,
          title: 'Give App Feedback',
          subtitle: 'Rate your experience and share thoughts',
          onTap: () => _openFeedbackSheet(context),
        ),
      ],
    );
  }
}

/// Contact Option Tile
class _ContactMethodCard extends StatelessWidget {
  const _ContactMethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.rr(14)),
        child: Ink(
          padding: EdgeInsets.symmetric(
              horizontal: context.rw(16), vertical: context.rh(14)),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(context.rr(14)),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: colors.shadowColor.withValues(alpha: 0.04),
                blurRadius: context.rr(12),
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.rr(10)),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: context.rr(20),
                  color: scheme.primary,
                ),
              ),
              SizedBox(width: context.rw(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: context.rsp(14.5),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: context.rh(2)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: context.rsp(12.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: context.rr(20),
                color: colors.iconMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Interactive Bottom Sheet Form with Star Rating & Free Text Field
class _FeedbackBottomSheet extends StatefulWidget {
  const _FeedbackBottomSheet();

  @override
  State<_FeedbackBottomSheet> createState() => _FeedbackBottomSheetState();
}

class _FeedbackBottomSheetState extends State<_FeedbackBottomSheet> {
  int _rating = 5;
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submitFeedback() {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Thank you for your feedback! ($_rating ★)'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: EdgeInsets.all(context.rr(20)),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(context.rr(24)),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: context.rw(40),
                  height: context.rh(4),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(context.rr(2)),
                  ),
                ),
              ),
              SizedBox(height: context.rh(16)),
              Text(
                'Send Us Feedback',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: context.rsp(18),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: context.rh(4)),
              Text(
                'How was your experience using the app?',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: context.rsp(13),
                ),
              ),
              SizedBox(height: context.rh(16)),

              // Interactive Star Rating Widget
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return IconButton(
                    onPressed: () => setState(() => _rating = starIndex),
                    icon: Icon(
                      starIndex <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: starIndex <= _rating
                          ? Colors.amber.shade600
                          : colors.iconMuted,
                      size: context.rr(32),
                    ),
                  );
                }),
              ),
              SizedBox(height: context.rh(16)),

              // Note / Free Text Field
              TextField(
                controller: _noteController,
                maxLines: 4,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: context.rsp(14),
                ),
                decoration: InputDecoration(
                  hintText: 'Describe any technical issues or suggestions...',
                  hintStyle: TextStyle(
                    color: colors.textHint,
                    fontSize: context.rsp(13.5),
                  ),
                  filled: true,
                  fillColor: colors.surfaceSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.rr(12)),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.rr(12)),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.rr(12)),
                    borderSide: BorderSide(color: scheme.primary, width: 1.5),
                  ),
                ),
              ),
              SizedBox(height: context.rh(20)),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitFeedback,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    padding: EdgeInsets.symmetric(vertical: context.rh(14)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(context.rr(12)),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Submit Feedback',
                    style: TextStyle(
                      fontSize: context.rsp(15),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
