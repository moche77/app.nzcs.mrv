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

class InventoryScreen extends StatelessWidget {
  final bool readOnly;
  const InventoryScreen({super.key, this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final lots = data.getInventoryLots();
    return Scaffold(
      body: lots.isEmpty
          ? const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No Inventory Lots',
              message:
                  'Tap + to record an inventory lot. Reconciliation auto-validates that ending = beginning + added − removed.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: lots.length,
              itemBuilder: (_, i) {
                final l = lots[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(l.inventoryLotId,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                        ),
                        StatusBadge(
                            status: l.reconciliationStatus.toUpperCase()),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${Fmt.date(l.date)} · ${l.storageLocationId}',
                              style: const TextStyle(fontSize: 12)),
                          Text(
                            'Begin: ${Fmt.num2(l.beginningInventory)} · +${Fmt.num2(l.biocharAdded)} · −${Fmt.num2(l.biocharRemoved)} · End: ${Fmt.num2(l.endingInventory)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Allocation: ${l.allocationStatus} (${Fmt.num2(l.allocatedQuantity)} t)',
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
                                _open(context, existing: l);
                              } else if (v == 'delete') {
                                data.deleteInventory(l.id);
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
              label: const Text('NEW LOT',
                  style: TextStyle(color: Colors.white)),
            ),
    );
  }

  void _open(BuildContext context, {InventoryLot? existing}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InventoryEditor(existing: existing)),
    );
  }
}

class InventoryEditor extends StatefulWidget {
  final InventoryLot? existing;
  const InventoryEditor({super.key, this.existing});

  @override
  State<InventoryEditor> createState() => _InventoryEditorState();
}

class _InventoryEditorState extends State<InventoryEditor> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late TextEditingController _lotId;
  List<String> _selectedBatchIds = [];
  late TextEditingController _location;
  late TextEditingController _begin;
  late TextEditingController _added;
  late TextEditingController _removed;
  late TextEditingController _allocated;
  late TextEditingController _comments;
  String _allocStatus = 'unallocated';

  double get _expectedEnding {
    final b = double.tryParse(_begin.text) ?? 0;
    final a = double.tryParse(_added.text) ?? 0;
    final r = double.tryParse(_removed.text) ?? 0;
    return b + a - r;
  }

  String get _reconciliation {
    // Computed automatically from the formula. Treat empty (zero) as pass.
    return _expectedEnding >= 0 ? 'pass' : 'fail';
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.date ?? DateTime.now();
    final idGen = context.read<IdGeneratorService>();
    _lotId = TextEditingController(
        text: e?.inventoryLotId ?? idGen.peekInventoryLotId());
    _selectedBatchIds = (e?.linkedBiocharBatchIds ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    _location = TextEditingController(
        text: e?.storageLocationId ?? idGen.peekNextId(IdGeneratorService.prefixStorage));
    _begin =
        TextEditingController(text: e?.beginningInventory.toString() ?? '0');
    _added = TextEditingController(text: e?.biocharAdded.toString() ?? '0');
    _removed = TextEditingController(text: e?.biocharRemoved.toString() ?? '0');
    _allocated =
        TextEditingController(text: e?.allocatedQuantity.toString() ?? '0');
    _comments = TextEditingController(text: e?.comments ?? '');
    if (e != null) _allocStatus = e.allocationStatus;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final data = context.read<DataService>();
    final auth = context.read<AuthService>();
    final idGen = context.read<IdGeneratorService>();
    final inventoryLotId =
        widget.existing?.inventoryLotId ?? idGen.nextInventoryLotId();
    final storageLocationId = widget.existing?.storageLocationId.isNotEmpty == true
        ? widget.existing!.storageLocationId
        : idGen.nextStorageId();
    final lot = InventoryLot(
      id: widget.existing?.id ?? data.newId(),
      date: _date,
      inventoryLotId: inventoryLotId,
      linkedBiocharBatchIds: _selectedBatchIds.join(', '),
      storageLocationId: storageLocationId,
      beginningInventory: double.tryParse(_begin.text) ?? 0,
      biocharAdded: double.tryParse(_added.text) ?? 0,
      biocharRemoved: double.tryParse(_removed.text) ?? 0,
      endingInventory: _expectedEnding,
      reconciliationStatus: _reconciliation,
      allocatedQuantity: double.tryParse(_allocated.text) ?? 0,
      allocationStatus: _allocStatus,
      comments: _comments.text.trim(),
      enteredBy: auth.currentUser?.username ?? 'unknown',
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    await data.saveInventory(lot);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Inventory lot saved'),
        backgroundColor: AppTheme.successGreen,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New Inventory Lot' : 'Edit Lot'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FormFieldWrapper(
                label: 'Date',
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
                label: 'Inventory Lot ID (auto-generated)',
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
                  final options = ds.getQualityBatches().map((b) {
                    final qty = b.batchQuantityDry > 0
                        ? '${b.batchQuantityDry.toStringAsFixed(2)} t'
                        : '';
                    return IdPickerOption(
                      id: b.batchLotId,
                      subtitle:
                          'C ${b.totalCarbonPct.toStringAsFixed(2)}% · ${b.acceptanceStatus}',
                      trailingBadge: qty.isEmpty ? null : qty,
                    );
                  }).where((o) => o.id.isNotEmpty).toList();
                  return IdPickerField(
                    label: 'Linked Biochar Batch IDs',
                    helperText:
                        'Multi-select all quality-tested batches comprising this inventory lot',
                    required: true,
                    multiSelect: true,
                    options: options,
                    selected: _selectedBatchIds,
                    emptyHint:
                        'No quality batches logged yet — Lab must record one first.',
                    onChanged: (ids) =>
                        setState(() => _selectedBatchIds = ids),
                  );
                },
              ),
              FormFieldWrapper(
                label: 'Storage Location ID (auto-generated)',
                child: TextFormField(
                  controller: _location,
                  readOnly: true,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    suffixIcon: Icon(Icons.lock_outline, size: 18),
                  ),
                ),
              ),
              FormFieldWrapper(
                label: 'Beginning Inventory (dry, t)',
                child: TextFormField(
                  controller: _begin,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: FormFieldWrapper(
                      label: 'Biochar Added (t)',
                      child: TextFormField(
                        controller: _added,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FormFieldWrapper(
                      label: 'Biochar Removed (t)',
                      child: TextFormField(
                        controller: _removed,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calculate_outlined,
                        color: AppTheme.primaryGreen, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Computed Ending Inventory',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary)),
                          Text(
                            '${Fmt.num2(_expectedEnding)} t dry · Reconciliation: ${_reconciliation.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FormFieldWrapper(
                label: 'Allocated Quantity (dry, t)',
                child: TextFormField(
                  controller: _allocated,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              FormFieldWrapper(
                label: 'Allocation Status',
                required: true,
                child: DropdownButtonFormField<String>(
                  value: _allocStatus,
                  items: const ['unallocated', 'allocated', 'excluded']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _allocStatus = v!),
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
                label: const Text('SAVE INVENTORY LOT'),
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
