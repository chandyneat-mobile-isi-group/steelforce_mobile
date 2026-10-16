import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/authentication/domain/entities/password_reset_grant.dart';
import 'package:steelforce/features/authentication/presentation/screens/create_new_password_screen.dart';

/// The new-password screen of the forgot-password flow checks the policy the
/// server sent with the reset token, so a weak password is caught before the
/// reset call rather than after it.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  const policy = PasswordPolicy(
    minLength: 8,
    requireUppercase: true,
    requireLowercase: true,
    requireNumber: true,
    requireSpecial: true,
  );

  Future<List<String>> pump(WidgetTester tester, {PasswordPolicy? p}) async {
    final submitted = <String>[];
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light(AppTypography.latinFontFamily),
        home: CreateNewPasswordScreen(
          policy: p,
          onSubmit: (pw) async {
            submitted.add(pw);
            return const ResetPasswordResult.success();
          },
        ),
      ),
    ));
    await tester.pump();
    return submitted;
  }

  Future<void> enter(WidgetTester tester, String pw) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), pw);
    await tester.enterText(fields.at(1), pw);
    final button = find.text('auth.reset_password_button'.tr);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  testWidgets('names the rule a weak password breaks', (tester) async {
    final submitted = await pump(tester, p: policy);

    await enter(tester, 'Ab1!');
    expect(find.text('auth.password_min_length'.trParams({'min': 8})),
        findsOneWidget);

    await enter(tester, 'abcdefg1!');
    expect(find.text('auth.password_needs_uppercase'.tr), findsOneWidget);

    await enter(tester, 'Abcdefgh1');
    expect(find.text('auth.password_needs_special'.tr), findsOneWidget);

    expect(submitted, isEmpty);
  });

  testWidgets('submits a password that meets the policy', (tester) async {
    final submitted = await pump(tester, p: policy);
    await enter(tester, 'Abcdef1!');
    expect(submitted, ['Abcdef1!']);
  });

  testWidgets('without a policy only the basic length check applies',
      (tester) async {
    final submitted = await pump(tester);
    await enter(tester, 'abcdef');
    expect(submitted, ['abcdef']);
  });
}
