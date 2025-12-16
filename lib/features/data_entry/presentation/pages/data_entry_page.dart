import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/state/daily_log_provider.dart';
import '../../../../core/state/weekly_log_provider.dart';
import '../../../../shared/widgets/app_drawer.dart';

// ✅ ADD THIS IMPORT


@RoutePage()
class DataEntryPage extends ConsumerStatefulWidget {
  const DataEntryPage({super.key});

  @override
  ConsumerState<DataEntryPage> createState() => _DataEntryPageState();
}

class _DataEntryPageState extends ConsumerState<DataEntryPage> {
  // Biomarker controllers
  final TextEditingController _glucoseController = TextEditingController();
  final TextEditingController _bhbController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  @override
  void dispose() {
    _glucoseController.dispose();
    _bhbController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Biomarkers'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'Daily Biomarkers',
              'Log your metabolic measurements',
              Icons.science,
            ),
            const SizedBox(height: 16),
            _buildBiomarkerInputSection(),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor.withOpacity(0.1), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiomarkerInputSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildBiomarkerInputCard(
                'Glucose',
                'mg/dL',
                _glucoseController,
                Colors.orange.shade600,
                'Target: <100',
                Icons.water_drop,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBiomarkerInputCard(
                'BHB',
                'mmol/L',
                _bhbController,
                Colors.yellow.shade700,
                'Target: >0.5',
                Icons.science,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildBiomarkerInputCard(
                'Weight',
                'kg',
                _weightController,
                Colors.blue.shade600,
                'Optional',
                Icons.scale,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.calculate, color: AppTheme.primaryColor),
                    const SizedBox(height: 8),
                    Text(
                      'GKI auto-calculated from glucose & BHB',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBiomarkerInputCard(
      String label,
      String unit,
      TextEditingController controller,
      Color color,
      String target,
      IconData icon,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              hintText: '0.0',
              suffixText: unit,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            target,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saveData,
            icon: const Icon(Icons.save),
            label: const Text('Save Biomarker Data'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _clearData,
            icon: const Icon(Icons.clear),
            label: const Text('Clear All'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _saveData() {
    final glucose = _parseDouble(_glucoseController.text);
    final bhb = _parseDouble(_bhbController.text);
    final weightText = _weightController.text.trim();
    final weight = weightText.isEmpty ? null : _parseDouble(weightText);

    ref.read(dailyLogProvider.notifier).setBiomarkers(
      glucoseMgDl: glucose,
      bhbMmol: bhb,
      weightKg: weight,
    );
    ref.read(weeklyLogProvider.notifier).upsertBiomarkersForToday(
      glucoseMgDl: glucose,
      bhbMmol: bhb,
      weightKg: weight,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Biomarker data saved successfully!'),
        backgroundColor: AppTheme.primaryColor,
        action: SnackBarAction(
          label: 'View Dashboard',
          textColor: Colors.white,
          onPressed: () => context.router.pushNamed('/dashboard'),
        ),
      ),
    );

    _clearInputs();
  }

  void _clearData() {
    ref.read(dailyLogProvider.notifier).clearBiomarkers();
    ref.read(weeklyLogProvider.notifier).clearBiomarkersForToday();
    _clearInputs();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All fields cleared'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _clearInputs() {
    _glucoseController.clear();
    _bhbController.clear();
    _weightController.clear();
  }

  double _parseDouble(String input) {
    final normalized = input.trim();
    if (normalized.isEmpty) return 0;
    return double.tryParse(normalized) ?? 0;
  }
}
