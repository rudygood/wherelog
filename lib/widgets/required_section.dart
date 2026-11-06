import 'package:flutter/material.dart';
import '../data/location_data.dart';
import '../theme/app_theme.dart';

enum RequiredSectionSource { storage, inventory }

/// What a location field's action button currently means, derived from
/// the field's text, the existing names, and the field's anchor.
enum _FieldAction { empty, exact, caseOfAnchor, caseOfOther, diverged, fresh }

class RequiredSection extends StatefulWidget {
  final TextEditingController generalController;
  final TextEditingController specificController;
  final TextEditingController itemNameController;
  final FocusNode generalFocus;
  final FocusNode specificFocus;
  final RequiredSectionSource source;
  final LocationData data;
  final String itemHint;

  const RequiredSection({
    super.key,
    required this.generalController,
    required this.specificController,
    required this.itemNameController,
    required this.generalFocus,
    required this.specificFocus,
    required this.source,
    required this.data,
    this.itemHint = 'Item name',
  });

  @override
  State<RequiredSection> createState() => _RequiredSectionState();
}

class _RequiredSectionState extends State<RequiredSection> {
  /// The last committed existing name each location field displayed.
  /// While the user edits, the text can diverge from the anchor; the
  /// anchor is the location a rename would rename. Anchors change only
  /// at commit points — a pick, or one of the action button's outcomes —
  /// or when the field is left empty; never merely because the text was
  /// edited, so a select-all-and-retype keeps the anchor it began from.
  String? _generalAnchor;
  String? _specificAnchor;

  @override
  void initState() {
    super.initState();
    widget.generalController.addListener(() => setState(() {}));
    widget.specificController.addListener(() => setState(() {}));
    widget.itemNameController.addListener(() => setState(() {}));
    final g = widget.generalController.text.trim();
    if (generalList.contains(g)) _generalAnchor = g;
    final s = widget.specificController.text.trim();
    if (s.isNotEmpty && getSpecificsForCurrentGeneral().contains(s)) {
      _specificAnchor = s;
    }
    widget.generalFocus.addListener(() {
      if (!widget.generalFocus.hasFocus &&
          widget.generalController.text.trim().isEmpty) {
        _generalAnchor = null;
      }
    });
    widget.specificFocus.addListener(() {
      if (!widget.specificFocus.hasFocus &&
          widget.specificController.text.trim().isEmpty) {
        _specificAnchor = null;
      }
    });
  }

  /// Commits [name] as the general field's anchor. Specifics live under
  /// the general, so the specific anchor survives a general commit only
  /// if its text still names a specific under the committed general.
  /// Callers set the general controller's text first.
  void _commitGeneralAnchor(String? name) {
    _generalAnchor = name;
    final s = widget.specificController.text.trim();
    _specificAnchor = (name != null &&
            s.isNotEmpty &&
            getSpecificsForCurrentGeneral().contains(s))
        ? s
        : null;
  }

  String get fullLocationDisplay {
    final g = widget.generalController.text.trim();
    final s = widget.specificController.text.trim();
    if (g.isNotEmpty && s.isNotEmpty) return '$g / $s';
    return g.isNotEmpty ? g : s;
  }

  List<String> get generalList => widget.data.generalNames;

  /// The general whose specifics are in scope. While the general
  /// field's text names an existing general, that general; while the
  /// text has diverged from the committed anchor without naming
  /// another existing general (a rename in progress, a half-typed
  /// name), the anchor — the specific context must not vanish mid-edit
  /// just because the edit is not committed yet.
  String get scopedGeneralName {
    final text = widget.generalController.text.trim();
    if (text.isNotEmpty && widget.data.generalIdForName(text).isNotEmpty) {
      return text;
    }
    return _generalAnchor ?? text;
  }

  List<String> getSpecificsForCurrentGeneral() {
    final genName = scopedGeneralName;
    if (genName.isEmpty) return [];
    final genId = widget.data.generalIdForName(genName);
    if (genId.isEmpty) return [];
    return widget.source == RequiredSectionSource.storage
        ? widget.data.storageSpecificNamesFor(genId)
        : widget.data.inventorySpecificNamesFor(genId);
  }

  bool isDuplicateGeneral(String name) => widget.data.isDuplicateGeneral(name);

  bool isDuplicateSpecific(String parent, String name) {
    final genId = widget.data.generalIdForName(parent);
    if (genId.isEmpty) return false;
    return widget.source == RequiredSectionSource.storage
        ? widget.data.isDuplicateStorageSpecific(genId, name)
        : widget.data.isDuplicateInventorySpecific(genId, name);
  }

