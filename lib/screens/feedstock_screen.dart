import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/data_models.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/id_generator_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';

class FeedstockScreen extends StatelessWidget {
  final bool readOnly;
  const FeedstockScreen({super.key, this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final logs = data.getFeedstockLogs();
    return Scaffold(
      body: logs.isEmpty
          ? const EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'No Feedstock Logs',
              message:
                  'Tap + to record an incoming feedstock load. All quantities recorded on dry basis per VM0044.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: logs.length,
              itemBuilder: (_, i) {
                final l = logs[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.loadId.isEmpty ? '(no load ID)' : l.loadId,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        StatusBadge(status: l.acceptanceStatus.toUpperCase()),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${Fmt.date(l.date)} · ${l.category}',
                              style: const TextStyle(fontSize: 12)),
                          Text(
                            'Supplier: ${l.supplier} · Net: ${Fmt.num2(l.netWeightDry)} t dry',
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
                                _openEditor(context, existing: l);
                              } else if (v == 'delete') {
                                data.deleteFeedstock(l.id);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
      floatingActionButton: readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(context),
              backgroundColor: AppTheme.primaryGreen,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('NEW LOAD',
                  style: TextStyle(color: Colors.white)),
            ),
    );
  }

  void _openEditor(BuildContext context, {FeedstockLog? existing}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FeedstockEditor(existing: existing),
      ),
    );
  }
}

class FeedstockEditor extends StatefulWidget {
  final FeedstockLog? existing;
  const FeedstockEditor({super.key, this.existing});

  @override
  State<FeedstockEditor> createState() => _FeedstockEditorState();
}

