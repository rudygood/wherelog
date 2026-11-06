import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import '../theme/app_theme.dart';
import '../services/clipboard_image_service.dart';

enum PhotoDetailsVariant { storage, inventory, poi }

class PhotoDetailsSection extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final PhotoDetailsVariant variant;
  final File? photoFile;
  final ValueChanged<File?> onPhotoChanged;
  final VoidCallback? onPhotoView;
  final TextEditingController valueController;
  final TextEditingController? qtyController;
  final TextEditingController? serialController;
  final TextEditingController? brandController;
  final TextEditingController? modelController;
  final TextEditingController? purchasePriceController;
  final TextEditingController? addressController;
  final String? coordsSource;
  final VoidCallback? onPickMap;
  final DateTime? acquiredDate;
  final VoidCallback? onPickAcquiredDate;
  final String? storageKey;

  const PhotoDetailsSection({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    required this.variant,
    required this.photoFile,
    required this.onPhotoChanged,
    this.onPhotoView,
    required this.valueController,
    this.qtyController,
    this.serialController,
    this.brandController,
    this.modelController,
    this.purchasePriceController,
    this.addressController,
    this.coordsSource,
    this.onPickMap,
    this.acquiredDate,
    this.onPickAcquiredDate,
    this.storageKey,
  });

  @override
  State<PhotoDetailsSection> createState() => _PhotoDetailsSectionState();
}

