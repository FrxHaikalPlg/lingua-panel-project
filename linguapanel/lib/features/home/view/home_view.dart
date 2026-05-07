import 'package:linguapanel/core/utils/ui_helpers.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:linguapanel/core/services/auth_service.dart';
import 'package:linguapanel/features/history/view/favorites_view.dart';
import 'package:linguapanel/features/history/view/history_view.dart';
import 'package:linguapanel/features/history/viewmodel/history_viewmodel.dart';
import 'package:linguapanel/features/home/viewmodel/home_viewmodel.dart';
import 'package:linguapanel/features/settings/view/settings_view.dart';
import 'package:linguapanel/features/widgets/full_screen_image_viewer.dart';
import 'package:provider/provider.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => HomeViewModel()),
        ChangeNotifierProvider(create: (context) => HistoryViewModel()),
      ],
      child: Builder(builder: (context) {
        final authService = AuthService();

        return Scaffold(
          appBar: AppBar(
            title: const Text('LinguaPanel'),
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value:
                            Provider.of<HistoryViewModel>(context, listen: false),
                        child: const HistoryView(),
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.star),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value:
                            Provider.of<HistoryViewModel>(context, listen: false),
                        child: const FavoritesView(),
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsView(),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () {
                  authService.signOut();
                },
              ),
            ],
          ),
          body: Consumer<HomeViewModel>(
            builder: (context, viewModel, child) {
              if (viewModel.errorMessage != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  UIHelpers.showErrorSnackBar(context, viewModel.errorMessage!);
                  viewModel.setErrorMessage(null);
                });
              }
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- Mode Toggle ---
                      _buildModeToggle(context, viewModel),
                      const SizedBox(height: 12),

                      // --- Settings Row ---
                      _buildSettingsRow(context, viewModel),
                      const SizedBox(height: 16),

                      // --- Content based on mode ---
                      if (viewModel.mode == TranslationMode.single)
                        _buildSingleImageContent(context, viewModel)
                      else
                        _buildChapterContent(context, viewModel),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }

  // -------------------------------------------------------
  // Mode Toggle
  // -------------------------------------------------------
  Widget _buildModeToggle(BuildContext context, HomeViewModel viewModel) {
    return SegmentedButton<TranslationMode>(
      segments: const [
        ButtonSegment(
          value: TranslationMode.single,
          label: Text('Single Image'),
          icon: Icon(Icons.image),
        ),
        ButtonSegment(
          value: TranslationMode.chapter,
          label: Text('Chapter'),
          icon: Icon(Icons.collections),
        ),
      ],
      selected: {viewModel.mode},
      onSelectionChanged: viewModel.isLoading
          ? null
          : (Set<TranslationMode> selected) {
              viewModel.setMode(selected.first);
            },
    );
  }

  // -------------------------------------------------------
  // Settings Row (shared)
  // -------------------------------------------------------
  Widget _buildSettingsRow(BuildContext context, HomeViewModel viewModel) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: viewModel.selectedLang,
            decoration: const InputDecoration(
              labelText: 'Language',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            items: HomeViewModel.languageOptions.entries
                .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
            onChanged: viewModel.isLoading
                ? null
                : (val) {
                    if (val != null) {
                      viewModel.setLanguage(val);
                      if (val == 'ko') {
                        viewModel.setOrientation('horizontal');
                      } else if (val == 'ja' || val == 'ch_sim') {
                        viewModel.setOrientation('vertical');
                      }
                    }
                  },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: viewModel.selectedOrientation,
            decoration: const InputDecoration(
              labelText: 'Orientation',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            items: HomeViewModel.orientationOptions.entries
                .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
            onChanged: viewModel.isLoading
                ? null
                : (val) {
                    if (val != null) viewModel.setOrientation(val);
                  },
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------
  // Single Image Content
  // -------------------------------------------------------
  Widget _buildSingleImageContent(BuildContext context, HomeViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: viewModel.isLoading ? null : () => viewModel.pickImage(),
          icon: const Icon(Icons.photo_library),
          label: const Text('Select Image'),
        ),
        const SizedBox(height: 20),
        _buildImageDisplay(context, 'Original Image', viewModel.selectedImage),
        const SizedBox(height: 20),
        if (viewModel.selectedImage != null && !viewModel.isLoading)
          ElevatedButton.icon(
            onPressed: () => viewModel.translateImage(),
            icon: const Icon(Icons.translate, color: Colors.white),
            label: const Text('Translate'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        const SizedBox(height: 20),
        if (viewModel.isLoading)
          _buildProgressIndicator(viewModel)
        else if (viewModel.translatedImageBytes != null)
          _buildImageDisplayFromBytes(
              context, 'Translated Image', viewModel.translatedImageBytes),
      ],
    );
  }

  // -------------------------------------------------------
  // Chapter Content
  // -------------------------------------------------------
  Widget _buildChapterContent(BuildContext context, HomeViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Pick buttons ---
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: viewModel.isLoading
                    ? null
                    : () => viewModel.pickChapterImages(),
                icon: const Icon(Icons.photo_library),
                label: const Text('Select Images'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    viewModel.isLoading ? null : () => viewModel.pickZipFile(),
                icon: const Icon(Icons.folder_zip),
                label: const Text('Select ZIP'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // --- Selected files info ---
        if (viewModel.selectedChapterImages.isNotEmpty && !viewModel.isLoading)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${viewModel.selectedChapterImages.length} file(s) selected',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Thumbnail grid of selected images
              _buildThumbnailGrid(viewModel.selectedChapterImages),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => viewModel.translateChapter(),
                icon: const Icon(Icons.translate, color: Colors.white),
                label: Text(
                    'Translate ${viewModel.selectedChapterImages.length} Page(s)'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ],
          ),
        const SizedBox(height: 20),

        // --- Progress ---
        if (viewModel.isLoading) _buildProgressIndicator(viewModel),

        // --- Chapter results ---
        if (!viewModel.isLoading && viewModel.translatedChapterPages.isNotEmpty)
          _buildChapterResults(context, viewModel),
      ],
    );
  }

  Widget _buildThumbnailGrid(List<File> images) {
    // Show first file name if it's a ZIP
    if (images.length == 1 && images.first.path.toLowerCase().endsWith('.zip')) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_zip, size: 32, color: Colors.orange),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  images.first.path.split(RegExp(r'[/\\]')).last,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                images[index],
                width: 60,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChapterResults(BuildContext context, HomeViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Translated Pages (${viewModel.translatedChapterPages.length})',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: viewModel.translatedChapterPages.length,
          itemBuilder: (context, index) {
            final pageBytes = viewModel.translatedChapterPages[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          FullScreenImageViewer(imageBytes: pageBytes),
                    ),
                  );
                },
                child: Column(
                  children: [
                    Text(
                      'Page ${index + 1}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(pageBytes, fit: BoxFit.contain),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // -------------------------------------------------------
  // Shared widgets
  // -------------------------------------------------------
  Widget _buildProgressIndicator(HomeViewModel viewModel) {
    return Column(
      children: [
        LinearProgressIndicator(
          value: viewModel.progressPercent > 0
              ? viewModel.progressPercent / 100.0
              : null,
        ),
        const SizedBox(height: 8),
        Text(
          viewModel.progressMessage,
          style: const TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        if (viewModel.progressPercent > 0)
          Text(
            '${viewModel.progressPercent}%',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
      ],
    );
  }

  Widget _buildImageDisplay(BuildContext context, String title, File? imageFile) {
    return Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            if (imageFile != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FullScreenImageViewer(imageFile: imageFile),
                ),
              );
            }
          },
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: imageFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(imageFile, fit: BoxFit.contain),
                  )
                : Container(
                    height: 250,
                    alignment: Alignment.center,
                    child: const Text('No image selected',
                        style: TextStyle(color: Colors.grey)),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageDisplayFromBytes(
      BuildContext context, String title, Uint8List? imageBytes) {
    return Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            if (imageBytes != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      FullScreenImageViewer(imageBytes: imageBytes),
                ),
              );
            }
          },
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: imageBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(imageBytes, fit: BoxFit.contain),
                  )
                : Container(
                    height: 250,
                    alignment: Alignment.center,
                    child: const Text('No image to display',
                        style: TextStyle(color: Colors.grey)),
                  ),
          ),
        ),
      ],
    );
  }
}