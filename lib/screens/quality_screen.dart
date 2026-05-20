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

class QualityScreen extends StatelessWidget {
  final bool readOnly;
  const QualityScreen({super.key, this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final batches = data.getQualityBatches();
    return Scaffold(
      body: batches.isEmpty
          ? const EmptyState(
              icon: Icons.science_outlined,
              title: 'No Quality Samples',
              message:
                  'Tap + to log a quality sample. Total Carbon % drives the carbon stored calculation.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: batches.length,
              itemBuilder: (_, i) {
                final b = batches[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(b.batchLotId,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                        ),
                        StatusBadge(status: b.acceptanceStatus.toUpperCase()),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${Fmt.date(b.samplingDate)} · ${Fmt.num2(b.batchQuantityDry)} t dry',
                              style: const TextStyle(fontSize: 12)),
                          Text(
                            'C: ${Fmt.pct(b.totalCarbonPct)} · Ash: ${Fmt.pct(b.ashPct)} · Moisture: ${Fmt.pct(b.moisturePct)}',
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
                                _open(context, existing: b);
                              } else if (v == 'delete') {
                                data.deleteQuality(b.id);
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
              label: const Text('NEW SAMPLE',
                  style: TextStyle(color: Colors.white)),
            ),
    );
  }

  void _open(BuildContext context, {QualityBatch? existing}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QualityEditor(existing: existing)),
    );
  }
}

class QualityEditor extends StatefulWidget {
  final QualityBatch? existing;
  const QualityEditor({super.key, this.existing});

  @override
  State<QualityEditor> createState() => _QualityEditorState();
}

class _QualityEditorState extends State<QualityEditor> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late TextEditingController _lotId;
  List<String> _selectedRunIds = [];
  late TextEditingController _qty;
  late TextEditingController _method;
  late TextEditingController _coa;
  late TextEditingController _moisture;
  late TextEditingController _ash;
  late TextEditingController _carbon;
  late TextEditingController _hcorg;
  late TextEditingController _comments;
  String _acceptance = 'accepted';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.samplingDate ?? DateTime.now();
    final idGen = context.read<IdGeneratorService>();
    _lotId = TextEditingController(
        text: e?.batchLotId ?? idGen.peekQualityBatchId());
    _selectedRunIds = (e?.productionRunIdsCovered ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    _qty = TextEditingController(text: e?.batchQuantityDry.toString() ?? '0');
    _method = TextEditingController(text: e?.samplingMethodRef ?? '');
    _coa = TextEditingController(text: e?.labCoaRef ?? '');
    _moisture = TextEditingController(text: e?.moisturePct.toString() ?? '0');
    _ash = TextEditingController(text: e?.ashPct.toString() ?? '0');
    _carbon = TextEditingController(text: e?.totalCarbonPct.toString() ?? '0');
    _hcorg = TextEditingController(text: e?.hCorgMolar.toString() ?? '0');
    _comments = TextEditingController(text: e?.comments ?? '');
    if (e != null) _acceptance = e.acceptanceStatus;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final data = context.read<DataService>();
    final auth = context.read<AuthService>();
    final c = double.tryParse(_carbon.text) ?? 0;
    if (c < 0 || c > 100) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Carbon % must be between 0 and 100'),
        backgroundColor: AppTheme.dangerRed,
      ));
      return;
    }
    final idGen = context.read<IdGeneratorService>();
    final batchLotId = widget.existing?.batchLotId ?? idGen.nextQualityBatchId();
    final batch = QualityBatch(
      id: widget.existing?.id ?? data.newId(),
      batchLotId: batchLotId,
      productionRunIdsCovered: _selectedRunIds.join(', '),
      batchQuantityDry: double.tryParse(_qty.text) ?? 0,
      samplingDate: _date,
      samplingMethodRef: _method.text.trim(),
      labCoaRef: _coa.text.trim(),
      moisturePct: double.tryParse(_moisture.text) ?? 0,
      ashPct: double.tryParse(_ash.text) ?? 0,
      totalCarbonPct: c,
      hCorgMolar: double.tryParse(_hcorg.text) ?? 0,
      acceptanceStatus: _acceptance,
      comments: _comments.text.trim(),
      enteredBy: auth.currentUser?.username ?? 'unknown',
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    await data.saveQuality(batch);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quality batch saved'),
        backgroundColor: AppTheme.successGreen,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.existing == null ? 'New Quality Sample' : 'Edit Sample'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FormFieldWrapper(
                label: 'Sampling Date',
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
                label: 'Biochar Batch / Lot ID (auto-generated)',
                required: true,
                child: TextFormField(
                  controller: _lotId,
                  readOnly: true,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    suffixIcon: Icon(Icons.lock_outline, size: 18),
                    helperText: 'System-assigned identifier — not editable',
                  ),
                ),
              ),
              Consumer<DataService>(
                builder: (_, ds, __) {
                  final options = ds.getProductionRuns().map((r) {
                    final qty = r.biocharProducedDry > 0
                        ? '${r.biocharProducedDry.toStringAsFixed(2)} t'
                        : '';
                    return IdPickerOption(
                      id: r.runId,
                      subtitle:
                          'Unit ${r.unitLineId.isEmpty ? "—" : r.unitLineId} · ${r.productionDate.year}-${r.productionDate.month.toString().padLeft(2, "0")}-${r.productionDate.day.toString().padLeft(2, "0")}',
                      trailingBadge: qty.isEmpty ? null : qty,
                    );
                  }).where((o) => o.id.isNotEmpty).toList();
                  return IdPickerField(
                    label: 'Production Run IDs Covered',
                    helperText:
                        'Multi-select all production runs this lab batch covers',
                    required: true,
                    multiSelect: true,
                    options: options,
                    selected: _selectedRunIds,
                    emptyHint:
                        'No production runs logged yet — Pyrolysis must record one first.',
                    onChanged: (ids) =>
                        setState(() => _selectedRunIds = ids),
                  );
                },
              ),
              FormFieldWrapper(
                label: 'Batch Quantity (dry, t)',
                required: true,
                child: TextFormField(
                  controller: _qty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              FormFieldWrapper(
                label: 'Sampling Method Reference',
                child: TextFormField(controller: _method),
              ),
              FormFieldWrapper(
                label: 'Laboratory & COA Reference',
                child: TextFormField(controller: _coa),
              ),
              Row(
                children: [
                  Expanded(
                    child: FormFieldWrapper(
                      label: 'Moisture (%)',
                      child: TextFormField(
                        controller: _moisture,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FormFieldWrapper(
                      label: 'Ash (%)',
                      child: TextFormField(
                        controller: _ash,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: FormFieldWrapper(
                      label: 'Total Carbon (%)',
                      required: true,
                      child: TextFormField(
                        controller: _carbon,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FormFieldWrapper(
                      label: 'H/Corg (molar)',
                      child: TextFormField(
                        controller: _hcorg,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ),
                ],
              ),
              FormFieldWrapper(
                label: 'Batch Acceptance Status',
                required: true,
                child: DropdownButtonFormField<String>(
                  value: _acceptance,
                  items: const ['accepted', 'rejected', 'pending']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _acceptance = v!),
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
                label: const Text('SAVE QUALITY BATCH'),
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
