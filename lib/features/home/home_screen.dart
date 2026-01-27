import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/theme/app_theme.dart';
import 'package:konektizen/features/cases/cases_provider.dart';
import 'package:konektizen/features/cases/case_model.dart';
import 'package:konektizen/features/auth/user_provider.dart';
import 'dart:async';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentLanguageIndex = 0;
  Timer? _languageTimer;

  // Rotating text in different Philippine languages
  final List<Map<String, String>> _languageTexts = [
    {
      'question': 'Ano ang nangyayari sa inyong lugar?',
      'hint': 'Ilarawan ang problema (hal., "May butas sa kalsada")',
      'language': 'Tagalog'
    },
    {
      'question': 'Ano ang nagakalatabo sa inyo nga lugar?',
      'hint': 'Iladawan ang problema (hal., "May guba sa dalan")',
      'language': 'Hiligaynon'
    },
    {
      'question': 'Unsa ang nahitabo sa inyong lugar?',
      'hint': 'Ihulagway ang problema (hal., "May lungag sa dalan")',
      'language': 'Cebuano'
    },
  ];

  @override
  void initState() {
    super.initState();
    // Rotate language every 4 seconds
    // Rotate language every 4 seconds
    _languageTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentLanguageIndex = (_currentLanguageIndex + 1) % _languageTexts.length;
        });
      }
    });

    // Check verification status
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVerificationStatus();
    });
  }

  void _checkVerificationStatus() {
    final user = ref.read(userProvider);
    if (!user.isAuthenticated) return;

    // If not verified and not pending, prompt user
    if ((user.isVerified == false) && user.verificationStatus != 'PENDING') {
       _showVerificationDialog();
    }
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.verified_user_outlined, color: AppTheme.primary),
            const SizedBox(width: 8),
            const Text('Verify Account'),
          ],
        ),
        content: const Text(
          'Your account is not verified yet. Verify your identity to unlock all features and report incidents effectively.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Maybe Later', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/verify-id');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Verify Now'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _languageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for authentication state changes to prompt for verification
    ref.listen(userProvider, (previous, next) {
      if (!next.isLoading && next.isAuthenticated) {
        // If we just finished loading or just logged in
        if (previous?.isLoading == true || previous?.isAuthenticated != true) {
          // Use the captured context to show dialog
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _checkVerificationStatus();
          });
        }
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              _buildAIPrompt(context),
              _buildQuickCategories(context),
              _buildEmergencySOSBanner(context),
              _buildActiveReports(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KONEKTIZEN',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Good Morning, Citizen', // Placeholder user name
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          CircleAvatar(
            backgroundColor: AppTheme.secondary.withOpacity(0.1),
            child: const Icon(Icons.notifications_none, color: AppTheme.secondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAIPrompt(BuildContext context) {
    final currentText = _languageTexts[_currentLanguageIndex];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppTheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'AI Assistant',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const Spacer(),
              // Language indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  currentText['language']!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Text(
              currentText['question']!,
              key: ValueKey<int>(_currentLanguageIndex),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Only Mic Button, no text field
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.mic, color: AppTheme.primary),
                onPressed: () {
                  // TODO: Voice Input
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCategories(BuildContext context) {
    // UPDATED: Tagalog labels and replaced City Updates with "Mag-ulat" (Report)
    final categories = [
      {'icon': Icons.delete_outline, 'label': 'Basura', 'category_key': 'BASURA', 'color': AppTheme.secondary}, 
      {'icon': Icons.add_road, 'label': 'Kalsada', 'category_key': 'KALSADA', 'color': AppTheme.primary}, 
      {'icon': Icons.water_drop_outlined, 'label': 'Pagbaha', 'category_key': 'PAGBAHA', 'color': Colors.blue},
      {'icon': Icons.lightbulb_outline, 'label': 'Ilaw sa Kalye', 'category_key': 'ILAW_SA_KALYE', 'color': AppTheme.tertiary}, 
      {'icon': Icons.traffic, 'label': 'Trapiko', 'category_key': 'TRAPIKO', 'color': Colors.red},
      // New "Mag-ulat" tile instead of City Updates
      {'icon': Icons.assignment_add, 'label': 'Mag-ulat', 'category_key': 'IBA_PA', 'color': Colors.purple, 'isReport': true},
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mabilis na Ulat', // Translated "Quick Report"
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.1,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final item = categories[index];
              return InkWell(
                onTap: () {
                   if (item['isReport'] == true) {
                     // Go to general report or category selection
                     context.push('/report'); 
                   } else {
                     // Pass the specific category key
                     context.push('/report?category=${item['category_key']}');
                   }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (item['color'] as Color).withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (item['color'] as Color).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item['icon'] as IconData, 
                          color: item['color'] as Color
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['label'] as String,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // UPDATED: This is now the "City Updates" banner instead of SOS
  Widget _buildEmergencySOSBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GestureDetector(
        onTap: () {
           context.push('/home/city-updates');
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green, // Green for City Updates
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.campaign, 
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MGA ABISO NG LUNGSOD', // Translated
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tingnan ang mga anunsyo ng lungsod.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveReports(BuildContext context) {
    final allCases = ref.watch(caseListProvider);
    final activeCases = allCases.where((c) => c.status != CaseStatus.resolved).toList();
    final recentCases = activeCases.take(3).toList(); // Show top 3 recent active ones

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Aktibong mga Report',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (activeCases.isNotEmpty)
                TextButton(
                  onPressed: () {
                    // Navigate to My Cases tab (index 2 in shell)
                    StatefulNavigationShell.of(context).goBranch(2);
                  },
                  child: Text(
                    'Tingnan Lahat',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (recentCases.isEmpty)
            _buildEmptyState(context)
          else
            Column(
              children: recentCases.map((item) => _buildCaseItem(context, item)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'Walang aktibong report',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          TextButton(
            onPressed: () {
               StatefulNavigationShell.of(context).goBranch(2);
            },
            child: const Text('Suriin ang History'),
          ),
        ],
      ),
    );
  }

  Widget _buildCaseItem(BuildContext context, dynamic item) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () {
           context.push('/my-cases/detail/${item.id}');
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.description_outlined, color: AppTheme.primary),
        ),
        title: Text(
          item.category,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          item.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(item.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            item.statusLabel.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _getStatusColor(item.status),
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(dynamic status) {
    switch (status) {
      case CaseStatus.submitted: return Colors.blue;
      case CaseStatus.validated: return Colors.orange;
      case CaseStatus.inProgress: return Colors.purple;
      case CaseStatus.resolved: return Colors.green;
      default: return Colors.grey;
    }
  }
}
