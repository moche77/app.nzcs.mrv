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

class ApplicationScreen extends StatelessWidget {
  final bool readOnly;
  const ApplicationScreen({super.key, this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final events = data.getApplicationEvents();
    return Scaffold(
      body: events.isEmpty
          ? const EmptyState(
              icon: Icons.agriculture_outlined,
              title: 'No Application Events',
              message:
                  'Tap + to record a soil or non-soil application event with operator attestation.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: events.length,
              itemBuilder: (_, i) {
                final e = events[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(e.applicationEventId,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                        ),
                        StatusBadge(
                            status: e.applicationStatus.toUpperCase()),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${Fmt.date(e.applicationDate)} · ${Fmt.num2(e.allocatedQuantityApplied)} t dry',
                              style: const TextStyle(fontSize: 12)),
                          if (e.soilSiteId.isNotEmpty)
                            Text(
                                'Soil: ${e.soilSiteId} · ${e.soilLandUseCategory}',
                                style: const TextStyle(fontSize: 12)),
                          if (e.nonSoilUseCategory.isNotEmpty)
                            Text('Non-Soil: ${e.nonSoilUseCategory}',
                                style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    trailing: readOnly
                        ? null
                        : PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') {
                                _open(context, existing: e);
                              } else if (v == 'delete') {
                                data.deleteApplication(e.id);
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
              label: const Text('NEW EVENT',
                  style: TextStyle(color: Colors.white)),
            ),
    );
  }

  void _open(BuildContext context, {ApplicationEvent? existing}) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ApplicationEditor(existing: existing)),
    );
  }
}

class ApplicationEditor extends StatefulWidget {
  final ApplicationEvent? existing;
  const ApplicationEditor({super.key, this.existing});

  @override
  State<ApplicationEditor> createState() => _ApplicationEditorState();
}

