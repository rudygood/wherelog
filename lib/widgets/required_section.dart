import 'package:flutter/material.dart';
import '../data/location_data.dart';
import '../theme/app_theme.dart';

enum RequiredSectionSource { storage, inventory }

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
  @override
  void initState() {
    super.initState();
    widget.generalController.addListener(() => setState(() {}));
    widget.specificController.addListener(() => setState(() {}));
    widget.itemNameController.addListener(() => setState(() {}));
  }

  String get fullLocationDisplay {
    final g = widget.generalController.text.trim();
    final s = widget.specificController.text.trim();
    if (g.isNotEmpty && s.isNotEmpty) return '$g / $s';
    return g.isNotEmpty ? g : s;
  }

  List<String> get generalList => widget.data.generalNames;

  List<String> getSpecificsForCurrentGeneral() {
    final genName = widget.generalController.text.trim();
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
        hint: 'Search or type new General',
        allowBlank: false,
        onAddNew: (name) => addGeneral(name),
        isDuplicate: isDuplicateGeneral,
      ),
    );
    if (r != null) setState(() => widget.generalController.text = r);
  }

  Future<void> openSpecificPicker() async {
    if (widget.generalController.text.trim().isEmpty) return;
    final parent = widget.generalController.text.trim();
    final r = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sheet)),
      builder: (c) => _GeneralSpecificPickerSheet(
        title: 'Specific for $parent',
        existing: getSpecificsForCurrentGeneral(),
        hint: 'Search or type new Specific',
        allowBlank: true,
        onAddNew: (name) => addSpecific(parent, name),
        isDuplicate: (name) => isDuplicateSpecific(parent, name),
      ),
    );
    if (r != null) setState(() => widget.specificController.text = r);
  }

  Widget buildLocationField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required bool isTier1,
    required bool enabled,
    required VoidCallback onPickerTap,
    required VoidCallback onAddTap,
    required List<String> existing,
  }) {
    final filter = controller.text.toLowerCase().trim();
    final filtered = filter.isEmpty ? existing : existing.where((e) => e.toLowerCase().contains(filter)).toList();
    final showDropdown = focusNode.hasFocus && filtered.isNotEmpty;
    final bool canAdd = controller.text.trim().isNotEmpty &&
        (isTier1
            ? !isDuplicateGeneral(controller.text.trim())
            : !isDuplicateSpecific(widget.generalController.text.trim(), controller.text.trim()));
    String? similar;
    if (!isTier1 && controller.text.trim().isNotEmpty) {
      similar = findSimilarSpecific(widget.generalController.text.trim(), controller.text.trim());
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
                onPressed: canAdd ? onAddTap : null,
                style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: AppSize.buttonMinSizeIcon, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Icon(Icons.add, size: 18),
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
          onAddTap: () => addGeneral(widget.generalController.text.trim()),
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
          onAddTap: () => addSpecific(widget.generalController.text.trim(), widget.specificController.text.trim()),
          existing: getSpecificsForCurrentGeneral(),
        ),
        const SizedBox(height: 18),
        Text(widget.source == RequiredSectionSource.storage ? 'Storage Item (required)' : 'Inventory Item (required)', style: AppText.dialogSection),
        const SizedBox(height: 4),
        SizedBox(
          height: AppSize.fieldHeight,
          child: TextField(
            controller: widget.itemNameController,
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
  final void Function(String) onAddNew;
  final bool Function(String) isDuplicate;
  const _GeneralSpecificPickerSheet(
      {required this.title, required this.existing, required this.hint, required this.allowBlank, required this.onAddNew, required this.isDuplicate});
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
    final bool canAdd = filter.trim().isNotEmpty && !widget.isDuplicate(filter.trim());
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
          if (canAdd)
            ListTile(
              leading: const Icon(Icons.add, color: AppColors.textPrimary),
              title: Text('Add "$filter" as new', style: AppText.dialogItemBold),
              onTap: () {
                widget.onAddNew(filter.trim());
                Navigator.pop(context, filter.trim());
              },
            ),
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
