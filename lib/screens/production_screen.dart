import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/data_models.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/id_generator_service.dart';
import '../widgets/id_picker.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';

class ProductionScreen extends StatelessWidget {
  final bool readOnly;
  const ProductionScreen({super.key, this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final runs = data.getProductionRuns();
    return Scaffold(
      body: runs.isEmpty
          ? const EmptyState(
              icon: Icons.factory_outlined,
              title: 'No Production Runs',
              message:
                  'Tap + to log a pyrolysis run. Reactor temperature, residence time, and oxygen-limited confirmation are required.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: runs.length,
              itemBuilder: (_, i) {
                final r = runs[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.runId.isEmpty ? '(no run ID)' : r.runId,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text('Yield: ${Fmt.pctRatio(r.massYield)}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryGreen)),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${Fmt.date(r.productionDate)} · ${r.unitLineId}',
                              style: const TextStyle(fontSize: 12)),
                          Text(
                            'Input: ${Fmt.num2(r.feedstockInputDry)} t · Output: ${Fmt.num2(r.biocharProducedDry)} t · ${Fmt.num2(r.electricityKwh)} kWh',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    trailing: readOnly
                        ? null
                        : PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') {
                                _open(context, existing: r);
                              } else if (v == 'delete') {
                                data.deleteProduction(r.id);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                  value: 'delete', child: Text('Delete')),
                            ],
                          ),
                  ),
                );
              },
            ),
      floatingActionButton: readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _open(context),
              backgroundColor: AppTheme.primaryGreen,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('NEW RUN',
                  style: TextStyle(color: Colors.white)),
            ),
    );
  }

  void _open(BuildContext context, {ProductionRun? existing}) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ProductionEditor(existing: existing)),
    );
  }
}

class ProductionEditor extends StatefulWidget {
  final ProductionRun? existing;
  const ProductionEditor({super.key, this.existing});

  @override
  State<ProductionEditor> createState() => _ProductionEditorState();
}

