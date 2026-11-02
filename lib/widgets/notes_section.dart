import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/app_sheet.dart';

class NotesSection extends StatefulWidget {
  final TextEditingController controller;
  final bool isExpanded;
  final VoidCallback onToggle;
  final String? storageKey;

  const NotesSection({
    super.key,
    required this.controller,
    required this.isExpanded,
    required this.onToggle,
    this.storageKey,
  });

  @override
  State<NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends State<NotesSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isExpanded;
    _load();
  }

  Future<void> _load() async {
    if (widget.storageKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(widget.storageKey!);
    if (saved != null && mounted) setState(() => _expanded = saved);
  }

  @override
  void didUpdateWidget(covariant NotesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isExpanded != widget.isExpanded && widget.storageKey == null) {
      _expanded = widget.isExpanded;
    }
  }

  Future<void> _handleToggle() async {
    setState(() => _expanded = !_expanded);
    if (widget.storageKey != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(widget.storageKey!, _expanded);
    }
    widget.onToggle();
  }

  Future<void> _showNotesDialog(BuildContext context) async {
    final tempCtrl = TextEditingController(text: widget.controller.text);
    final focusNode = FocusNode();

    final result = await showModalTopSheet<String>(
      context: context,
      maxWidth: 600,
      backgroundColor: AppColors.white,
      builder: (c, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Edit Notes', style: AppText.dialogTitle),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(c)),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
                child: TextField(
                  controller: tempCtrl,
                  focusNode: focusNode,
                  minLines: 8,
                  maxLines: 20,
                  scrollPhysics: const AlwaysScrollableScrollPhysics(),
                  autofocus: true,
                  style: AppText.inputMulti,
                  decoration: InputDecoration(
                    hintText: 'Additional details...',
                    hintStyle: AppText.inputHint,
                    contentPadding: AppSize.fieldPaddingMulti,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius)),
                    filled: true,
                    fillColor: AppColors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel', style: AppText.buttonSmall))),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(c, tempCtrl.text),
                    child: const Text('Save', style: AppText.buttonPrimary),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (result != null) widget.controller.text = result;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('NOTES', style: AppText.dialogSection),
            const SizedBox(width: 12),
            InkWell(
              onTap: _handleToggle,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(_expanded ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: AppSize.buttonHeight,
              child: ElevatedButton(
                onPressed: () => _showNotesDialog(context),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: AppSize.buttonMinSize),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_full, size: 12),
                    SizedBox(width: 4),
                    Text('Expand', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_expanded) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: AppSize.fieldHeightMulti,
            child: TextField(
              controller: widget.controller,
              minLines: 3,
              maxLines: 3,
              scrollPhysics: const AlwaysScrollableScrollPhysics(),
              style: AppText.inputMulti,
              decoration: InputDecoration(
                hintText: 'Additional details (optional)',
                hintStyle: AppText.inputHint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius), borderSide: AppBorder.side),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius), borderSide: AppBorder.side),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius), borderSide: const BorderSide(color: AppColors.textPrimary, width: 1)),
                filled: true,
                fillColor: AppColors.white,
                contentPadding: AppSize.fieldPaddingMulti,
                isDense: true,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
