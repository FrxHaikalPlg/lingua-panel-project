import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class FullScreenImageViewer extends StatelessWidget {
  final File? imageFile;
  final String? imageUrl;
  final Uint8List? imageBytes;

  const FullScreenImageViewer(
      {super.key, this.imageFile, this.imageUrl, this.imageBytes})
      : assert(imageFile != null || imageUrl != null || imageBytes != null);

  @override
  Widget build(BuildContext context) {
    ImageProvider imageProvider;
    if (imageFile != null) {
      imageProvider = FileImage(imageFile!);
    } else if (imageBytes != null) {
      imageProvider = MemoryImage(imageBytes!);
    } else {
      imageProvider = NetworkImage(imageUrl!);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), // Make back button white
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image(image: imageProvider),
        ),
      ),
    );
  }
}
