import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/data_models.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/id_generator_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';

class AuditControlsScreen extends StatelessWidget {
  final bool readOnly;
  const AuditControlsScreen({super.key, this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final controls = data.getAuditControls();
    return Scaffold(
      body: controls.isEmpty
          ? const EmptyState(
              icon: Icons.security_outlined,
              title: 'No Audit Controls Logged',
              message:
                  'Tap + to log a verification hygiene check. VM0044 + investor-grade defensibility.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: controls.length,
              itemBuilder: (_, i) {
                final c = controls[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(c.controlName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                        ),
                        StatusBadge(status: c.status.toUpperCase()),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.rationale,
                              style: const TextStyle(fontSize: 12)),
                          Text(
                              'Checked by ${c.checkedBy} on ${Fmt.date(c.dateChecked)}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    trailing: readOnly
                        ? null
                        : PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') {
                                _open(context, existing: c);
                              } else if (v == 'delete') {
                                data.deleteAuditControl(c.id);
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
              label: const Text('NEW CONTROL',
                  style: TextStyle(color: Colors.white)),
            ),
    );
  }

  void _open(BuildContext context, {AuditControl? existing}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AuditEditor(existing: existing)),
    );
  }
}

class AuditEditor extends StatefulWidget {
  final AuditControl? existing;
  const AuditEditor({super.key, this.existing});

  @override
  State<AuditEditor> createState() => _AuditEditorState();
}

class _AuditEditorState extends State<AuditEditor> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _controlRef;
  late TextEditingController _name;
  late TextEditingController _rationale;
  late TextEditingController _evidence;
  late TextEditingController _comments;
  late DateTime _date;
  String _status = 'pass';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final idGen = context.read<IdGeneratorService>();
    _controlRef =
        TextEditingController(text: e != null ? '(existing)' : idGen.peekAuditControlId());
    _name = TextEditingController(text: e?.controlName ?? '');
    _rationale = TextEditingController(text: e?.rationale ?? '');
    _evidence = TextEditingController(text: e?.evidence ?? '');
    _comments = TextEditingController(text: e?.comments ?? '');
    _date = e?.dateChecked ?? DateTime.now();
    if (e != null) _status = e.status;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final data = context.read<DataService>();
    final auth = context.read<AuthService>();
    final idGen = context.read<IdGeneratorService>();
    // Advance audit control counter on first save for traceability parity.
    if (widget.existing == null) {
      idGen.nextAuditControlId();
    }
    final c = AuditControl(
      id: widget.existing?.id ?? data.newId(),
      controlName: _name.text.trim(),
      rationale: _rationale.text.trim(),
      status: _status,
      evidence: _evidence.text.trim(),
      dateChecked: _date,
      checkedBy: auth.currentUser?.username ?? 'unknown',
      comments: _comments.text.trim(),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    await data.saveAuditControl(c);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Audit control saved'),
        backgroundColor: AppTheme.successGreen,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New Audit Control' : 'Edit Control'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FormFieldWrapper(
                label: 'Control Reference ID (auto-generated)',
                required: true,
                child: TextFormField(
                  controller: _controlRef,
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
                label: 'Control Name',
                required: true,
                child: TextFormField(
                  controller: _name,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ),
              FormFieldWrapper(
                label: 'Rationale (why this exists)',
                child: TextFormField(controller: _rationale, maxLines: 3),
              ),
              FormFieldWrapper(
                label: 'Status',
                required: true,
                child: DropdownButtonFormField<String>(
                  value: _status,
                  items: const ['pass', 'fail', 'pending']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v!),
                ),
              ),
              FormFieldWrapper(
                label: 'Evidence Reference',
                child: TextFormField(controller: _evidence),
              ),
              FormFieldWrapper(
                label: 'Date Checked',
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
                label: 'Comments',
                child: TextFormField(controller: _comments, maxLines: 3),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('SAVE CONTROL'),
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
