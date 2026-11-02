import 'package:flutter/material.dart';
import '../data/location_data.dart';
import '../theme/app_theme.dart';

/// Location filter - similar to required_section.dart location part
/// but NO chips, NO add. Just fields that open picker sheets.
/// isStorage flag picks different Specific lists.
class LocationFilterSection extends StatelessWidget {
  final LocationData data;
  final bool isStorage;
  final String selectedGeneral;
  final String? selectedSpecific;
  final ValueChanged<String> onGeneralChanged;
  final ValueChanged<String?> onSpecificChanged;

  const LocationFilterSection({
    super.key,
    required this.data,
    required this.isStorage,
    required this.selectedGeneral,
    required this.selectedSpecific,
    required this.onGeneralChanged,
    required this.onSpecificChanged,
  });

  List<String> get generalList => data.generalNames;

  List<String> specificsFor(String generalName) {
    if (generalName == 'All' || generalName.isEmpty) return [];
    final genId = data.generalIdForName(generalName);
    if (genId.isEmpty) return [];
    return isStorage
        ? data.storageSpecificNamesFor(genId)
        : data.inventorySpecificNamesFor(genId);
  }

  static bool matchesFilter({
    required String place,
    String? bin,
    required String filterGeneral,
    String? filterSpecific,
  }) {
    if (filterGeneral != 'All' && filterGeneral.isNotEmpty && place != filterGeneral) return false;
    if (filterSpecific != null && filterSpecific.isNotEmpty && (bin ?? '') != filterSpecific) return false;
    return true;
  }

  Future<void> openGeneralPicker(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sheet)),
      builder: (c) => _GeneralPickerSheet(
        title: 'General',
        existing: ['All', ...generalList],
        hint: 'Search General',
      ),
    );
    if (result != null) {
      onGeneralChanged(result);
      if (result == 'All') {
        onSpecificChanged(null);
      } else {
        final newSpecs = specificsFor(result);
        if (selectedSpecific != null && !newSpecs.contains(selectedSpecific)) {
          onSpecificChanged(null);
        }
      }
    }
  }

  Future<void> openSpecificPicker(BuildContext context) async {
    if (selectedGeneral == 'All' || selectedGeneral.isEmpty) return;
    final specifics = specificsFor(selectedGeneral);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sheet)),
      builder: (c) => _SpecificPickerSheet(
        title: 'Specific for $selectedGeneral',
        existing: specifics,
        hint: 'Search Specific',
        parentGeneral: selectedGeneral,
      ),
    );
    if (result != null) {
      if (result.isEmpty) {
        onSpecificChanged(null);
      } else {
        onSpecificChanged(result);
      }
    }
  }

  String get summaryDisplay {
    if (selectedGeneral == 'All' || selectedGeneral.isEmpty) return 'All locations';
    if (selectedSpecific == null || selectedSpecific!.isEmpty) return selectedGeneral;
    return '$selectedGeneral / $selectedSpecific';
  }

  String get specificFieldValue {
    if (selectedSpecific == null || selectedSpecific!.isEmpty) return 'All';
    return selectedSpecific!;
  }

  Widget buildLocationField({
    required String label,
    required String value,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.dialogSection),
        SizedBox(height: 4),
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppBorder.radius),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border, width: AppBorder.width),
              borderRadius: BorderRadius.circular(AppBorder.radius),
              color: enabled ? AppColors.white : AppColors.scaffold,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value.isEmpty ? '—' : value,
                    style: TextStyle(
                      color: enabled ? AppColors.textPrimary : AppColors.textDisabled,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: enabled ? AppColors.textDisabled : AppColors.buttonBgDisabled),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasGeneral = selectedGeneral != 'All' && selectedGeneral.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Location:', style: AppText.dialogSection),
        SizedBox(height: 2),
        Text(
          summaryDisplay,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 12),
        buildLocationField(
          label: 'General Area (All = no filter)',
          value: selectedGeneral,
          enabled: true,
          onTap: () => openGeneralPicker(context),
        ),
        SizedBox(height: 12),
        buildLocationField(
          label: '${isStorage ? "Storage" : "Inventory"} Specific Area (optional)',
          value: specificFieldValue,
          enabled: hasGeneral,
          onTap: () => openSpecificPicker(context),
        ),
        if (!hasGeneral)
          Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Select a General to filter by Specific',
              style: TextStyle(fontSize: 11, color: AppColors.textDisabled, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}

class _GeneralPickerSheet extends StatefulWidget {
  final String title;
  final List<String> existing;
  final String hint;
  const _GeneralPickerSheet({required this.title, required this.existing, required this.hint});
  @override
  State<_GeneralPickerSheet> createState() => _GeneralPickerSheetState();
}

class _GeneralPickerSheetState extends State<_GeneralPickerSheet> {
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
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (c, scroll) => Padding(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Text(widget.title, style: AppText.dialogTitle),
            Spacer(),
            IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context))
          ]),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius)),
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: filtered.length,
              itemBuilder: (c, i) {
                final e = filtered[i];
                return ListTile(
                  title: Text(e, style: AppText.dialogItem),
                  onTap: () => Navigator.pop(context, e),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _SpecificPickerSheet extends StatefulWidget {
  final String title;
  final List<String> existing;
  final String hint;
  final String parentGeneral;
  const _SpecificPickerSheet({required this.title, required this.existing, required this.hint, required this.parentGeneral});
  @override
  State<_SpecificPickerSheet> createState() => _SpecificPickerSheetState();
}

class _SpecificPickerSheetState extends State<_SpecificPickerSheet> {
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
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (c, scroll) => Padding(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Text(widget.title, style: AppText.dialogTitle),
            Spacer(),
            IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context))
          ]),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius)),
            ),
          ),
          SizedBox(height: 8),
          ListTile(
            title: Text('All in ${widget.parentGeneral}', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('No specific filter', style: TextStyle(fontSize: 11)),
            onTap: () => Navigator.pop(context, ''),
          ),
          Divider(),
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text('No matches', style: TextStyle(color: AppColors.textDisabled)))
                : ListView.builder(
                    controller: scroll,
                    itemCount: filtered.length,
                    itemBuilder: (c, i) {
                      final e = filtered[i];
                      return ListTile(
                        title: Text(e, style: AppText.dialogItem),
                        onTap: () => Navigator.pop(context, e),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
