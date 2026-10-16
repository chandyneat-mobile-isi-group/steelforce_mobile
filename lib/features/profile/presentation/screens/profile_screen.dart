import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_event.dart';
import 'package:steelforce/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:steelforce/features/profile/presentation/bloc/profile_state.dart';
import 'package:steelforce/features/profile/presentation/widgets/edit_profile_sheet.dart';
import 'package:steelforce/features/profile/presentation/widgets/profile_header.dart';
import 'package:steelforce/features/profile/presentation/widgets/profile_info_section.dart';
import 'package:steelforce/features/profile/presentation/widgets/unsent_work_dialog.dart';
import 'package:steelforce/features/localization/presentation/bloc/language_cubit.dart';
import 'package:steelforce/features/localization/presentation/widgets/language_selector_sheet.dart';
import 'package:steelforce/features/profile/presentation/widgets/profile_details_dialog.dart';
import 'package:steelforce/features/profile/presentation/widgets/profile_menu.dart';
import 'package:steelforce/features/settings/theme/presentation/cubit/theme_cubit.dart';
import 'package:steelforce/features/settings/theme/presentation/cubit/theme_state.dart';
import 'package:steelforce/features/settings/theme/presentation/widgets/theme_option_meta.dart';
import 'package:steelforce/features/settings/theme/presentation/widgets/theme_selector_sheet.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/pending_sync_sheet.dart';
import 'package:steelforce/routes/app_routes.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ProfileCubit>().load();
  }

  Future<void> _openEditor(BuildContext context, ProfileLoaded state) async {
    final saved = await showEditProfileSheet(
      context: context,
      profile: state.profile,
      cubit: context.read<ProfileCubit>(),
      imageCapture: sl<ImageCaptureService>(),
    );
    if (saved != true || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Text('profile.updated_success'.tr),
    ));
  }

  Future<void> _confirmLogout(BuildContext context) async {
    // Sign-out wipes the device, so anything not yet on the server has to go
    // first. The rep is taken to the Sync Center to send it; until it is gone
    // there is no sign-out to confirm.
    final cubit = context.read<ProfileCubit>();
    final unsent = await cubit.unsentWork();
    if (!context.mounted) return;
    if (unsent.isNotEmpty) {
      final openSync =
          await showUnsentWorkDialog(context: context, initial: unsent);
      if (openSync != true || !context.mounted) return;
      await showPendingSyncSheet(context);
      if (!context.mounted) return;
      // Everything sent while the sheet was open: carry on to the sign-out.
      final left = await cubit.unsentWork();
      if (left.isNotEmpty || !context.mounted) return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appColors.surfaceSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('profile.logout_confirm_title'.tr,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text('profile.logout_confirm_body'.tr,
            style: TextStyle(color: context.appColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('profile.cancel'.tr)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('profile.logout'.tr)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    context.read<AuthBloc>().add(const LogoutRequested());
  }

  /// The menu shared by both layouts. A tablet already shows the details
  /// inline, so only a phone gets the row that opens them.
  Widget _menu(BuildContext context, ProfileLoaded state,
      {required bool withDetails}) {
    return ProfileMenuCard(
      logoutLabel: 'profile.logout'.tr,
      onLogout: () => _confirmLogout(context),
      tiles: [
        if (withDetails)
          ProfileMenuTile(
            icon: Icons.badge_outlined,
            title: 'profile.my_details'.tr,
            subtitle: state.profile.email,
            onTap: () => showProfileDetailsDialog(context),
          ),
        BlocBuilder<ThemeCubit, ThemeState>(
          builder: (context, theme) => ProfileMenuTile(
            icon: theme.mode.icon,
            title: 'appearance.title'.tr,
            subtitle: theme.mode.labelKey.tr,
            onTap: () => showThemeSelectorSheet(context),
          ),
        ),
        BlocBuilder<LanguageCubit, Locale>(
          builder: (context, locale) {
            final supported = context.read<LanguageCubit>().supportedLanguages;
            final language = supported.firstWhere(
              (l) => l.code == locale.languageCode,
              orElse: () => supported.first,
            );
            return ProfileMenuTile(
              icon: Icons.translate_rounded,
              title: 'settings.language_title'.tr,
              subtitle: language.nameKey.tr,
              leadingSubtitle: Text(language.flag,
                  style: TextStyle(fontSize: context.rsp(13))),
              onTap: () => showLanguageSelectorSheet(context),
            );
          },
        ),
        ProfileMenuTile(
          icon: Icons.lock_reset_rounded,
          title: 'profile.change_password'.tr,
          subtitle: 'profile.change_password_hint'.tr,
          onTap: () => Navigator.of(context).pushNamed(Static.forgotPassword),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LocalizedBuilder(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final screenWidth = MediaQuery.sizeOf(context).width;
        final isTablet = screenWidth >= 600;

        return Scaffold(
          // The shell's canvas, matching Home and the tabs.
          backgroundColor: context.appColors.canvas,
          appBar: AppBar(
            backgroundColor: context.appColors.canvas,
            iconTheme: IconThemeData(color: scheme.onSurface),
            title: Text(
              'profile.title'.tr,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: context.rsp(17),
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          body: BlocConsumer<ProfileCubit, ProfileState>(
            listener: (context, state) {
              if (state is ProfileLoaded && state.actionError != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    content: Text(state.actionError!)));
              }
            },
            builder: (context, state) => switch (state) {
              ProfileLoaded() => RefreshIndicator(
                  color: scheme.primary,
                  onRefresh: () => context.read<ProfileCubit>().load(),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isTablet ? 960 : double.infinity,
                      ),
                      child: isTablet
                          ? _buildTabletLayout(context, state)
                          : _buildPhoneLayout(context, state),
                    ),
                  ),
                ),
              ProfileError(:final message) => Center(
                  child: Text(message,
                      style:
                          TextStyle(color: context.appColors.textSecondary))),
              _ =>
                Center(child: CircularProgressIndicator(color: scheme.primary)),
            },
          ),
        );
      },
    );
  }

  // Phone: who you are, then one card of places to go, then sign-out.
  // Details sit one tap down so the menu starts above the fold.
  Widget _buildPhoneLayout(BuildContext context, ProfileLoaded state) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
          context.rw(16), context.rh(16), context.rw(16), context.rh(32)),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.rw(4)),
          child: ProfileHeader(
            profile: state.profile,
            onEdit: state.isSaving ? null : () => _openEditor(context, state),
          ),
        ),
        SizedBox(height: context.rh(24)),
        _menu(context, state, withDetails: true),
      ],
    );
  }

  // Tablet: the identity card stays put on the left; details and the menu
  // scroll on the right, so there is room to show the details inline.
  Widget _buildTabletLayout(BuildContext context, ProfileLoaded state) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 300,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.border),
              ),
              child: ProfileHeader(
                profile: state.profile,
                isTablet: true,
                onEdit:
                    state.isSaving ? null : () => _openEditor(context, state),
              ),
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: ListView(
              children: [
                ProfileInfoSection(profile: state.profile),
                const SizedBox(height: 24),
                _menu(context, state, withDetails: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
