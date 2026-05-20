import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/data_models.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';

class GlobalQAScreen extends StatelessWidget {
  final bool readOnly;
  const GlobalQAScreen({super.key, this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final qas = data.getGlobalQA();
    return Scaffold(
      body: qas.isEmpty
          ? const EmptyState(
              icon: Icons.fact_check_outlined,
              title: 'No QA Records',
              message:
                  'One control row per monitoring period (YYYY-MM). Reviewer signs off MRV completeness.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: qas.length,
              itemBuilder: (_, i) {
                final q = qas[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text('Period: ${q.monitoringPeriod}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                        ),
                        StatusBadge(
                            status: q.completenessConfirmation.toUpperCase() ==
                                    'YES'
                                ? 'PASS'
                                : 'FAIL'),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Reviewer: ${q.reviewerName} · ${Fmt.date(q.dateReviewed)}',
                              style: const TextStyle(fontSize: 12)),
                          if (q.comments.isNotEmpty)
                            Text(q.comments,
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
                                _open(context, existing: q);
                              } else if (v == 'delete') {
                                data.deleteGlobalQA(q.id);
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
              label: const Text('NEW QA',
                  style: TextStyle(color: Colors.white)),
            ),
    );
  }

  void _open(BuildContext context, {GlobalQA? existing}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GlobalQAEditor(existing: existing)),
    );
  }
}

class GlobalQAEditor extends StatefulWidget {
  final GlobalQA? existing;
  const GlobalQAEditor({super.key, this.existing});

  @override
  State<GlobalQAEditor> createState() => _GlobalQAEditorState();
}

class _GlobalQAEditorState extends State<GlobalQAEditor> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _period;
  late TextEditingController _reviewer;
  late TextEditingController _comments;
  late DateTime _date;
  String _completeness = 'yes';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = DateTime.now();
    final currentPeriod =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    _period =
        TextEditingController(text: e?.monitoringPeriod ?? currentPeriod);
    _reviewer = TextEditingController(text: e?.reviewerName ?? '');
    _comments = TextEditingController(text: e?.comments ?? '');
    _date = e?.dateReviewed ?? DateTime.now();
    if (e != null) _completeness = e.completenessConfirmation;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final data = context.read<DataService>();
    final auth = context.read<AuthService>();
    final qa = GlobalQA(
      id: widget.existing?.id ?? data.newId(),
      monitoringPeriod: _period.text.trim(),
      completenessConfirmation: _completeness,
      reviewerName: _reviewer.text.trim(),
      dateReviewed: _date,
      comments: _comments.text.trim(),
      enteredBy: auth.currentUser?.username ?? 'unknown',
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    await data.saveGlobalQA(qa);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Global QA record saved'),
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
            widget.existing == null ? 'New QA Record' : 'Edit QA Record'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FormFieldWrapper(
                label: 'Monitoring Period (YYYY-MM, auto-populated)',
                required: true,
                child: TextFormField(
                  controller: _period,
                  readOnly: true,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    suffixIcon: Icon(Icons.lock_outline, size: 18),
                    helperText:
                        'System-derived from current calendar month — not editable',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final regex = RegExp(r'^\d{4}-\d{2}$');
                    if (!regex.hasMatch(v.trim())) return 'Format: YYYY-MM';
                    return null;
                  },
                ),
              ),
              FormFieldWrapper(
                label: 'MRV Completeness Confirmation',
                required: true,
                child: DropdownButtonFormField<String>(
                  value: _completeness,
                  items: const ['yes', 'no']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _completeness = v!),
                ),
              ),
              FormFieldWrapper(
                label: 'Reviewer Name',
                required: true,
                child: TextFormField(
                  controller: _reviewer,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ),
              FormFieldWrapper(
                label: 'Date Reviewed',
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
                child: TextFormField(controller: _comments, maxLines: 4),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('SAVE QA RECORD'),
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