  String? findSimilarSpecific(String parent, String newName) {
    final list = widget.data.specificNamesByGeneralName(
      parent,
      storage: widget.source == RequiredSectionSource.storage,
    );
    final nl = newName.toLowerCase();
    for (final ex in list) {
      if (ex.toLowerCase().contains(nl) || nl.contains(ex.toLowerCase())) {
        if (ex.toLowerCase() != nl) return ex;
      }
    }
    return null;
  }

  Future<void> addGeneral(String name) async {
    final t = name.trim();
    if (t.isEmpty || isDuplicateGeneral(t)) return;
    await widget.data.addGeneral(t);
    _commitGeneralAnchor(t);
    if (mounted) setState(() {});
  }

  Future<void> addSpecific(String parent, String name) async {
    final p = parent.trim();
    final t = name.trim();
    if (p.isEmpty || t.isEmpty || isDuplicateSpecific(p, t)) return;
    final genId = widget.data.generalIdForName(p);
    if (genId.isEmpty) return;
    if (widget.source == RequiredSectionSource.storage) {
      await widget.data.addStorageSpecific(genId, t);
    } else {
      await widget.data.addInventorySpecific(genId, t);
    }
    _specificAnchor = t;
    if (mounted) setState(() {});
  }

  Future<void> renameGeneral(String oldName, String newName) async {
    final t = newName.trim();
    if (t.isEmpty) return;
    await widget.data.renameGeneral(oldName, t);
    _commitGeneralAnchor(t);
    if (mounted) setState(() {});
  }

  Future<void> renameSpecific(String oldName, String newName) async {
    final t = newName.trim();
    if (t.isEmpty) return;
    // The anchor specific lives under the committed general, which is
    // not necessarily the general field's (possibly diverged) text.
    final parent = _generalAnchor ?? widget.generalController.text.trim();
    if (widget.source == RequiredSectionSource.storage) {
      await widget.data.renameStorageSpecific(parent, oldName, t);
    } else {
      await widget.data.renameInventorySpecific(parent, oldName, t);
    }
    _specificAnchor = t;
    if (mounted) setState(() {});
  }

