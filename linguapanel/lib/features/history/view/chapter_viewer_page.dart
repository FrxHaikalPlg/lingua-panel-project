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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${imagePaths.length} pages',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        itemCount: imagePaths.length,
        itemBuilder: (context, index) {
          final file = File(imagePaths[index]);
          final exists = file.existsSync();

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Page header
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color:
                                theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Page ${index + 1} of ${imagePaths.length}',
                          style: theme.textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                  // Image
                  GestureDetector(
                    onTap: () {
                      if (exists) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                FullScreenImageViewer(imageFile: file),
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: exists
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(file, fit: BoxFit.contain),
                            )
                          : Container(
                              height: 200,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.grey.shade300),
                              ),
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image_rounded,
                                        size: 48, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('Image not found',
                                        style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
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
