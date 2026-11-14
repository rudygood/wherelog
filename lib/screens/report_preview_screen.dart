import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// Preview screen for the insurance report PDF (2026-11-13): the
/// document opens as a preview with print and share built in —
/// sharing to Files is how a saved copy is made. No folder picker,
/// and no file is written until the user shares or prints it.
///
/// The preview opens already zoomed on the first page — centred,
/// pinch to enlarge — because a landscape page on a portrait phone
/// otherwise sits as a small strip at the top, and the stock
/// preview only zooms after a double-tap. Double-tap exits to the
/// page list; double-tap a page in the list zooms it again.
class ReportPreviewScreen extends StatefulWidget {
  final Future<Uint8List> Function(PdfPageFormat format) buildPdf;
  final String fileName;

  const ReportPreviewScreen({super.key, required this.buildPdf, required this.fileName});

  @override
  State<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends State<ReportPreviewScreen> {
  // Which page is zoomed, or null for the page list. Starts zoomed
  // on the first page (2026-11-13).
  int? _zoomedPage = 0;
  final _transformationController = TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _zoomIn(int index) {
    setState(() {
      _zoomedPage = index;
      _transformationController.value.setIdentity();
    });
  }

  void _zoomOut() {
    setState(() => _zoomedPage = null);
  }

  Widget _pageImage(PdfPreviewPageData page) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[BoxShadow(offset: Offset(0, 3), blurRadius: 5)],
      ),
      child: AspectRatio(
        aspectRatio: page.aspectRatio,
        child: Image(image: page.image, fit: BoxFit.cover),
      ),
    );
  }

  Widget _pagesBuilder(BuildContext context, List<PdfPreviewPageData> pages) {
    if (_zoomedPage != null) {
      final index = _zoomedPage!.clamp(0, pages.length - 1);
      return _zoomView(pages, index);
    }
    return _listView(pages);
  }

  Widget _chevron(IconData icon, VoidCallback? onPressed) {
    return Align(
      alignment: icon == Icons.chevron_left ? Alignment.centerLeft : Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Container(
          decoration: const BoxDecoration(color: Colors.white70, shape: BoxShape.circle),
          child: IconButton(icon: Icon(icon), onPressed: onPressed),
        ),
      ),
    );
  }

  Widget _zoomView(List<PdfPreviewPageData> pages, int index) {
    return Stack(
      children: [
        GestureDetector(
          onDoubleTap: _zoomOut,
          child: InteractiveViewer(
            transformationController: _transformationController,
            maxScale: 5,
            child: Center(child: _pageImage(pages[index])),
          ),
        ),
        if (pages.length > 1) ...[
          _chevron(Icons.chevron_left, index > 0 ? () => _zoomIn(index - 1) : null),
          _chevron(Icons.chevron_right, index < pages.length - 1 ? () => _zoomIn(index + 1) : null),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(12)),
                child: Text('Page ${index + 1} of ${pages.length}', style: AppText.dialog),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _listView(List<PdfPreviewPageData> pages) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < pages.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: GestureDetector(
                      onDoubleTap: () => _zoomIn(i),
                      child: _pageImage(pages[i]),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(screenName: 'Insurance Report'),
      backgroundColor: AppColors.scaffold,
      body: PdfPreview.builder(
        build: widget.buildPdf,
        pagesBuilder: _pagesBuilder,
        pdfFileName: widget.fileName,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        initialPageFormat: PdfPageFormat.letter.landscape,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}
