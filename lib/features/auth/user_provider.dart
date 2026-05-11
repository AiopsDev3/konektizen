import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:konektizen/core/api/api_service.dart';

/// User state model
class UserState {
  final String? id;
  final String? fullName;
  final String? email;
  final String? phoneNumber;
  final String? role;
  final bool? isVerified;
  final bool phoneVerified;
  final String verificationStatus;
  final bool isLoading;
  final String? error;

  const UserState({
    this.id,
    this.fullName,
    this.email,
    this.phoneNumber,
    this.role,
    this.isVerified = false,
    this.phoneVerified = false,
    this.verificationStatus = 'UNVERIFIED',
    this.authProvider,
    this.isLoading = false,
    this.error,
  });

  final String? authProvider;

  bool get isPhoneAuth => authProvider == 'PHONE';

  UserState copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? role,
    bool? isVerified,
    bool? phoneVerified,
    String? verificationStatus,
    String? authProvider,
    bool? isLoading,
    String? error,
  }) {
    return UserState(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      isVerified: isVerified ?? this.isVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      authProvider: authProvider ?? this.authProvider,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool get isAuthenticated => id != null;
}

/// User notifier to manage authenticated user state
class UserNotifier extends StateNotifier<UserState> {
  UserNotifier() : super(const UserState());

  /// Load current authenticated user from backend
  Future<void> loadCurrentUser() async {
    final token = await apiService.getToken();
    if (token == null || token.isEmpty) {
      state = const UserState();
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final userData = await apiService.getCurrentUser();
      
      if (userData != null) {
        final rawStatus = (userData['verificationStatus'] ??
                userData['verification_status'] ??
                'UNVERIFIED')
            .toString()
            .toUpperCase();
        final verified = userData['isVerified'] ??
            userData['is_verified'] ??
            rawStatus == 'APPROVED';
        state = UserState(
          id: userData['id']?.toString(),
          fullName: userData['fullName'] ?? userData['full_name'],
          email: userData['email'],
          phoneNumber: userData['phoneNumber'] ?? userData['phone_number'],
          role: userData['role'] ?? 'reporter',
          isVerified: verified == true,
          phoneVerified:
              userData['phoneVerified'] ?? userData['phone_verified'] ?? false,
          verificationStatus: rawStatus,
          authProvider: userData['authProvider'] ?? userData['auth_provider'],
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load user data',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Logout user
  Future<void> logout() async {
    await apiService.logout();
    state = const UserState();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for user state
final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier();
});
