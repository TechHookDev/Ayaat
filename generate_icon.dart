import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  // Create a 1024x1024 icon with transparent background
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = const Size(1024, 1024);

  // Blue background
  final paint = Paint()..color = const Color(0xFF1A237E);
  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

  // Draw Arabic text "آيات" in golden color
  final textStyle = ui.TextStyle(
    color: const Color(0xFFFFD700),
    fontSize: 400,
    fontWeight: FontWeight.bold,
    fontFamily: 'Amiri',
  );

  final paragraphStyle = ui.ParagraphStyle(
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.center,
  );

  final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
    ..pushStyle(textStyle)
    ..addText('آيات');

  final paragraph = paragraphBuilder.build();
  paragraph.layout(const ui.ParagraphConstraints(width: 1024));

  // Center the text
  final textHeight = paragraph.height;
  final textWidth = paragraph.maxIntrinsicWidth;
  final offset = Offset(
    (size.width - textWidth) / 2,
    (size.height - textHeight) / 2,
  );

  canvas.drawParagraph(paragraph, offset);

  final picture = recorder.endRecording();
  final image = await picture.toImage(1024, 1024);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

  if (byteData != null) {
    final buffer = byteData.buffer.asUint8List();
    final file = File('assets/icon.png');
    await file.writeAsBytes(buffer);
    print('Icon generated successfully!');
  }
}
