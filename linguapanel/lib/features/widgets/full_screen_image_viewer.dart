import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        body: Center(
          child: Hero(
            tag: 'image_viewer',
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 6.0,
              child: Image(image: imageProvider),
            ),
          ),
        ),
      ),
    );
  }
}
