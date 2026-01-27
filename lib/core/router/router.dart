import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/features/onboarding/onboarding_screen.dart';
import 'package:konektizen/features/home/home_screen.dart';
import 'package:konektizen/features/home/city_updates_screen.dart';
import 'package:konektizen/features/shell/shell_screen.dart';
import 'package:konektizen/features/report/report_description_screen.dart';
import 'package:konektizen/features/report/report_category_screen.dart';
import 'package:konektizen/features/report/report_evidence_screen.dart';
import 'package:konektizen/features/report/report_submit_screen.dart';
import 'package:konektizen/features/report/submission_success_screen.dart';
import 'package:konektizen/features/cases/my_cases_screen.dart';
import 'package:konektizen/features/cases/case_detail_screen.dart';
import 'package:konektizen/features/profile/profile_screen.dart';

import 'package:konektizen/features/verification/residency_verification_screen.dart';
import 'package:konektizen/features/auth/login_screen.dart';
import 'package:konektizen/features/auth/register_screen.dart';
import 'package:konektizen/features/auth/phone_login_screen.dart';
import 'package:konektizen/features/auth/otp_verification_screen.dart';
import 'package:konektizen/features/auth/phone_profile_completion_screen.dart';
import 'package:konektizen/features/sos/sos_confirmation_screen.dart';
import 'package:konektizen/features/profile/edit_profile_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _sectionNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const OnboardingScreen(),
      routes: [
         GoRoute(
          path: 'auth/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: 'auth/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: 'auth/phone-login',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return PhoneLoginScreen(
              isRegister: extra?['isRegister'] ?? false,
            );
          },
        ),
        GoRoute(
          path: 'auth/verify-otp',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>;
            return OTPVerificationScreen(
              phoneNumber: extra['phoneNumber'],
              verificationId: extra['verificationId'],
              isRegister: extra['isRegister'] ?? false,
            );
          },
        ),
        GoRoute(
          path: 'auth/complete-profile',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>;
            return PhoneProfileCompletionScreen(
              firebaseUid: extra['firebaseUid'],
              phoneNumber: extra['phoneNumber'],
            );
          },
        ),
      ]
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ShellScreen(navigationShell: navigationShell);
      },
      branches: [
        // Home Branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'city-updates',
                  parentNavigatorKey: _rootNavigatorKey,
                   builder: (context, state) => const CityUpdatesScreen(),
                ),
              ],
            ),
          ],
        ),
        // My Cases Branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/my-cases',
              builder: (context, state) => const MyCasesScreen(),
              routes: [
                GoRoute(
                  path: 'detail/:id',
                  parentNavigatorKey: _rootNavigatorKey, // Hide bottom nav on detail
                  builder: (context, state) {
                    final id = state.pathParameters['id'] ?? '';
                    return CaseDetailScreen(caseId: id);
                  },
                ),
              ],
            ),
          ],
        ),
         // Profile Branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'edit',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const EditProfileScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    // SOS Full Screen Route
    GoRoute(
      path: '/sos',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SOSConfirmationScreen(),
    ),
    // Moved Report to top-level route (triggered from Home Grid)
    GoRoute(
      path: '/report',
      parentNavigatorKey: _rootNavigatorKey, // Full screen, no bottom nav
      builder: (context, state) {
        final startQuery = state.uri.queryParameters['query'];
        final category = state.uri.queryParameters['category'];
        return ReportDescriptionScreen(
          initialQuery: startQuery,
          initialCategory: category,
        );
      },
      routes: [
        GoRoute(
          path: 'category',
          builder: (context, state) {
            final description = state.uri.queryParameters['description'] ?? '';
            return ReportCategoryScreen(description: description);
          },
        ),
          GoRoute(
          path: 'evidence',
          builder: (context, state) => const ReportEvidenceScreen(),
        ),
        GoRoute(
          path: 'submit',
          builder: (context, state) => const ReportSubmitScreen(),
        ),
        GoRoute(
          path: 'success',
          builder: (context, state) => const SubmissionSuccessScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/verify-id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ResidencyVerificationScreen(),
    ),
  ],
);