class _ApplicationEditorState extends State<ApplicationEditor> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late TextEditingController _eventId;
  List<String> _selectedLotIds = [];
  late TextEditingController _qty;
  late TextEditingController _siteId;
  late TextEditingController _siteLoc;
  late TextEditingController _nonSoilProduct;
  late TextEditingController _delivery;
  late TextEditingController _attest;
  late TextEditingController _comments;
  String _status = 'completed';
  String _landUse = 'Cropland';
  String _appMethod = 'Surface broadcast';
  String _incorporation = 'Yes';
  String _nonSoilUse = 'None';
  String _category = 'Soil';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.applicationDate ?? DateTime.now();
    final idGen = context.read<IdGeneratorService>();
    _eventId = TextEditingController(
        text: e?.applicationEventId ?? idGen.peekApplicationEventId());
    _selectedLotIds = (e?.biocharInventoryLotIds ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    _qty = TextEditingController(
        text: e?.allocatedQuantityApplied.toString() ?? '0');
    _siteId = TextEditingController(
        text: e?.soilSiteId ?? idGen.peekNextId(IdGeneratorService.prefixSoilSite));
    _siteLoc = TextEditingController(text: e?.soilSiteLocation ?? '');
    _nonSoilProduct = TextEditingController(text: e?.nonSoilProductRef ?? '');
    _delivery = TextEditingController(text: e?.deliveryRecordRef ?? '');
    _attest = TextEditingController(text: e?.operatorAttestation ?? '');
    _comments = TextEditingController(text: e?.comments ?? '');
    if (e != null) {
      _status = e.applicationStatus;
      if (e.soilLandUseCategory.isNotEmpty) _landUse = e.soilLandUseCategory;
      if (e.soilApplicationMethod.isNotEmpty) {
        _appMethod = e.soilApplicationMethod;
      }
      if (e.soilIncorporationConfirmation.isNotEmpty) {
        _incorporation = e.soilIncorporationConfirmation;
      }
      if (e.nonSoilUseCategory.isNotEmpty) _nonSoilUse = e.nonSoilUseCategory;
      _category = e.nonSoilUseCategory.isNotEmpty && e.nonSoilUseCategory != 'None'
          ? 'Non-Soil'
          : 'Soil';
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final data = context.read<DataService>();
    final auth = context.read<AuthService>();
    final idGen = context.read<IdGeneratorService>();
    final applicationEventId =
        widget.existing?.applicationEventId ?? idGen.nextApplicationEventId();
    String soilSiteId = '';
    if (_category == 'Soil') {
      soilSiteId = (widget.existing?.soilSiteId.isNotEmpty == true)
          ? widget.existing!.soilSiteId
          : idGen.nextSoilSiteId();
    }
    final ev = ApplicationEvent(
      id: widget.existing?.id ?? data.newId(),
      applicationEventId: applicationEventId,
      applicationDate: _date,
      biocharInventoryLotIds: _selectedLotIds.join(', '),
      allocatedQuantityApplied: double.tryParse(_qty.text) ?? 0,
      applicationStatus: _status,
      soilSiteId: soilSiteId,
      soilSiteLocation: _category == 'Soil' ? _siteLoc.text.trim() : '',
      soilLandUseCategory: _category == 'Soil' ? _landUse : '',
      soilApplicationMethod: _category == 'Soil' ? _appMethod : '',
      soilIncorporationConfirmation:
          _category == 'Soil' ? _incorporation : '',
      nonSoilUseCategory: _category == 'Non-Soil' ? _nonSoilUse : '',
      nonSoilProductRef:
          _category == 'Non-Soil' ? _nonSoilProduct.text.trim() : '',
      deliveryRecordRef: _delivery.text.trim(),
      operatorAttestation: _attest.text.trim(),
      comments: _comments.text.trim(),
      enteredBy: auth.currentUser?.username ?? 'unknown',
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    await data.saveApplication(ev);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Application event saved'),
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
            widget.existing == null ? 'New Application Event' : 'Edit Event'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FormFieldWrapper(
                label: 'Application Event ID (auto-generated)',
                required: true,
                child: TextFormField(
                  controller: _eventId,
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
                label: 'Application Date',
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
              Consumer<DataService>(
                builder: (_, ds, __) {
                  final options = ds.getInventoryLots().map((l) {
                    final available = l.beginningInventory +
                        l.biocharAdded -
                        l.biocharRemoved;
                    final qty = available > 0
                        ? '${available.toStringAsFixed(2)} t avail'
                        : '';
                    return IdPickerOption(
                      id: l.inventoryLotId,
                      subtitle:
                          'Storage ${l.storageLocationId.isEmpty ? "—" : l.storageLocationId} · ${l.allocationStatus}',
                      trailingBadge: qty.isEmpty ? null : qty,
                    );
                  }).where((o) => o.id.isNotEmpty).toList();
                  return IdPickerField(
                    label: 'Biochar Inventory Lot ID(s)',
                    helperText:
                        'Multi-select all inventory lots drawn down for this application event',
                    required: true,
                    multiSelect: true,
                    options: options,
                    selected: _selectedLotIds,
                    emptyHint:
                        'No inventory lots logged yet — Inventory must record one first.',
                    onChanged: (ids) =>
                        setState(() => _selectedLotIds = ids),
                  );
                },
              ),
              FormFieldWrapper(
                label: 'Allocated Quantity Applied (dry, t)',
                required: true,
                child: TextFormField(
                  controller: _qty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              FormFieldWrapper(
                label: 'Application Status',
                required: true,
                child: DropdownButtonFormField<String>(
                  value: _status,
                  items: const ['completed', 'partial', 'excluded']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v!),
                ),
              ),
              FormFieldWrapper(
                label: 'Application Category',
                required: true,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Soil', label: Text('Soil')),
                    ButtonSegment(value: 'Non-Soil', label: Text('Non-Soil')),
                  ],
                  selected: {_category},
                  onSelectionChanged: (s) =>
                      setState(() => _category = s.first),
                ),
              ),
              if (_category == 'Soil') ...[
                FormFieldWrapper(
                  label: 'Site ID (auto-generated)',
                  child: TextFormField(
                    controller: _siteId,
                    readOnly: true,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      suffixIcon: Icon(Icons.lock_outline, size: 18),
                    ),
                  ),
                ),
                FormFieldWrapper(
                  label: 'Site General Location',
                  child: TextFormField(controller: _siteLoc),
                ),
                FormFieldWrapper(
                  label: 'Land Use Category',
                  child: DropdownButtonFormField<String>(
                    value: _landUse,
                    items: const [
                      'Cropland',
                      'Pasture',
                      'Grassland',
                      'Forest',
                      'Restoration Site',
                      'Other'
                    ]
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _landUse = v!),
                  ),
                ),
                FormFieldWrapper(
                  label: 'Application Method',
                  child: DropdownButtonFormField<String>(
                    value: _appMethod,
                    items: const [
                      'Surface broadcast',
                      'Surface incorporation',
                      'Banded',
                      'Subsurface injection',
                      'Mixed with compost'
                    ]
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _appMethod = v!),
                  ),
                ),
                FormFieldWrapper(
                  label: 'Incorporation Confirmation',
                  child: DropdownButtonFormField<String>(
                    value: _incorporation,
                    items: const ['Yes', 'No', 'Partial']
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _incorporation = v!),
                  ),
                ),
              ] else ...[
                FormFieldWrapper(
                  label: 'Non-Soil Use Category',
                  child: DropdownButtonFormField<String>(
                    value: _nonSoilUse,
                    items: const [
                      'None',
                      'Concrete additive',
                      'Asphalt additive',
                      'Animal feed',
                      'Filtration media',
                      'Composite material',
                      'Other'
                    ]
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _nonSoilUse = v!),
                  ),
                ),
                FormFieldWrapper(
                  label: 'Product or Batch Reference',
                  child: TextFormField(controller: _nonSoilProduct),
                ),
              ],
              FormFieldWrapper(
                label: 'Delivery / Transfer Record Reference',
                child: TextFormField(controller: _delivery),
              ),
              FormFieldWrapper(
                label: 'Operator / Partner Attestation',
                required: true,
                child: TextFormField(
                  controller: _attest,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText:
                        'Sign-off statement (e.g. "I, [Name], attest that...")',
                  ),
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
                label: const Text('SAVE APPLICATION EVENT'),
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
