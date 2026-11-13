import 'package:flutter/material.dart';

import '../data/db_inspector.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// Hidden, read-only look at the SQLite database — what the file
/// actually holds, as opposed to what the screens choose to show.
/// Reached by the hidden gesture on the menu's About tile; there is no
/// visible entry point. All queries go through DbInspector in lib/data/,
/// which refuses anything that is not a single SELECT.
class DbInspectorScreen extends StatefulWidget {
  const DbInspectorScreen({super.key});

  @override
  State<DbInspectorScreen> createState() => _DbInspectorScreenState();
}

class _DbInspectorScreenState extends State<DbInspectorScreen> {
  final _inspector = DbInspector.instance;
  final _queryController = TextEditingController(text: 'SELECT * FROM storage_items ORDER BY id');

  Map<String, int> _counts = {};
  List<Map<String, Object?>> _rows = [];
  String? _error;
  String? _resultLabel;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    final counts = <String, int>{};
    for (final t in DbInspector.tables) {
      counts[t] = await _inspector.countRows(t);
    }
    if (mounted) setState(() => _counts = counts);
  }

  Future<void> _run(String sql, String label) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final rows = await _inspector.runSelect(sql);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _resultLabel = label;
        _running = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rows = [];
        _resultLabel = null;
        _error = e.toString().replaceFirst('FormatException: ', '');
        _running = false;
      });
    }
  }

  String _fmt(Object? v) {
    if (v == null) return 'NULL';
    if (v is String && v.isEmpty) return "''";
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(screenName: 'Database Inspector'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text('TABLES — tap to browse', style: AppText.dialogSection),
                const SizedBox(height: 4),
                ...DbInspector.tables.map((t) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(t, style: AppText.dialogItem),
                      trailing: Text(
                        _counts.containsKey(t) ? '${_counts[t]} rows' : '…',
                        style: AppText.dialog,
                      ),
                      onTap: _running ? null : () => _run('SELECT * FROM $t ORDER BY id', t),
                    )),
                const Divider(height: 16),
                 Text('QUERY — SELECT only', style: AppText.dialogSection),
                const SizedBox(height: 6),
                TextField(
                  controller: _queryController,
                  maxLines: 3,
                  // The query box is a code field, not prose: no autocorrect
                  // or suggestions (they mangle SQL, and their compose/commit
                  // cycle can swallow the text when Enter is pressed), and
                  // the keyboard's action key is Done — pressing it runs
                  // the query and dismisses the keyboard instead of
                  // inserting a newline into the box.
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  onSubmitted: (_) => _run(_queryController.text, 'Query result'),
                  style: AppText.input,
                  decoration: InputDecoration(
                    hintText: 'SELECT ...',
                    hintStyle: AppText.inputHint,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius)),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: AppSize.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _running
                        ? null
                        : () => _run(_queryController.text, 'Query result'),
                    style: AppButton.primary,
                    child: const Text('Run'),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!, style: AppText.dialogAlert),
                  ),
                if (_resultLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      '$_resultLabel — ${_rows.length} row${_rows.length == 1 ? '' : 's'}${_rows.length >= DbInspector.rowCap ? ' (capped at ${DbInspector.rowCap})' : ''}',
                      style: AppText.dialogNotice,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _running
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _rows.length,
                    itemBuilder: (c, i) {
                      final row = _rows[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.border, width: AppBorder.width),
                          borderRadius: BorderRadius.circular(AppBorder.radius),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...row.entries.map((e) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 1),
                                  child: RichText(
                                    text: TextSpan(
                                      style: AppText.dialog,
                                      children: [
                                        TextSpan(
                                          text: '${e.key}: ',
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                        TextSpan(text: _fmt(e.value)),
                                      ],
                                    ),
                                  ),
                                )),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
