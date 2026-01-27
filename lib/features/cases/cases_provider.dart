import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:konektizen/features/cases/case_model.dart';

import 'package:konektizen/core/api/api_service.dart';

class CaseListNotifier extends StateNotifier<List<CaseModel>> {
  CaseListNotifier() : super([]); // Initialize empty

  Future<void> loadCases() async {
    final data = await apiService.fetchCases();
    final cases = data.map((json) => CaseModel.fromJson(json)).toList();
    state = cases;
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
