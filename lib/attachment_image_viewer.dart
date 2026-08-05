import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Full-screen, pinch-to-zoom view of an already-downloaded image
/// attachment — shown entirely from in-memory [bytes], never from a
/// Storage URL (signed or otherwise), so nothing about where the file
/// actually lives is ever visible to the user.
class AttachmentImageViewer extends StatelessWidget {
  const AttachmentImageViewer({super.key, required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(fileName, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
