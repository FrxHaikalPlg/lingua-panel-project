import 'dart:io';
import 'package:flutter/material.dart';
import 'package:linguapanel/features/widgets/full_screen_image_viewer.dart';

/// Scrollable viewer for chapter translation results.
class ChapterViewerPage extends StatelessWidget {
  final String title;
  final List<String> imagePaths;

  const ChapterViewerPage({
    super.key,
    required this.title,
    required this.imagePaths,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: imagePaths.length,
        itemBuilder: (context, index) {
          final file = File(imagePaths[index]);
          final exists = file.existsSync();

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () {
                if (exists) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullScreenImageViewer(imageFile: file),
                    ),
                  );
                }
              },
              child: Column(
                children: [
                  Text(
                    'Page ${index + 1} of ${imagePaths.length}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  exists
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(file, fit: BoxFit.contain),
                        )
                      : Container(
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(Icons.broken_image,
                                size: 48, color: Colors.grey),
                          ),
                        ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
