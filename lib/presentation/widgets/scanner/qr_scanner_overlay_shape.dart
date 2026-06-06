import 'package:flutter/material.dart';

class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final double borderLength;
  final double borderRadius;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 4.0,
    this.borderLength = 20.0,
    this.borderRadius = 0.0,
    this.cutOutSize = 250.0,
  });

  @override EdgeInsetsGeometry get dimensions => EdgeInsets.zero;
  @override Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();
  @override Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRect(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.5)..style = PaintingStyle.fill;
    final cutOutRect = Rect.fromLTWH((width - cutOutSize) / 2, (height - cutOutSize) / 2, cutOutSize, cutOutSize);

    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect)
      ..addRRect(RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)));

    canvas.drawPath(path, backgroundPaint);
    
    final borderPaint = Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = borderWidth;
    final rrect = RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius));
    
    canvas.drawPath(Path()..moveTo(rrect.left, rrect.top + borderLength)..lineTo(rrect.left, rrect.top)..lineTo(rrect.left + borderLength, rrect.top), borderPaint);
    canvas.drawPath(Path()..moveTo(rrect.right - borderLength, rrect.top)..lineTo(rrect.right, rrect.top)..lineTo(rrect.right, rrect.top + borderLength), borderPaint);
    canvas.drawPath(Path()..moveTo(rrect.right, rrect.bottom - borderLength)..lineTo(rrect.right, rrect.bottom)..lineTo(rrect.right - borderLength, rrect.bottom), borderPaint);
    canvas.drawPath(Path()..moveTo(rrect.left + borderLength, rrect.bottom)..lineTo(rrect.left, rrect.bottom)..lineTo(rrect.left, rrect.bottom - borderLength), borderPaint);
  }

  @override ShapeBorder scale(double t) => this;
}