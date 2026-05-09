import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:linguapanel/core/utils/ui_helpers.dart';
import 'package:linguapanel/features/history/view/chapter_viewer_page.dart';
import 'package:linguapanel/features/history/viewmodel/history_viewmodel.dart';
import 'package:linguapanel/features/widgets/full_screen_image_viewer.dart';
import 'package:linguapanel/features/history/model/translation_history.dart';
import 'package:provider/provider.dart';

class FavoritesView extends StatelessWidget {
  const FavoritesView({super.key});

  void _openItem(BuildContext context, TranslationHistory item) {
    if (item.isChapter) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChapterViewerPage(
            title: item.title,
            imagePaths: item.translatedImagePaths,
          ),
        ),
      );
    } else if (item.translatedImagePaths.isNotEmpty) {
      final file = File(item.translatedImagePaths.first);
      if (file.existsSync()) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenImageViewer(imageFile: file),
          ),
        );
      }
    }
  }

  Future<void> _showRenameDialog(
      BuildContext context, HistoryViewModel viewModel, TranslationHistory item) async {
    final controller = TextEditingController(text: item.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter new name',
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
            ),
          ],
        );
      },
    );

    if (newTitle != null && newTitle.isNotEmpty) {
      await viewModel.renameItem(item.id, newTitle);
    }
  }

  Future<void> _showDeleteConfirmationDialog(
      BuildContext context, HistoryViewModel viewModel, String historyId) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this item?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      try {
        await viewModel.deleteHistoryItem(historyId);
        if (context.mounted) {
          UIHelpers.showSuccessSnackBar(context, 'Item deleted successfully.');
        }
      } catch (e) {
        if (context.mounted) {
          UIHelpers.showErrorSnackBar(context, 'Failed to delete item.');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
      ),
      body: Consumer<HistoryViewModel>(
        builder: (context, viewModel, child) {
          final favoriteItems = viewModel.favoriteItems;

          if (favoriteItems.isEmpty) {
            return const Center(
              child: Text(
                'No favorites yet.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: favoriteItems.length,
            itemBuilder: (context, index) {
              final item = favoriteItems[index];
              return _buildHistoryCard(context, viewModel, item);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(
      BuildContext context, HistoryViewModel viewModel, TranslationHistory item) {
    final thumbnailPath = item.translatedImagePaths.isNotEmpty
        ? item.translatedImagePaths.first
        : '';
    final thumbnailFile = File(thumbnailPath);
    final thumbnailExists = thumbnailPath.isNotEmpty && thumbnailFile.existsSync();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openItem(context, item),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // --- Thumbnail ---
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 70,
                  height: 90,
                  child: thumbnailExists
                      ? Image.file(thumbnailFile, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image,
                              color: Colors.grey),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // --- Title & info ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _showRenameDialog(context, viewModel, item),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 14, color: Colors.grey),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat.yMMMd().add_jm().format(item.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (item.isChapter)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${item.pageCount} pages',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // --- Actions ---
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.star, color: Colors.amber, size: 22),
                    onPressed: () => viewModel.toggleFavorite(item.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minHeight: 36),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 22),
                    onPressed: () => _showDeleteConfirmationDialog(
                        context, viewModel, item.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minHeight: 36),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
