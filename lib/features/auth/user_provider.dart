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
    state = state.copyWith(isLoading: true, error: null);

    try {
      final userData = await apiService.getCurrentUser();
      
      if (userData != null) {
        state = UserState(
          id: userData['id'],
          fullName: userData['fullName'],
          email: userData['email'],
          phoneNumber: userData['phoneNumber'],
          role: userData['role'],
          isVerified: userData['isVerified'] ?? false,
          phoneVerified: userData['phoneVerified'] ?? false,
          verificationStatus: userData['verificationStatus'] ?? 'UNVERIFIED',
          authProvider: userData['authProvider'],
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