class _PhotoDetailsSectionState extends State<PhotoDetailsSection> with WidgetsBindingObserver {
  late bool _expanded;
  bool _hasClipboard = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _expanded = widget.isExpanded;
    _load();
    _checkClipboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The clipboard's contents change while the user is off in
  /// another app copying a photo. When WhereLog comes back to
  /// the front, look again, so the Clipboard button's enabled
  /// state reflects the clipboard as it is now, not as it was
  /// when this screen was first built.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkClipboard();
  }

  @override
  void didUpdateWidget(covariant PhotoDetailsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isExpanded != widget.isExpanded) _expanded = widget.isExpanded;
  }

  Future<void> _load() async {
    if (widget.storageKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(widget.storageKey!);
    if (saved != null && mounted) setState(() => _expanded = saved);
  }

  Future<void> _handleToggle() async {
    _checkClipboard();
    setState(() => _expanded = !_expanded);
    if (widget.storageKey != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(widget.storageKey!, _expanded);
    }
    widget.onToggle();
  }

  Future<void> _checkClipboard() async {
    final has = await ClipboardImageService.hasImage();
    if (mounted) setState(() => _hasClipboard = has);
  }

  String get _title {
    switch (widget.variant) {
      case PhotoDetailsVariant.poi: return 'ADDRESS & PHOTO';
      default: return 'DETAILS & PHOTO';
    }
  }

  bool get _hasAppImage {
    final f = widget.photoFile;
    if (f == null) return false;
    try { return f.existsSync(); } catch (_) { return false; }
  }

  String _uniqueName([String ext = '.jpg']) {
    if (!ext.startsWith('.')) ext = '.$ext';
    if (ext.isEmpty) ext = '.jpg';
    final r = Random().nextInt(90000) + 10000;
    return 'img_${DateTime.now().microsecondsSinceEpoch}_${r}$ext';
  }

  /// The extension for pasted bytes that actually begin as a
  /// known image, or '' when they do not — pasted content is
  /// never saved under a guessed extension.
  String _extFromBytes(Uint8List bytes) {
    if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return '.png';
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return '.jpg';
    if (bytes.length >= 12 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return '.webp';
    if (bytes.length >= 4 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) return '.gif';
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) return '.bmp';
    return '';
  }

  Future<void> _deleteIfExists(String? path) async {
    if (path == null || path.isEmpty) return;
    try { final f = File(path); if (await f.exists()) await f.delete(); } catch (_) {}
  }

  Future<void> _handleCamera() async {
    final XFile? img = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1280);
    if (img == null) return;
    await _savePickedFile(File(img.path));
  }

  Future<void> _handleGallery() async {
    final XFile? img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1280);
    if (img == null) return;
    await _savePickedFile(File(img.path));
  }

  Future<void> _savePickedFile(File tempFile) async {
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(dir.path, 'WhereLog', 'photos'));
    if (!await photosDir.exists()) await photosDir.create(recursive: true);
    final ext = p.extension(tempFile.path).isEmpty ? '.jpg' : p.extension(tempFile.path);
    final newFile = File(p.join(photosDir.path, _uniqueName(ext)));
    await tempFile.copy(newFile.path);
    final oldPath = widget.photoFile?.path;
    if (oldPath != null && oldPath != newFile.path) await _deleteIfExists(oldPath);
    widget.onPhotoChanged(newFile);
  }

  /// Diagnostic (long-press the Clipboard button): show what
  /// the clipboard currently claims to hold, in plain text.
  Future<void> _showClipDiagnostic() async {
    final report = await ClipboardImageService.describeClip();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorder.radius), side: AppBorder.side),
        title: const Text('Clipboard contents', style: AppText.dialogTitle),
        content: SingleChildScrollView(child: SelectableText(report, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _handlePaste() async {
    final bytes = await ClipboardImageService.getImageBytes();
    if (bytes == null || bytes.isEmpty) {
      await _checkClipboard();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clipboard has no image')));
      return;
    }
    final ext = _extFromBytes(bytes);
    if (ext.isEmpty) {
      // Bytes arrived but are not an image (a copied link's
      // payload, a web page, ...). Save nothing.
      await _checkClipboard();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clipboard has no image')));
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(dir.path, 'WhereLog', 'photos'));
    if (!await photosDir.exists()) await photosDir.create(recursive: true);
    final newFile = File(p.join(photosDir.path, _uniqueName(ext)));
    await newFile.writeAsBytes(bytes);
    final oldPath = widget.photoFile?.path;
    if (oldPath != null) await _deleteIfExists(oldPath);
    widget.onPhotoChanged(newFile);
    await _checkClipboard();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(_title, style: AppText.dialogSection),
          const SizedBox(width: 12),
          InkWell(onTap: _handleToggle, borderRadius: BorderRadius.circular(4), child: Padding(padding: const EdgeInsets.all(4), child: Icon(_expanded ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppColors.textPrimary))),
        ]),
        if (_expanded) ...[
          const SizedBox(height: 10),
          _buildDetailsFields(),
          const SizedBox(height: 14),
          _buildPhotoRow(),
        ],
      ],
    );
  }

  Widget _buildDetailsFields() {
    const fieldHeight = AppSize.fieldHeight;
    InputDecoration deco(String hint, {Widget? prefix}) => InputDecoration(
      hintText: hint,
      hintStyle: AppText.inputHint,
      // This is the actual border definition used for entry fields - OutlineInputBorder without explicit side
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius), borderSide: BorderSide(color: AppColors.border, width: 1)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius), borderSide: BorderSide(color: AppColors.textPrimary.withOpacity(0.6), width: 1)),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      isDense: true,
      prefixIcon: prefix,
    );
    if (widget.variant == PhotoDetailsVariant.storage) {
      return Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Quantity', style: AppText.dialogSection), const SizedBox(height: 4), SizedBox(height: fieldHeight, child: TextField(controller: widget.qtyController, keyboardType: TextInputType.number, style: AppText.input, decoration: deco('1')))])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Value (\$)', style: AppText.dialogSection), const SizedBox(height: 4), SizedBox(height: fieldHeight, child: TextField(controller: widget.valueController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: AppText.input, decoration: deco('0.00', prefix: const Icon(Icons.attach_money, size: 18, color: AppColors.textSecondary))))])),
      ]);
    } else if (widget.variant == PhotoDetailsVariant.inventory) {
      return Column(children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Brand', style: AppText.dialogSection), const SizedBox(height: 4), SizedBox(height: fieldHeight, child: TextField(controller: widget.brandController, textCapitalization: TextCapitalization.words, style: AppText.input, decoration: deco('Optional')))])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Model', style: AppText.dialogSection), const SizedBox(height: 4), SizedBox(height: fieldHeight, child: TextField(controller: widget.modelController, textCapitalization: TextCapitalization.sentences, style: AppText.input, decoration: deco('Optional')))])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Serial Number', style: AppText.dialogSection), const SizedBox(height: 4), SizedBox(height: fieldHeight, child: TextField(controller: widget.serialController, textCapitalization: TextCapitalization.none, style: AppText.input, decoration: deco('Optional')))])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Quantity', style: AppText.dialogSection), const SizedBox(height: 4), SizedBox(height: fieldHeight, child: TextField(controller: widget.qtyController, keyboardType: TextInputType.number, style: AppText.input, decoration: deco('1')))])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Purchase Price (\$)', style: AppText.dialogSection), const SizedBox(height: 4), SizedBox(height: fieldHeight, child: TextField(controller: widget.purchasePriceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: AppText.input, decoration: deco('0.00', prefix: const Icon(Icons.attach_money, size: 18, color: AppColors.textSecondary))))])),
          const SizedBox(width: 12),
          // This is the figure an insurance claim pays on (schema D4) —
          // labelled so it can never be confused with purchase price.
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Replacement Value (\$)', style: AppText.dialogSection), const SizedBox(height: 4), SizedBox(height: fieldHeight, child: TextField(controller: widget.valueController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: AppText.input, decoration: deco('0.00', prefix: const Icon(Icons.attach_money, size: 18, color: AppColors.textSecondary))))])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Acquisition Date', style: AppText.dialogSection), const SizedBox(height: 4), InkWell(onTap: widget.onPickAcquiredDate, borderRadius: BorderRadius.circular(AppRadius.button), child: Container(height: fieldHeight, padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: AppColors.white, border: Border.all(color: AppColors.border, width: AppBorder.width), borderRadius: BorderRadius.circular(AppRadius.button)), child: Row(children: [Expanded(child: Text(widget.acquiredDate == null ? 'Optional' : '${widget.acquiredDate!.month}/${widget.acquiredDate!.day}/${widget.acquiredDate!.year}', style: TextStyle(color: widget.acquiredDate == null ? AppColors.textDisabled : AppColors.textPrimary, fontSize: 13, fontWeight: widget.acquiredDate == null ? FontWeight.normal : FontWeight.w600))), const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary)])))])),
          const SizedBox(width: 12),
          const Expanded(child: SizedBox()),
        ]),
      ]);
    } else {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ADDRESS (optional)', style: AppText.dialogSection),
        const SizedBox(height: 4),
        SizedBox(height: fieldHeight, child: TextField(controller: widget.addressController, textCapitalization: TextCapitalization.words, style: AppText.input, decoration: InputDecoration(hintText: 'Optional address from map', hintStyle: AppText.inputHint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius), borderSide: BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius), borderSide: BorderSide(color: AppColors.border)), filled: true, fillColor: AppColors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), isDense: true, suffixIcon: IconButton(icon: const Icon(Icons.map_outlined, color: AppColors.textSecondary), onPressed: widget.onPickMap)))),
        const SizedBox(height: 12),
        const Text('COORDS SOURCE', style: AppText.dialogSection),
        const SizedBox(height: 4),
        Container(height: fieldHeight, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: AppColors.scaffoldDark, border: Border.all(color: AppColors.border, width: AppBorder.width), borderRadius: BorderRadius.circular(AppRadius.button)), alignment: Alignment.centerLeft, child: Text(widget.coordsSource?.isNotEmpty == true ? widget.coordsSource! : 'Not set - will be set on save', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600))),
      ]);
    }
  }

  Widget _buildPhotoRow() {
    final hasApp = _hasAppImage;
    const double buttonHeight = AppSize.buttonHeight;
    const double buttonSpacing = 8.0;
    const double thumbSize = buttonHeight * 3 + buttonSpacing * 2;

    // FIXED: Border that actually matches entry fields above
    // Entry fields use OutlineInputBorder default: AppColors.border width 1
    // AppColors.border = 0x1A000000 (10% black) is way too light - that was the bug
    final Border photoBorder = Border.all(color: AppColors.border, width: 1);

    Widget leftBtn(VoidCallback? onPressed, IconData icon, String label) => SizedBox(
          width: double.infinity,
          height: buttonHeight,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 16),
            label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            style: AppButton.primary,
          ),
        );

    Widget rightBtn(VoidCallback? onPressed, IconData icon, String label) => SizedBox(
          width: double.infinity,
          height: buttonHeight,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 16),
            label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            style: AppButton.primary,
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.white, border: photoBorder, borderRadius: BorderRadius.circular(AppRadius.button)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      leftBtn(_handleCamera, Icons.photo_camera_outlined, 'Camera'),
                      const SizedBox(height: buttonSpacing),
                      leftBtn(_handleGallery, Icons.photo_library_outlined, 'Gallery'),
                      const SizedBox(height: buttonSpacing),
                      // The diagnostic long-press lives on a
                      // wrapper, NOT on the button: a button with
                      // a long-press handler counts as enabled
                      // even when its tap handler is null, which
                      // made the button glow with nothing to paste.
                      GestureDetector(onLongPress: _showClipDiagnostic, child: leftBtn(_hasClipboard ? _handlePaste : null, Icons.content_paste_outlined, 'Clipboard')),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Lightweight brace - darker now per request (opacity 0.85)
                SizedBox(
                  width: 20,
                  height: thumbSize,
                  child: CustomPaint(painter: _LightweightBracePainter(color: AppColors.textPrimary.withOpacity(0.85))),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: thumbSize,
            height: thumbSize,
            decoration: BoxDecoration(color: AppColors.white, border: photoBorder, borderRadius: BorderRadius.circular(AppRadius.button)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.button - 1),
              child: hasApp && widget.photoFile != null ? Image.file(widget.photoFile!, fit: BoxFit.cover) : Container(color: AppColors.scaffoldDark, child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.image_outlined, size: 32, color: AppColors.textDisabled), SizedBox(height: 4), Text('No Photo', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 10))])),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: thumbSize,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    rightBtn(hasApp ? widget.onPhotoView : null, Icons.fullscreen_outlined, 'View Photo'),
                    const SizedBox(height: buttonSpacing),
                    rightBtn(hasApp ? _handleRemove : null, Icons.delete_outline, 'Remove'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRemove() async {
    if (!_hasAppImage) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Photo?', style: AppText.dialogTitleAlert),
        content: const Text('This will delete the photo from this entry. This cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.buttonBg, foregroundColor: AppColors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button))), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    final oldPath = widget.photoFile?.path;
    if (oldPath != null) await _deleteIfExists(oldPath);
    widget.onPhotoChanged(null);
  }
}

class _LightweightBracePainter extends CustomPainter {
  final Color color;
  _LightweightBracePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    final top = Path();
    top.moveTo(w * 0.1, h * 0.02);
    top.cubicTo(w * 0.6, h * -0.02, w * 0.7, h * 0.08, w * 0.4, h * 0.20);
    top.cubicTo(w * 0.2, h * 0.30, w * 0.15, h * 0.38, w * 0.55, h * 0.45);
    top.cubicTo(w * 0.75, h * 0.48, w * 0.85, h * 0.49, w * 0.95, h * 0.5);

    final bottom = Path();
    bottom.moveTo(w * 0.1, h * 0.98);
    bottom.cubicTo(w * 0.6, h * 1.02, w * 0.7, h * 0.92, w * 0.4, h * 0.80);
    bottom.cubicTo(w * 0.2, h * 0.70, w * 0.15, h * 0.62, w * 0.55, h * 0.55);
    bottom.cubicTo(w * 0.75, h * 0.52, w * 0.85, h * 0.51, w * 0.95, h * 0.5);

    canvas.drawPath(top, paint);
    canvas.drawPath(bottom, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