class _FeedstockEditorState extends State<FeedstockEditor> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late TextEditingController _loadId;
  late TextEditingController _supplier;
  late TextEditingController _facility;
  late TextEditingController _address;
  late TextEditingController _bol;
  late TextEditingController _distance;
  late TextEditingController _gross;
  late TextEditingController _net;
  late TextEditingController _ticket;
  late TextEditingController _contamination;
  late TextEditingController _storage;
  late TextEditingController _processing;
  late TextEditingController _comments;

  String _category = 'Wood Chips';
  String _eligibility = 'Eligible';
  String _disposalPath = 'Landfill';
  String _transport = 'Truck';
  String _fuelType = 'Diesel';
  String _moistureBasis = 'Wet (as-received)';
  String _visualInspection = 'Pass';
  String _acceptance = 'accepted';

  static const _categories = [
    'Wood Chips',
    'Agricultural Residue',
    'Forestry Residue',
    'Manure',
    'Yard Waste',
    'Mill Residue',
    'Other Biomass'
  ];
  static const _eligibilities = ['Eligible', 'Conditional', 'Ineligible'];
  static const _disposalPaths = [
    'Landfill',
    'Open Burning',
    'Decomposition',
    'Other'
  ];
  static const _transportModes = ['Truck', 'Rail', 'Barge', 'Multi-modal'];
  static const _fuels = ['Diesel', 'Gasoline', 'Biodiesel', 'CNG', 'Electric'];
  static const _moistureBases = [
    'Wet (as-received)',
    'Dry (lab certified)',
    'Adjusted (calculated)'
  ];
  static const _visuals = ['Pass', 'Marginal', 'Fail'];
  static const _acceptances = ['accepted', 'rejected', 'pending'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.date ?? DateTime.now();
    final autoLoadId = e?.loadId ??
        context.read<IdGeneratorService>().peekFeedstockId();
    _loadId = TextEditingController(text: autoLoadId);
    _supplier = TextEditingController(text: e?.supplier ?? '');
    _facility = TextEditingController(text: e?.sourceFacility ?? '');
    _address = TextEditingController(text: e?.sourceAddress ?? '');
    _bol = TextEditingController(text: e?.bolNumber ?? '');
    _distance = TextEditingController(text: e?.distanceMiles.toString() ?? '0');
    _gross = TextEditingController(text: e?.grossWeight.toString() ?? '0');
    _net = TextEditingController(text: e?.netWeightDry.toString() ?? '0');
    _ticket = TextEditingController(text: e?.scaleTicketRef ?? '');
    _contamination = TextEditingController(text: e?.observedContamination ?? '');
    _storage = TextEditingController(text: e?.initialStorageId ?? '');
    _processing = TextEditingController(text: e?.processingLocationId ?? '');
    _comments = TextEditingController(text: e?.comments ?? '');
    if (e != null) {
      _category = e.category;
      _eligibility = e.eligibilityStatus;
      _disposalPath = e.baselineDisposalPathway;
      _transport = e.transportMode;
      _fuelType = e.fuelType;
      _moistureBasis = e.moistureBasis;
      _visualInspection = e.visualInspection;
      _acceptance = e.acceptanceStatus;
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final data = context.read<DataService>();
    final auth = context.read<AuthService>();
    final idGen = context.read<IdGeneratorService>();
    // Commit the auto-generated identifier on first save (advances counter).
    final loadId = widget.existing?.loadId ?? idGen.nextFeedstockId();
    final log = FeedstockLog(
      id: widget.existing?.id ?? data.newId(),
      date: _date,
      loadId: loadId,
      category: _category,
      supplier: _supplier.text.trim(),
      sourceFacility: _facility.text.trim(),
      sourceAddress: _address.text.trim(),
      eligibilityStatus: _eligibility,
      baselineDisposalPathway: _disposalPath,
      bolNumber: _bol.text.trim(),
      transportMode: _transport,
      distanceMiles: double.tryParse(_distance.text) ?? 0,
      fuelType: _fuelType,
      grossWeight: double.tryParse(_gross.text) ?? 0,
      moistureBasis: _moistureBasis,
      netWeightDry: double.tryParse(_net.text) ?? 0,
      scaleTicketRef: _ticket.text.trim(),
      visualInspection: _visualInspection,
      observedContamination: _contamination.text.trim(),
      acceptanceStatus: _acceptance,
      initialStorageId: _storage.text.trim(),
      processingLocationId: _processing.text.trim(),
      comments: _comments.text.trim(),
      enteredBy: auth.currentUser?.username ?? 'unknown',
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    await data.saveFeedstock(log);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Feedstock log saved'),
        backgroundColor: AppTheme.successGreen,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New Feedstock Load' : 'Edit Load'),
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
                        const Icon(Icons.calendar_today_outlined,
                            size: 18, color: AppTheme.textSecondary),
                        const SizedBox(width: 10),
                        Text(Fmt.date(_date)),
                      ],
                    ),
                  ),
                ),
              ),
              FormFieldWrapper(
                label: 'Feedstock Load ID (auto-generated)',
                required: true,
                child: TextFormField(
                  controller: _loadId,
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
                label: 'Feedstock Category',
                child: _dropdown(_categories, _category,
                    (v) => setState(() => _category = v!)),
              ),
              FormFieldWrapper(
                label: 'Supplier / Generator',
                child: TextFormField(controller: _supplier),
              ),
              FormFieldWrapper(
                label: 'Source Facility Name',
                child: TextFormField(controller: _facility),
              ),
              FormFieldWrapper(
                label: 'Source Facility Address',
                child: TextFormField(controller: _address, maxLines: 2),
              ),
              FormFieldWrapper(
                label: 'Eligibility Status',
                child: _dropdown(_eligibilities, _eligibility,
                    (v) => setState(() => _eligibility = v!)),
              ),
              FormFieldWrapper(
                label: 'Baseline Disposal Pathway',
                child: _dropdown(_disposalPaths, _disposalPath,
                    (v) => setState(() => _disposalPath = v!)),
              ),
              FormFieldWrapper(
                label: 'BOL Number (Baseline Evidence Reference)',
                child: TextFormField(controller: _bol),
              ),
              Row(
                children: [
                  Expanded(
                    child: FormFieldWrapper(
                      label: 'Transport Mode',
                      child: _dropdown(_transportModes, _transport,
                          (v) => setState(() => _transport = v!)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FormFieldWrapper(
                      label: 'Distance (miles)',
                      child: TextFormField(
                        controller: _distance,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ),
                ],
              ),
              FormFieldWrapper(
                label: 'Fuel Type',
                child: _dropdown(_fuels, _fuelType,
                    (v) => setState(() => _fuelType = v!)),
              ),
              Row(
                children: [
                  Expanded(
                    child: FormFieldWrapper(
                      label: 'Gross Weight',
                      child: TextFormField(
                        controller: _gross,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FormFieldWrapper(
                      label: 'Net Weight (dry, t)',
                      required: true,
                      child: TextFormField(
                        controller: _net,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          if (n == null || n < 0) return 'Enter ≥ 0';
                          return null;
                        },
                      ),
                    ),
                  ),
                ],
              ),
              FormFieldWrapper(
                label: 'Moisture / Solids Basis',
                child: _dropdown(_moistureBases, _moistureBasis,
                    (v) => setState(() => _moistureBasis = v!)),
              ),
              FormFieldWrapper(
                label: 'Scale Ticket Reference',
                child: TextFormField(controller: _ticket),
              ),
              FormFieldWrapper(
                label: 'Visual Inspection',
                child: _dropdown(_visuals, _visualInspection,
                    (v) => setState(() => _visualInspection = v!)),
              ),
              FormFieldWrapper(
                label: 'Observed Contamination',
                child: TextFormField(controller: _contamination, maxLines: 2),
              ),
              FormFieldWrapper(
                label: 'Load Acceptance Status',
                required: true,
                child: _dropdown(_acceptances, _acceptance,
                    (v) => setState(() => _acceptance = v!)),
              ),
              FormFieldWrapper(
                label: 'Initial Storage ID',
                child: TextFormField(controller: _storage),
              ),
              FormFieldWrapper(
                label: 'Processing Location ID',
                child: TextFormField(controller: _processing),
              ),
              FormFieldWrapper(
                label: 'Comments',
                child: TextFormField(controller: _comments, maxLines: 3),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('SAVE FEEDSTOCK LOG'),
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

  Widget _dropdown(
      List<String> items, String value, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : items.first,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
