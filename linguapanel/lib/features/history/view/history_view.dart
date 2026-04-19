import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:linguapanel/core/utils/ui_helpers.dart';
import 'package:linguapanel/features/history/model/translation_history.dart';
import 'package:linguapanel/features/history/viewmodel/history_viewmodel.dart';
import 'package:linguapanel/features/widgets/full_screen_image_viewer.dart';
import 'package:provider/provider.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  Future<void> _showDeleteConfirmationDialog(
      BuildContext context, HistoryViewModel viewModel, String historyId) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this history item?'),
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
      await viewModel.deleteHistoryItem(historyId);
      if (context.mounted) {
        if (viewModel.errorMessage != null) {
          UIHelpers.showErrorSnackBar(context, viewModel.errorMessage!);
        } else {
          UIHelpers.showSuccessSnackBar(context, 'History item deleted successfully.');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Translation History'),
      ),
      body: Consumer<HistoryViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.errorMessage != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              UIHelpers.showErrorSnackBar(context, viewModel.errorMessage!);
              viewModel.setErrorMessage(null);
            });
          }
          return StreamBuilder<List<TranslationHistory>>(
            stream: viewModel.historyStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Could not load history. Please check your internet connection and try again.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, color: Colors.red),
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'No history found.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                );
              }

              final historyItems = snapshot.data!;

              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: historyItems.length,
                itemBuilder: (context, index) {
                  final item = historyItems[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat.yMMMd().add_jm().format(item.timestamp),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: Icon(
                                  item.isFavorite
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: item.isFavorite
                                      ? Colors.amber
                                      : Colors.grey,
                                ),
                                onPressed: () => viewModel.toggleFavorite(
                                    item.id, item.isFavorite),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                onPressed: () => _showDeleteConfirmationDialog(
                                    context, viewModel, item.id),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildImagePreview(
                                    context, 'Original', item.originalImageUrl),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildImagePreview(context, 'Translated',
                                    item.translatedImageUrl),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildImagePreview(
      BuildContext context, String title, String imageUrl) {
    if (imageUrl.isEmpty) {
      return const Center(child: Text('Image not available'));
    }

    return Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            if (imageUrl.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      FullScreenImageViewer(imageUrl: imageUrl),
                ),
              );
            }
          },
          child: Container(
            height: 150,
            width: 150,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                      child: Icon(Icons.error, color: Colors.red));
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
