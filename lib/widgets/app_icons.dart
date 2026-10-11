import 'package:flutter/material.dart';

// Single source for Wherelog icons - no assets needed
class AppIcons {
  static Widget directions({double size = 24, Color? color, Color? bgColor}) =>
      DirectionsIcon(size: size, color: color, backgroundColor: bgColor);
  static Widget headerLogo({double size = 32}) => _HeaderLogoIcon(size: size);
}

// -------------------------------------------------------------
// DIRECTIONS ICON - Perfect match to raster
// Diamond with rounded corners + right-turn arrow
// -------------------------------------------------------------
class DirectionsIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final Color? backgroundColor;
  const DirectionsIcon({super.key, this.size = 24, this.color, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: DirectionsIconPainter(
          color: color ?? Colors.black,
          backgroundColor: backgroundColor ?? Colors.white,
        ),
      ),
    );
  }
}

class DirectionsIconPainter extends CustomPainter {
  final Color color;
  final Color backgroundColor;
  DirectionsIconPainter({required this.color, required this.backgroundColor});

  Path _diamondPath(double cx, double cy, double r, double cornerRadius) {
    // Diamond with 4 points: top, right, bottom, left
    // r = distance from center to point
    final path = Path();
    // We inset the corners by cornerRadius along edges
    // Top point
    final top = Offset(cx, cy - r);
    final right = Offset(cx + r, cy);
    final bottom = Offset(cx, cy + r);
    final left = Offset(cx - r, cy);

    // Create rounded diamond by using arcTo between edges
    // Simple approach: move along edges inset by radius
    final double inset = cornerRadius * 0.9;
    
    path.moveTo(top.dx + inset, top.dy + inset);
    // top -> right
    path.lineTo(right.dx - inset, right.dy - inset);
    path.quadraticBezierTo(right.dx, right.dy, right.dx - inset, right.dy + inset);
    // right -> bottom
    path.lineTo(bottom.dx + inset, bottom.dy - inset);
    path.quadraticBezierTo(bottom.dx, bottom.dy, bottom.dx - inset, bottom.dy - inset);
    // bottom -> left
    path.lineTo(left.dx + inset, left.dy + inset);
    path.quadraticBezierTo(left.dx, left.dy, left.dx + inset, left.dy - inset);
    // left -> top
    path.lineTo(top.dx - inset, top.dy + inset);
    path.quadraticBezierTo(top.dx, top.dy, top.dx + inset, top.dy + inset);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final double outerR = w * 0.50; // tip to center
    final double innerR = w * 0.38;
    final double borderW = w * 0.095;
    
    final paintBorder = Paint()..color = color..style = PaintingStyle.fill..isAntiAlias = true;
    final paintBg = Paint()..color = backgroundColor..style = PaintingStyle.fill..isAntiAlias = true;
    final paintArrow = Paint()..color = color..style = PaintingStyle.fill..isAntiAlias = true;

    // Draw outer diamond (border) and inner diamond (bg)
    final outerPath = _diamondPath(cx, cy, outerR, w * 0.10);
    final innerPath = _diamondPath(cx, cy, innerR, w * 0.06);
    
    canvas.drawPath(outerPath, paintBorder);
    canvas.drawPath(innerPath, paintBg);

    // Arrow - right turn
    // Dimensions relative to icon
    final double arrowStroke = w * 0.12;
    final double arrowLeft = cx - w * 0.14;
    final double arrowBottom = cy + h * 0.22;
    final double arrowTopBend = cy - h * 0.08;
    final double arrowRight = cx + w * 0.24;
    
    final Path arrow = Path();
    // Vertical stem: from bottom up to bend
    final double vLeft = arrowLeft;
    final double vRight = arrowLeft + arrowStroke;
    final double vTop = arrowTopBend;
    final double vBottom = arrowBottom;
    arrow.addRect(Rect.fromLTRB(vLeft, vTop, vRight, vBottom));
    
    // Horizontal stem: from left to right
    final double hTop = arrowTopBend;
    final double hBottom = arrowTopBend + arrowStroke;
    final double hLeft = arrowLeft;
    final double hRight = arrowRight;
    arrow.addRect(Rect.fromLTRB(hLeft, hTop, hRight, hBottom));
    
    // Rounded elbow - small overlap to smooth
    arrow.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(arrowLeft - w*0.01, arrowTopBend - h*0.01, arrowStroke + w*0.04, arrowStroke + h*0.04),
      Radius.circular(arrowStroke * 0.35),
    ));
    
    // Arrow head - triangle pointing right
    final Path head = Path();
    final double headTipX = arrowRight + w * 0.14;
    final double headBaseX = arrowRight - w * 0.02;
    final double headCy = arrowTopBend + arrowStroke/2;
    final double headH = h * 0.28;
    head.moveTo(headTipX, headCy);
    head.lineTo(headBaseX, headCy - headH/2);
    head.lineTo(headBaseX, headCy + headH/2);
    head.close();

    canvas.drawPath(arrow, paintArrow);
    canvas.drawPath(head, paintArrow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeaderLogoIcon extends StatelessWidget {
  final double size;
  const _HeaderLogoIcon({required this.size});
  @override
  Widget build(BuildContext context) {
    // Use PNG launcher for perfect header - code version is placeholder
    return Image.asset('assets/icon/wherelog_launcher.png',
      width: size, height: size,
      errorBuilder: (c,e,s) => Icon(Icons.inventory_2, size: size),
    );
  }
}
