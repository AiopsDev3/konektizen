import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:konektizen/features/cases/case_model.dart';
import 'package:konektizen/core/api/api_service.dart';
import 'package:konektizen/features/sos_video_call/signaling_service.dart';

class CaseListNotifier extends StateNotifier<List<CaseModel>> {
  CaseListNotifier() : super([]); // Initialize empty

  Future<void> loadCases() async {
    final data = await apiService.fetchCases();
    final cases = data.map((json) => CaseModel.fromJson(json)).toList();
    state = cases;
    _setupSocketListener();
  }

  void _setupSocketListener() async {
    try {
      final user = await apiService.getCurrentUser();
      final userId = user?['_id'] ?? user?['id'] ?? user?['user']?['id'] ?? user?['user']?['_id'];
      if (userId != null) {
        final signaling = SignalingService.instance;
        if (signaling.currentReporterId != userId.toString() ||
            signaling.socket == null ||
            !signaling.socket!.connected) {
          print('[CaseListNotifier] Initializing socket listener for user $userId');
          signaling.listenForIncomingCall(userId.toString());
        }
        signaling.onCaseUpdated = (payload) {
          print('[CaseListNotifier] case_updated socket notification received, reloading cases');
          loadCases();
        };
      }
    } catch (e) {
      print('[CaseListNotifier] Error setting up socket listener: $e');
    }
  }

  void addCase(CaseModel newCase) {
    state = [newCase, ...state];
  }
}

final caseListProvider = StateNotifierProvider<CaseListNotifier, List<CaseModel>>((ref) {
  final notifier = CaseListNotifier();
  notifier.loadCases(); // Auto-load
  return notifier;
});