  Future<void> openGeneralPicker() async {
    final r = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sheet)),
      builder: (c) => _GeneralSpecificPickerSheet(
        title: 'General',
        existing: generalList,
        hint: 'Search General',
        allowBlank: false,
      ),
    );
    if (r != null) {
      setState(() => widget.generalController.text = r);
      _commitGeneralAnchor(r.isEmpty ? null : r);
    }
  }

  Future<void> openSpecificPicker() async {
    if (widget.generalController.text.trim().isEmpty) return;
    final parent = scopedGeneralName;
    final r = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sheet)),
      builder: (c) => _GeneralSpecificPickerSheet(
        title: 'Specific for $parent',
        existing: getSpecificsForCurrentGeneral(),
        hint: 'Search Specific',
        allowBlank: true,
      ),
    );
    if (r != null) {
      setState(() => widget.specificController.text = r);
      _specificAnchor = r.isEmpty ? null : r;
    }
  }

  /// The stored spelling an existing name matches [text] with, ignoring
  /// case, or null when no existing name matches even loosely.
  String? _caseInsensitiveMatch(List<String> existing, String text) {
    final lower = text.toLowerCase();
    for (final e in existing) {
      if (e.toLowerCase() == lower) return e;
    }
    return null;
  }

  _FieldAction _actionFor(
      TextEditingController controller, List<String> existing, bool isTier1) {
    final text = controller.text.trim();
    if (text.isEmpty) return _FieldAction.empty;
    if (existing.contains(text)) return _FieldAction.exact;
    final ci = _caseInsensitiveMatch(existing, text);
    if (ci != null) {
      return ci == (isTier1 ? _generalAnchor : _specificAnchor)
          ? _FieldAction.caseOfAnchor
          : _FieldAction.caseOfOther;
    }
    final anchor = isTier1 ? _generalAnchor : _specificAnchor;
    if (anchor != null && text != anchor) return _FieldAction.diverged;
    return _FieldAction.fresh;
  }

  Future<void> _onFieldAction({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isTier1,
    required List<String> existing,
  }) async {
    final text = controller.text.trim();
    switch (_actionFor(controller, existing, isTier1)) {
      case _FieldAction.empty:
        break;
      case _FieldAction.exact:
        // The name already names an existing location; proceeding just
        // commits it as this field's selection.
        if (isTier1) {
          _commitGeneralAnchor(text);
        } else {
          _specificAnchor = text;
        }
        focusNode.unfocus();
        setState(() {});
        break;
      case _FieldAction.fresh:
        if (isTier1) {
          await addGeneral(text);
        } else {
          await addSpecific(scopedGeneralName, text);
        }
        break;
      case _FieldAction.caseOfOther:
        final stored = _caseInsensitiveMatch(existing, text)!;
        final use = await _confirmUseExisting(text, stored);
        if (!mounted || use != true) return;
        controller.text = stored;
        controller.selection =
            TextSelection.fromPosition(TextPosition(offset: stored.length));
        if (isTier1) {
          _commitGeneralAnchor(stored);
        } else {
          _specificAnchor = stored;
        }
        setState(() {});
        break;
      case _FieldAction.caseOfAnchor:
        final anchor = (isTier1 ? _generalAnchor : _specificAnchor)!;
        final change = await _confirmCaseChange(anchor, text);
        if (!mounted || change != true) return;
        if (isTier1) {
          await renameGeneral(anchor, text);
        } else {
          await renameSpecific(anchor, text);
        }
        break;
      case _FieldAction.diverged:
        final anchor = (isTier1 ? _generalAnchor : _specificAnchor)!;
        final choice = await _chooseChangeOrAdd(anchor, text, isTier1);
        if (!mounted) return;
        if (choice == 'change') {
          if (isTier1) {
            await renameGeneral(anchor, text);
          } else {
            await renameSpecific(anchor, text);
          }
        } else if (choice == 'add') {
          if (isTier1) {
            await addGeneral(text);
          } else {
            await addSpecific(scopedGeneralName, text);
          }
        }
        break;
    }
  }

  Future<bool?> _confirmUseExisting(String typed, String stored) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Capitalization differs', style: AppText.dialogTitle),
        content: Text('"$typed" matches the existing "$stored" except for capitalization.',
            style: AppText.dialog),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text('Use "$stored"')),
        ],
      ),
    );
  }

  Future<bool?> _confirmCaseChange(String anchor, String text) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Change capitalization', style: AppText.dialogTitle),
        content: Text(
            'Change "$anchor" to "$text"? Only the capitalization is different; every item filed under it keeps the new spelling.',
            style: AppText.dialog),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Change')),
        ],
      ),
    );
  }

  Future<String?> _chooseChangeOrAdd(String anchor, String text, bool isTier1) {
    final parent = _generalAnchor ?? widget.generalController.text.trim();
    final addLabel = isTier1
        ? 'Add New General Area "$text"'
        : 'Add New Specific Area "$text" in "$parent"';
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rename or add?', style: AppText.dialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('This field held "$anchor". What should "$text" be?',
                style: AppText.dialog),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: () => Navigator.pop(c, 'change'),
                child: Text('Change "$anchor" to "$text"')),
            const SizedBox(height: 8),
            ElevatedButton(
                onPressed: () => Navigator.pop(c, 'add'),
                child: Text(addLabel)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        ],
      ),
    );
  }

  Widget buildLocationField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required bool isTier1,
    required bool enabled,
    required VoidCallback onPickerTap,
    required List<String> existing,
  }) {
    final filter = controller.text.toLowerCase().trim();
    final filtered = filter.isEmpty ? existing : existing.where((e) => e.toLowerCase().contains(filter)).toList();
    final showDropdown = focusNode.hasFocus && filtered.isNotEmpty;
    final action = _actionFor(controller, existing, isTier1);
    final IconData actionIcon;
    if (action == _FieldAction.exact) {
      actionIcon = Icons.check;
    } else if (action == _FieldAction.diverged ||
        action == _FieldAction.caseOfAnchor ||
        action == _FieldAction.caseOfOther) {
      actionIcon = Icons.chevron_right;
    } else {
      actionIcon = Icons.add;
    }
    String? similar;
    if (!isTier1 && controller.text.trim().isNotEmpty) {
      similar = findSimilarSpecific(scopedGeneralName, controller.text.trim());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: AppSize.fieldHeight,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  textCapitalization: TextCapitalization.words,
                  style: AppText.input,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppText.inputHint,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius)),
                    filled: true,
                    fillColor: enabled ? AppColors.white : AppColors.scaffoldDark,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  onTap: () => setState(() {}),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 36,
              height: AppSize.fieldHeight,
              child: ElevatedButton(
                onPressed: enabled ? onPickerTap : null,
                style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: AppSize.buttonMinSizeIcon, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Icon(Icons.arrow_drop_down, size: 20),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 36,
              height: AppSize.fieldHeight,
              child: ElevatedButton(
                onPressed: enabled && action != _FieldAction.empty
                    ? () => _onFieldAction(
                        controller: controller,
                        focusNode: focusNode,
                        isTier1: isTier1,
                        existing: existing)
                    : null,
                style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: AppSize.buttonMinSizeIcon, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Icon(actionIcon, size: 18),
              ),
            ),
          ],
        ),
        if (showDropdown)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.border, width: AppBorder.width),
              borderRadius: BorderRadius.circular(AppBorder.radius),
              boxShadow: const [BoxShadow(color: AppColors.border, blurRadius: 4, offset: Offset(0, 2))],
            ),
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length > 6 ? 6 : filtered.length,
              itemBuilder: (c, i) {
                final e = filtered[i];
                final bool isExact = e.toLowerCase() == filter;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) {
                    controller.text = e;
                    controller.selection = TextSelection.fromPosition(TextPosition(offset: e.length));
                    if (isTier1) {
                      _commitGeneralAnchor(e);
                    } else {
                      _specificAnchor = e;
                    }
                    setState(() {});
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (focusNode.hasFocus) focusNode.unfocus();
                    });
                  },
                  child: ListTile(
                    dense: true,
                    title: Text(e, style: TextStyle(fontWeight: isExact ? FontWeight.bold : FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                    trailing: isExact ? const Icon(Icons.check, size: 16, color: AppColors.textPrimary) : null,
                  ),
                );
              },
            ),
          ),
        if (similar != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text('Similar to "$similar" exists — select it from the list above',
                style: TextStyle(fontSize: 11, color: AppColors.warningText, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemText = widget.itemNameController.text.trim();
    final locText = fullLocationDisplay;
    String summary;
    if (itemText.isEmpty && locText.isEmpty) {
      summary = '—';
    } else if (itemText.isNotEmpty && locText.isNotEmpty) {
      summary = '$itemText @ $locText';
    } else if (itemText.isNotEmpty) {
      summary = itemText;
    } else {
      summary = '@ $locText';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('LOCATION', style: AppText.dialogSection),
        const SizedBox(height: 2),
        SizedBox(
          height: 48,
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(summary,
                style: AppText.input,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(height: 10),
        const Text('General Area (required)', style: AppText.dialogSection),
        const SizedBox(height: 4),
        buildLocationField(
          controller: widget.generalController,
          focusNode: widget.generalFocus,
          hint: 'e.g. Garage, Attic',
          isTier1: true,
          enabled: true,
          onPickerTap: openGeneralPicker,
          existing: generalList,
        ),
        const SizedBox(height: 12),
        Text('${widget.source == RequiredSectionSource.storage ? "Storage" : "Inventory"} Specific Area (optional)',
            style: AppText.dialogSection),
        const SizedBox(height: 4),
        buildLocationField(
          controller: widget.specificController,
          focusNode: widget.specificFocus,
          hint: 'e.g. Bin 1, Shelf A (optional)',
          isTier1: false,
          enabled: widget.generalController.text.trim().isNotEmpty,
          onPickerTap: openSpecificPicker,
          existing: getSpecificsForCurrentGeneral(),
        ),
        const SizedBox(height: 18),
        Text(widget.source == RequiredSectionSource.storage ? 'Storage Item (required)' : 'Inventory Item (required)', style: AppText.dialogSection),
        const SizedBox(height: 4),
        SizedBox(
          height: AppSize.fieldHeight,
          child: TextField(
            controller: widget.itemNameController,
            textCapitalization: TextCapitalization.words,
            style: AppText.input,
            decoration: InputDecoration(
              hintText: widget.itemHint,
              hintStyle: AppText.inputHint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius)),
              filled: true,
              fillColor: AppColors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _GeneralSpecificPickerSheet extends StatefulWidget {
  final String title;
  final List<String> existing;
  final String hint;
  final bool allowBlank;
  const _GeneralSpecificPickerSheet(
      {required this.title, required this.existing, required this.hint, required this.allowBlank});
  @override
  State<_GeneralSpecificPickerSheet> createState() => _GeneralSpecificPickerSheetState();
}

class _GeneralSpecificPickerSheetState extends State<_GeneralSpecificPickerSheet> {
  late TextEditingController searchController;
  String filter = '';
  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();
    searchController.addListener(() => setState(() => filter = searchController.text));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.existing.where((e) => filter.isEmpty || e.toLowerCase().contains(filter.toLowerCase())).toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (c, scroll) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Text(widget.title, style: AppText.dialogTitle),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
          ]),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius)),
            ),
          ),
          const SizedBox(height: 8),
          if (widget.allowBlank) ListTile(title: const Text('(None)', style: AppText.dialogItem), onTap: () => Navigator.pop(context, '')),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: filtered.length,
              itemBuilder: (c, i) {
                final e = filtered[i];
                return ListTile(title: Text(e, style: AppText.dialogItem), onTap: () => Navigator.pop(context, e));
              },
            ),
          ),
        ]),
      ),
    );
  }
}
