import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccessibilitySettings {
  final bool highContrast;
  final bool screenReader;

  const AccessibilitySettings({
    this.highContrast = false,
    this.screenReader = false,
  });

  AccessibilitySettings copyWith({
    bool? highContrast,
    bool? screenReader,
  }) {
    return AccessibilitySettings(
      highContrast: highContrast ?? this.highContrast,
      screenReader: screenReader ?? this.screenReader,
    );
  }
}

class AccessibilityNotifier extends StateNotifier<AccessibilitySettings> {
  AccessibilityNotifier() : super(const AccessibilitySettings());

  void toggleHighContrast(bool value) {
    state = state.copyWith(highContrast: value);
  }

  void toggleScreenReader(bool value) {
    state = state.copyWith(screenReader: value);
  }
}

final accessibilityProvider =
    StateNotifierProvider<AccessibilityNotifier, AccessibilitySettings>((ref) {
  return AccessibilityNotifier();
});
