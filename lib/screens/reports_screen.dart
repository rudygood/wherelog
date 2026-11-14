import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/inventory_records.dart';
import '../data/photo_store.dart';
import '../data/sqlite_inventory_repository.dart';
import '../data/sqlite_location_repository.dart';
import '../data/sqlite_storage_repository.dart';
import '../services/directory_access_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import 'report_preview_screen.dart';

/// Reports menu page (2026-11-13): the printable, shareable outputs.
/// Two jobs, both about the data leaving the app in a usable form:
///
/// 1. A Home Inventory Report — an itemized PDF, grouped by General
///    location with the Specific location as a column, serial numbers,
///    dates, values and a total. It opens as a preview with print and
///    share built in; sharing to Files is how a saved copy is made.
///    A check mark in the Photo column shows an item has a photo on
///    file. Suitable as an insurance record. No purchase-price
///    column, by design: what was paid can only work against a
///    claim on a gift or a bargain — the replacement value is the
///    number on the record.
/// 2. The three location lists as CSV files — General locations,
///    Storage specifics, Inventory specifics — so the location data
///    is never locked inside the app.
///
/// The complete backup of everything, photos included, is the
/// Export / Import ZIP; these reports are the readable layer on
/// top of it, not a replacement for it.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _locRepo = SqliteLocationRepository.instance;
  final _invRepo = SqliteInventoryRepository.instance;
  final _storageRepo = SqliteStorageRepository.instance;

  bool _isWorking = false;
  String _status = '';

  // --- small formatters (no new dependencies) ---

  String _money(int? cents) {
    if (cents == null) return '-';
    final negative = cents < 0;
    final abs = cents.abs();
    final dollars = abs ~/ 100;
    final rem = abs % 100;
    final ds = dollars.toString();
    final grouped = StringBuffer();
    for (var i = 0; i < ds.length; i++) {
      if (i > 0 && (ds.length - i) % 3 == 0) grouped.write(',');
      grouped.write(ds[i]);
    }
    return '${negative ? '-\$' : '\$'}${grouped.toString()}.${rem.toString().padLeft(2, '0')}';
  }

  String _csv(String? s) {
    final v = s ?? '';
    if (v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  String _todayStamp() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // --- folder picking (same pattern as Export; CSVs only now) ---

  Future<String?> _pickFolder(String title) async {
    if (Platform.isIOS) {
      return DirectoryAccessService.pickDirectory();
    }
    try {
      return await FilePicker.getDirectoryPath(dialogTitle: title);
    } catch (_) {
      return null;
    }
  }

  // --- insurance report (PDF preview) ---

  void _openInsuranceReport() {
    final stamp = _todayStamp();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportPreviewScreen(
          buildPdf: _buildInsurancePdf,
          fileName: 'WhereLog-Home-Inventory-Report-$stamp.pdf',
        ),
      ),
    );
  }

  // The PDF fonts are the built-in Helvetica set, which only covers
  // the Latin-1 range (U+0020-U+00FF). Anything outside that (an
  // emoji in a note, an em dash) would come out as a boxed X, so
  // user text is washed: common punctuation is folded to its plain
  // equivalent, the rest becomes '?'.
  String _pdfSafe(String s) {
    const fold = {0x2013: '-', 0x2014: '-', 0x2018: "'", 0x2019: "'", 0x201C: '"', 0x201D: '"', 0x2022: '-', 0x2026: '...'};
    final out = StringBuffer();
    for (final r in s.runes) {
      final folded = fold[r];
      if (folded != null) {
        out.write(folded);
      } else if (r < 128 || (r >= 0xA0 && r <= 0xFF)) {
        out.writeCharCode(r);
      } else {
        out.write('?');
      }
    }
    return out.toString();
  }

  Future<Uint8List> _buildInsurancePdf(PdfPageFormat format) async {
    final generals = await _locRepo.getGenerals();
    final specifics = await _locRepo.getInventorySpecifics();
    final items = await _invRepo.getAll();
    generals.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final specificName = {for (final s in specifics) s.id: s.name};

    // Grouped on General only; the Specific location is a column.
    // Within a General, items cluster by Specific, then by name.
    final byGeneral = <int, List<InventoryItem>>{};
    for (final item in items) {
      byGeneral.putIfAbsent(item.generalId, () => []).add(item);
    }
    for (final gItems in byGeneral.values) {
      gItems.sort((a, b) {
        final sa = specificName[a.specificId] ?? '';
        final sb = specificName[b.specificId] ?? '';
        final bySpec = sa.toLowerCase().compareTo(sb.toLowerCase());
        if (bySpec != 0) return bySpec;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }

    // A photo on file is a check mark in the Photo column.
    Future<bool> hasPhoto(InventoryItem item) async {
      final filename = item.photoFilename;
      if (filename == null || filename.isEmpty) return false;
      final file = await PhotoStore.fileFor(filename);
      return file.exists();
    }

    // --- pdf cell helpers ---

    pw.Widget cell(String text, {pw.TextAlign align = pw.TextAlign.left, bool bold = false, double size = 9.5}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        child: pw.Text(
          _pdfSafe(text),
          textAlign: align,
          style: pw.TextStyle(font: bold ? pw.Font.helveticaBold() : pw.Font.helvetica(), fontSize: size),
        ),
      );
    }

    pw.Widget headCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
      return pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(2, 0, 2, 3),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(width: 1.5, color: PdfColors.grey800)),
        ),
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 9.5),
        ),
      );
    }

    pw.Widget photoCell(bool has) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        child: pw.Text(
          has ? '\u2713' : '',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: pw.Font.zapfDingbats(), fontSize: 11),
        ),
      );
    }

    // Fixed columns total 452pt; letter landscape is 792pt wide,
    // 720pt after the half-inch margins — the name column takes
    // what is left (about 268pt).
    const columnWidths = <int, pw.TableColumnWidth>{
      0: pw.FlexColumnWidth(1),
      1: pw.FixedColumnWidth(95),
      2: pw.FixedColumnWidth(85),
      3: pw.FixedColumnWidth(65),
      4: pw.FixedColumnWidth(32),
      5: pw.FixedColumnWidth(68),
      6: pw.FixedColumnWidth(75),
      7: pw.FixedColumnWidth(32),
    };

    final stamp = _todayStamp();
    var grandTotal = 0;
    var grandUnvalued = 0;
    final sections = <pw.Widget>[];

    for (final general in generals) {
      final gItems = byGeneral[general.id] ?? const <InventoryItem>[];
      var subtotal = 0;
      var unvalued = 0;
      for (final item in gItems) {
        if (item.valueCents != null) {
          subtotal += item.valueCents! * item.quantity;
        } else {
          unvalued++;
        }
      }
      grandTotal += subtotal;
      grandUnvalued += unvalued;

      sections.add(pw.Text(_pdfSafe(general.name),
          style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 13)));
      sections.add(pw.SizedBox(height: 4));
      if (gItems.isEmpty) {
        sections.add(pw.Text('No home inventory items recorded here.',
            style: pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)));
        sections.add(pw.SizedBox(height: 10));
        continue;
      }

      final rows = <pw.TableRow>[
        pw.TableRow(children: [
          headCell('Item'),
          headCell('Specific location'),
          headCell('Serial no.'),
          headCell('Acquired'),
          headCell('Qty', align: pw.TextAlign.right),
          headCell('Value each', align: pw.TextAlign.right),
          headCell('Line total', align: pw.TextAlign.right),
          headCell('Photo', align: pw.TextAlign.center),
        ]),
      ];
      for (final item in gItems) {
        final brandModel = [
          if (item.brand != null && item.brand!.isNotEmpty) item.brand!,
          if (item.model != null && item.model!.isNotEmpty) item.model!,
        ].join(' · ');
        final name = brandModel.isEmpty ? item.name : '${item.name}  ·  $brandModel';
        final lineTotal = item.valueCents != null ? _money(item.valueCents! * item.quantity) : '-';
        rows.add(pw.TableRow(children: [
          cell(name, bold: true),
          cell(item.specificId == null ? 'General only' : (specificName[item.specificId] ?? 'General only')),
          cell(item.serialNumber != null && item.serialNumber!.isNotEmpty ? item.serialNumber! : '-'),
          cell(item.acquisitionDate ?? '-'),
          cell('${item.quantity}', align: pw.TextAlign.right),
          cell(_money(item.valueCents), align: pw.TextAlign.right),
          cell(lineTotal, align: pw.TextAlign.right),
          photoCell(await hasPhoto(item)),
        ]));
        if (item.notes.isNotEmpty) {
          rows.add(pw.TableRow(children: [
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(2, 1, 2, 4),
              child: pw.Text(_pdfSafe(item.notes),
                  style: pw.TextStyle(font: pw.Font.helveticaOblique(), fontSize: 8.5, color: PdfColors.grey700)),
            ),
            pw.SizedBox(),
            pw.SizedBox(),
            pw.SizedBox(),
            pw.SizedBox(),
            pw.SizedBox(),
            pw.SizedBox(),
            pw.SizedBox(),
          ]));
        }
      }
      sections.add(pw.Table(
        border: const pw.TableBorder(
          bottom: pw.BorderSide(color: PdfColors.grey600, width: 1),
          horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
        columnWidths: columnWidths,
        children: rows,
      ));
      sections.add(pw.SizedBox(height: 6));
      sections.add(pw.Text(
        'Subtotal - ${_pdfSafe(general.name)}: ${_money(subtotal)}${unvalued > 0 ? '  ($unvalued item${unvalued == 1 ? '' : 's'} without a recorded value not included)' : ''}',
        style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 10),
      ));
      sections.add(pw.SizedBox(height: 10));
    }

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) => [
          pw.Text('Home Inventory Report',
              style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 18)),
          pw.SizedBox(height: 2),
          pw.Text('WhereLog - prepared for insurance records · Generated $stamp',
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.SizedBox(height: 12),
          ...sections,
          pw.Divider(color: PdfColors.grey600),
          pw.Text('Grand total: ${_money(grandTotal)}',
              style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 12)),
          pw.SizedBox(height: 4),
          pw.Text(
            '${items.length} item${items.length == 1 ? '' : 's'} in ${generals.length} location${generals.length == 1 ? '' : 's'}${grandUnvalued > 0 ? ' · $grandUnvalued without a recorded value (excluded from the total)' : ''}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.Text(
            'Values are the replacement values recorded in WhereLog. Items without a recorded value are listed but excluded from the totals. A check in the Photo column means a photo is on file in the app. Generated by WhereLog on $stamp.',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    return doc.save();
  }

  // --- location CSVs ---

  Future<void> _createLocationCsvs() async {
    setState(() {
      _isWorking = true;
      _status = 'Choosing folder...';
    });
    var holdIosFolder = false;
    try {
      final picked = await _pickFolder('Choose CSV Folder');
      if (picked == null || picked.isEmpty) {
        if (mounted) setState(() => _status = 'CSV export cancelled.');
        return;
      }
      holdIosFolder = Platform.isIOS;
      final dir = Directory(picked);
      if (!await dir.exists()) await dir.create(recursive: true);
      if (mounted) setState(() => _status = 'Writing CSV files...');
      await _writeLocationCsvs(dir);
      if (mounted) {
        setState(() => _status = '3 CSV files saved to:\n$picked');
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'CSV export failed: $e');
    } finally {
      if (holdIosFolder) await DirectoryAccessService.releaseDirectory();
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _writeLocationCsvs(Directory dir) async {
    final generals = await _locRepo.getGenerals();
    final storageSpecifics = await _locRepo.getStorageSpecifics();
    final inventorySpecifics = await _locRepo.getInventorySpecifics();
    generals.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    storageSpecifics.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    inventorySpecifics.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final generalName = {for (final g in generals) g.id: g.name};

    final generalRows = StringBuffer('General location,Storage items,Inventory items\n');
    for (final g in generals) {
      final sCount = g.id == null ? 0 : await _storageRepo.countForGeneral(g.id!);
      final iCount = g.id == null ? 0 : await _invRepo.countForGeneral(g.id!);
      generalRows.writeln('${_csv(g.name)},$sCount,$iCount');
    }
    await File(p.join(dir.path, 'WhereLog-General-Locations.csv'))
        .writeAsString(generalRows.toString());

    final storageRows = StringBuffer('General location,Specific location,Items\n');
    for (final s in storageSpecifics) {
      final count = s.id == null ? 0 : await _storageRepo.countForSpecific(s.id!);
      storageRows.writeln('${_csv(generalName[s.generalId] ?? '')},${_csv(s.name)},$count');
    }
    await File(p.join(dir.path, 'WhereLog-Storage-Specific-Locations.csv'))
        .writeAsString(storageRows.toString());

    final inventoryRows = StringBuffer('General location,Specific location,Items\n');
    for (final s in inventorySpecifics) {
      final count = s.id == null ? 0 : await _invRepo.countForSpecific(s.id!);
      inventoryRows.writeln('${_csv(generalName[s.generalId] ?? '')},${_csv(s.name)},$count');
    }
    await File(p.join(dir.path, 'WhereLog-Inventory-Specific-Locations.csv'))
        .writeAsString(inventoryRows.toString());
  }

  // --- page ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(screenName: 'Reports'),
      backgroundColor: AppColors.scaffold,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          Text('HOME INVENTORY REPORT', style: AppText.dialogSection),
          const SizedBox(height: 4),
          Text(
            'An itemized list of your Home Inventory, grouped by General location with serial '
            'numbers, acquisition dates, values and a total. It opens as a print-ready PDF '
            'preview — print it, or share it to Files when you want a saved copy. Items with '
            'a photo on file are marked with a check in the Photo column. Suitable as an '
            'insurance record.',
            style: AppText.dialog,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _openInsuranceReport,
            style: AppButton.primary,
            child: Text('View Insurance Report', style: AppText.buttonPrimary),
          ),
          AppDivider.horizontal,
          Text('LOCATION DATA (CSV)', style: AppText.dialogSection),
          const SizedBox(height: 4),
          Text(
            'The three location lists as spreadsheet files — General locations, Storage specifics '
            'and Inventory specifics — so the data is never locked inside the app. For the complete '
            'backup of everything, photos included, see Export / Import.',
            style: AppText.dialog,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isWorking ? null : _createLocationCsvs,
            style: AppButton.primary,
            child: Text('Create All Three CSV Files', style: AppText.buttonPrimary),
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 16),
            SelectableText(_status, style: AppText.dialog),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
