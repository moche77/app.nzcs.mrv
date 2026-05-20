import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/data_models.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class EmissionFactorsScreen extends StatefulWidget {
  const EmissionFactorsScreen({super.key});

  @override
  State<EmissionFactorsScreen> createState() => _EmissionFactorsScreenState();
}

class _EmissionFactorsScreenState extends State<EmissionFactorsScreen> {
  late TextEditingController _carbon;
  late TextEditingController _permanence;
  late TextEditingController _co2;
  late TextEditingController _grid;
  late TextEditingController _fuel;
  late TextEditingController _conv;

  @override
  void initState() {
    super.initState();
    final f = context.read<DataService>().emissionFactors;
    _carbon = TextEditingController(text: f.defaultCarbonPct.toString());
    _permanence = TextEditingController(text: f.permanenceFactor.toString());
    _co2 = TextEditingController(text: f.co2ConversionFactor.toString());
    _grid = TextEditingController(text: f.gridElectricityEf.toString());
    _fuel = TextEditingController(text: f.supplementalFuelEf.toString());
    _conv = TextEditingController(text: f.fuelUnitConversion.toString());
  }

  @override
  void dispose() {
    _carbon.dispose();
    _permanence.dispose();
    _co2.dispose();
    _grid.dispose();
    _fuel.dispose();
    _conv.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final factors = EmissionFactors(
      defaultCarbonPct: double.tryParse(_carbon.text) ?? 88.47,
      permanenceFactor: double.tryParse(_permanence.text) ?? 0.9704,
      co2ConversionFactor: double.tryParse(_co2.text) ?? 3.67,
      gridElectricityEf: double.tryParse(_grid.text) ?? 0.39,
      supplementalFuelEf: double.tryParse(_fuel.text) ?? 2.68,
      fuelUnitConversion: double.tryParse(_conv.text) ?? 0.001,
    );
    await context.read<DataService>().updateEmissionFactors(factors);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Emission factors updated'),
        backgroundColor: AppTheme.successGreen,
      ),
    );
    Navigator.pop(context);
  }

  Widget _factorField(String label, String hint, TextEditingController c) {
    return FormFieldWrapper(
      label: label,
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(hintText: hint),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emission Factors')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppTheme.warningAmber, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Verifier-controlled. Lock after agreement with verifier per VM0044 PD.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Methodological Constants',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      _factorField('Default Total Carbon (%)',
                          'e.g. 88.47', _carbon),
                      _factorField('Permanence Factor (fraction)',
                          'e.g. 0.9704', _permanence),
                      _factorField('C → CO₂ Conversion (44/12)',
                          'e.g. 3.67', _co2),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Energy & Fuel Factors',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      _factorField(
                          'Grid Electricity EF (tCO₂e/MWh)', '0.39', _grid),
                      _factorField('Supplemental Fuel EF (kg CO₂e/L)',
                          '2.68 (diesel default)', _fuel),
                      _factorField('Fuel Unit Conversion (t/kg)',
                          '0.001', _conv),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('SAVE FACTORS'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