class _ProductionEditorState extends State<ProductionEditor> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late TextEditingController _runId;
  late TextEditingController _unit;
  List<String> _selectedFeedstockIds = [];
  late TextEditingController _input;
  late TextEditingController _temp;
  late TextEditingController _residence;
  late TextEditingController _kwh;
  late TextEditingController _fuelLiters;
  late TextEditingController _output;
  late TextEditingController _comments;

  String _oxygen = 'Yes';
  String _fuelType = 'None';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.productionDate ?? DateTime.now();
    final idGen = context.read<IdGeneratorService>();
    _runId = TextEditingController(
        text: e?.runId ?? idGen.peekProductionId());
    _unit = TextEditingController(
        text: e?.unitLineId ?? idGen.peekNextId(IdGeneratorService.prefixUnitLine));
    _selectedFeedstockIds = (e?.linkedFeedstockLoadIds ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    _input = TextEditingController(text: e?.feedstockInputDry.toString() ?? '0');
    _temp = TextEditingController(text: e?.reactorTemperature.toString() ?? '0');
    _residence =
        TextEditingController(text: e?.residenceTimeMin.toString() ?? '0');
    _kwh = TextEditingController(text: e?.electricityKwh.toString() ?? '0');
    _fuelLiters =
        TextEditingController(text: e?.supplementalFuelLiters.toString() ?? '0');
    _output =
        TextEditingController(text: e?.biocharProducedDry.toString() ?? '0');
    _comments = TextEditingController(text: e?.comments ?? '');
    if (e != null) {
      _oxygen = e.oxygenLimitedConfirmation.isEmpty ? 'Yes' : e.oxygenLimitedConfirmation;
      _fuelType =
          e.supplementalFuelType.isEmpty ? 'None' : e.supplementalFuelType;
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final data = context.read<DataService>();
    final auth = context.read<AuthService>();
    final idGen = context.read<IdGeneratorService>();
    final runId = widget.existing?.runId ?? idGen.nextProductionId();
    final unitLineId = widget.existing?.unitLineId.isNotEmpty == true
        ? widget.existing!.unitLineId
        : idGen.nextUnitLineId();
    final run = ProductionRun(
      id: widget.existing?.id ?? data.newId(),
      productionDate: _date,
      runId: runId,
      unitLineId: unitLineId,
      linkedFeedstockLoadIds: _selectedFeedstockIds.join(', '),
      feedstockInputDry: double.tryParse(_input.text) ?? 0,
      reactorTemperature: double.tryParse(_temp.text) ?? 0,
      residenceTimeMin: double.tryParse(_residence.text) ?? 0,
      oxygenLimitedConfirmation: _oxygen,
      electricityKwh: double.tryParse(_kwh.text) ?? 0,
      supplementalFuelLiters: double.tryParse(_fuelLiters.text) ?? 0,
      supplementalFuelType: _fuelType,
      biocharProducedDry: double.tryParse(_output.text) ?? 0,
      comments: _comments.text.trim(),
      enteredBy: auth.currentUser?.username ?? 'unknown',
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    if (run.biocharProducedDry > run.feedstockInputDry &&
        run.feedstockInputDry > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Yield > 100% Detected'),
          content: const Text(
            'Biochar output exceeds feedstock input — this will trigger a REVIEW red flag on the dashboard. Continue saving?',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save Anyway')),
          ],
        ),
      );
      if (proceed != true) return;
    }
    await data.saveProduction(run);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Production run saved'),
        backgroundColor: AppTheme.successGreen,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New Production Run' : 'Edit Run'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FormFieldWrapper(
                label: 'Production Date',
                required: true,
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.dividerGray),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 18),
                        const SizedBox(width: 10),
                        Text(Fmt.date(_date)),
                      ],
                    ),
                  ),
                ),
              ),
              FormFieldWrapper(
                label: 'Production Run ID (auto-generated)',
                required: true,
                child: TextFormField(
                  controller: _runId,
                  readOnly: true,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    suffixIcon: Icon(Icons.lock_outline, size: 18),
                    helperText: 'System-assigned identifier — not editable',
                  ),
                ),
              ),
              FormFieldWrapper(
                label: 'Production Unit / Line ID (auto-generated)',
                child: TextFormField(
                  controller: _unit,
                  readOnly: true,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    suffixIcon: Icon(Icons.lock_outline, size: 18),
                  ),
                ),
              ),
              Consumer<DataService>(
                builder: (_, ds, __) {
                  final options = ds.getFeedstockLogs().map((f) {
                    final qty = f.netWeightDry > 0
                        ? '${f.netWeightDry.toStringAsFixed(2)} t'
                        : '';
                    return IdPickerOption(
                      id: f.loadId,
                      subtitle:
                          '${f.supplier.isEmpty ? "—" : f.supplier} · ${f.category}',
                      trailingBadge: qty.isEmpty ? null : qty,
                    );
                  }).where((o) => o.id.isNotEmpty).toList();
                  return IdPickerField(
                    label: 'Linked Feedstock Load IDs',
                    helperText:
                        'Multi-select all feedstock loads consumed in this run',
                    required: true,
                    multiSelect: true,
                    options: options,
                    selected: _selectedFeedstockIds,
                    emptyHint:
                        'No feedstock loads logged yet — Receiving must record one first.',
                    onChanged: (ids) =>
                        setState(() => _selectedFeedstockIds = ids),
                  );
                },
              ),
              FormFieldWrapper(
                label: 'Feedstock Input Mass (dry, t)',
                required: true,
                child: TextFormField(
                  controller: _input,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: FormFieldWrapper(
                      label: 'Reactor Temperature (°C)',
                      child: TextFormField(
                        controller: _temp,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FormFieldWrapper(
                      label: 'Residence Time (min)',
                      child: TextFormField(
                        controller: _residence,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ),
                ],
              ),
              FormFieldWrapper(
                label: 'Oxygen-Limited Operation Confirmation',
                required: true,
                child: DropdownButtonFormField<String>(
                  value: _oxygen,
                  items: const ['Yes', 'No', 'N/A']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _oxygen = v!),
                ),
              ),
              FormFieldWrapper(
                label: 'Electricity Consumed (kWh)',
                child: TextFormField(
                  controller: _kwh,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: FormFieldWrapper(
                      label: 'Supplemental Fuel Type',
                      child: DropdownButtonFormField<String>(
                        value: _fuelType,
                        items: const ['None', 'Diesel', 'Natural Gas', 'Propane', 'Other']
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setState(() => _fuelType = v!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FormFieldWrapper(
                      label: 'Fuel Quantity (liters)',
                      child: TextFormField(
                        controller: _fuelLiters,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ),
                ],
              ),
              FormFieldWrapper(
                label: 'Biochar Produced (dry mass, t)',
                required: true,
                child: TextFormField(
                  controller: _output,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              FormFieldWrapper(
                label: 'Comments',
                child: TextFormField(controller: _comments, maxLines: 3),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('SAVE PRODUCTION RUN'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
