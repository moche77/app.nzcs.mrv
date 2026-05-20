import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// IdPickerOption
///
/// Lightweight value object representing a selectable upstream identifier.
/// Encapsulates the primary identifier plus a human-readable subtitle
/// surfaced alongside it (e.g., supplier name, batch quantity, date).
class IdPickerOption {
  final String id;
  final String subtitle;
  final String? trailingBadge;

  const IdPickerOption({
    required this.id,
    this.subtitle = '',
    this.trailingBadge,
  });
}

/// IdPickerField
///
/// Read-only form field that opens a modal bottom-sheet picker exposing
/// upstream-department identifiers for selection. Supports both single-select
/// and multi-select semantics with searchable filtering.
///
/// Usage:
/// ```
/// IdPickerField(
///   label: 'Linked Feedstock Load IDs',
///   options: feedstockOptions,
///   selected: _selectedFeedstockIds,
///   multiSelect: true,
///   onChanged: (ids) => setState(() => _selectedFeedstockIds = ids),
/// );
/// ```
class IdPickerField extends StatelessWidget {
  final String label;
  final String? helperText;
  final List<IdPickerOption> options;
  final List<String> selected;
  final bool multiSelect;
  final bool required;
  final String emptyHint;
  final ValueChanged<List<String>> onChanged;

  const IdPickerField({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.multiSelect = false,
    this.required = false,
    this.helperText,
    this.emptyHint = 'No upstream records available — create one first.',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
              if (required)
                const Text(' *',
                    style: TextStyle(
                        color: AppTheme.dangerRed,
                        fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: options.isEmpty
                ? () => _showEmptyToast(context)
                : () => _openPicker(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppTheme.dividerGray),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildSelectedDisplay()),
                  const Icon(Icons.arrow_drop_down,
                      color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 4),
            Text(helperText!,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedDisplay() {
    if (selected.isEmpty) {
      return Text(
        multiSelect ? 'Tap to select one or more IDs' : 'Tap to select an ID',
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
      );
    }
    if (!multiSelect) {
      return Text(
        selected.first,
        style: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            fontSize: 14),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: selected
          .map((id) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
                ),
                child: Text(
                  id,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen),
                ),
              ))
          .toList(),
    );
  }

  void _showEmptyToast(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(emptyHint),
        backgroundColor: AppTheme.warningAmber,
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _PickerSheet(
        label: label,
        options: options,
        initialSelection: selected,
        multiSelect: multiSelect,
      ),
    );
    if (result != null) onChanged(result);
  }
}

class _PickerSheet extends StatefulWidget {
  final String label;
  final List<IdPickerOption> options;
  final List<String> initialSelection;
  final bool multiSelect;

  const _PickerSheet({
    required this.label,
    required this.options,
    required this.initialSelection,
    required this.multiSelect,
  });

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  late Set<String> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options.where((o) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return o.id.toLowerCase().contains(q) ||
          o.subtitle.toLowerCase().contains(q);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.dividerGray,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.multiSelect
                        ? 'Select ${widget.label}'
                        : 'Select ${widget.label}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (widget.multiSelect)
                  Text('${_selected.length} selected',
                      style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by ID or detail…',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No matching identifiers found.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final opt = filtered[i];
                      final isSelected = _selected.contains(opt.id);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: widget.multiSelect
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selected.add(opt.id);
                                    } else {
                                      _selected.remove(opt.id);
                                    }
                                  });
                                },
                              )
                            : Radio<String>(
                                value: opt.id,
                                groupValue: _selected.isEmpty
                                    ? null
                                    : _selected.first,
                                onChanged: (v) {
                                  setState(() {
                                    _selected = {v!};
                                  });
                                },
                              ),
                        title: Text(
                          opt.id,
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5),
                        ),
                        subtitle: opt.subtitle.isEmpty
                            ? null
                            : Text(opt.subtitle,
                                style: const TextStyle(fontSize: 11.5)),
                        trailing: opt.trailingBadge == null
                            ? null
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.emerald
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(opt.trailingBadge!,
                                    style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.emerald)),
                              ),
                        onTap: () {
                          setState(() {
                            if (widget.multiSelect) {
                              if (isSelected) {
                                _selected.remove(opt.id);
                              } else {
                                _selected.add(opt.id);
                              }
                            } else {
                              _selected = {opt.id};
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.dividerGray)),
              color: Colors.white,
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  if (widget.multiSelect)
                    TextButton(
                      onPressed: () => setState(() => _selected.clear()),
                      child: const Text('Clear'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, _selected.toList()),
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(widget.multiSelect
                        ? 'Confirm (${_selected.length})'
                        : 'Confirm'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
