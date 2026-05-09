import 'package:linguapanel/core/utils/ui_helpers.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:linguapanel/features/home/viewmodel/home_viewmodel.dart';
import 'package:linguapanel/features/widgets/full_screen_image_viewer.dart';
import 'package:provider/provider.dart';

/// Home tab content — no Scaffold/AppBar, used inside MainShell.
class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.errorMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            UIHelpers.showErrorSnackBar(context, viewModel.errorMessage!);
            viewModel.setErrorMessage(null);
          });
        }
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Mode Toggle ---
                _buildModeToggle(context, viewModel),
                const SizedBox(height: 16),

                // --- Settings Card ---
                _buildSettingsCard(context, viewModel),
                const SizedBox(height: 16),

                // --- Content based on mode ---
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeIn,
                  switchOutCurve: Curves.easeOut,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  child: viewModel.mode == TranslationMode.single
                      ? _buildSingleImageContent(context, viewModel)
                      : _buildChapterContent(context, viewModel),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isZipSelected(HomeViewModel viewModel) {
    return viewModel.selectedChapterImages.length == 1 &&
        viewModel.selectedChapterImages.first.path
            .toLowerCase()
            .endsWith('.zip');
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
          icon: Icon(Icons.image_rounded),
        ),
        ButtonSegment(
          value: TranslationMode.chapter,
          label: Text('Chapter'),
          icon: Icon(Icons.collections_rounded),
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
  // Settings Card
  // -------------------------------------------------------
  Widget _buildSettingsCard(BuildContext context, HomeViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Translation Settings',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: viewModel.selectedLang,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Language',
                      prefixIcon: Icon(Icons.language_rounded, size: 20),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    items: HomeViewModel.languageOptions.entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis),
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
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Direction',
                      prefixIcon:
                          Icon(Icons.text_rotation_none_rounded, size: 20),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    items: HomeViewModel.orientationOptions.entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis),
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
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // Single Image Content
  // -------------------------------------------------------
  Widget _buildSingleImageContent(
      BuildContext context, HomeViewModel viewModel) {
    return Column(
      key: const ValueKey('single'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildActionButton(
          icon: Icons.add_photo_alternate_rounded,
          label: 'Select Image',
          onPressed: viewModel.isLoading ? null : () => viewModel.pickImage(),
        ),
        const SizedBox(height: 16),
        _buildImageCard(context, 'Original Image', viewModel.selectedImage),
        if (viewModel.selectedImage != null && !viewModel.isLoading) ...[
          const SizedBox(height: 16),
          _buildActionButton(
            icon: Icons.translate_rounded,
            label: 'Translate',
            color: const Color(0xFF34D399),
            onPressed: () => viewModel.translateImage(),
          ),
        ],
        const SizedBox(height: 16),
        if (viewModel.isLoading)
          _buildProgressCard(viewModel)
        else if (viewModel.translatedImageBytes != null)
          _buildResultCard(context, viewModel.translatedImageBytes!),
      ],
    );
  }

  // -------------------------------------------------------
  // Chapter Content
  // -------------------------------------------------------
  Widget _buildChapterContent(BuildContext context, HomeViewModel viewModel) {
    return Column(
      key: const ValueKey('chapter'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pick buttons
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.photo_library_rounded,
                label: 'Select Images',
                onPressed: viewModel.isLoading
                    ? null
                    : () => viewModel.pickChapterImages(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.folder_zip_rounded,
                label: 'Select ZIP',
                onPressed: viewModel.isLoading
                    ? null
                    : () => viewModel.pickZipFile(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Selected files
        if (viewModel.selectedChapterImages.isNotEmpty &&
            !viewModel.isLoading) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _isZipSelected(viewModel)
                            ? Icons.folder_zip_rounded
                            : Icons.collections_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isZipSelected(viewModel)
                            ? '1 ZIP file selected'
                            : '${viewModel.selectedChapterImages.length} image(s) selected',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  if (!_isZipSelected(viewModel)) ...[
                    const SizedBox(height: 12),
                    _buildThumbnailGrid(viewModel.selectedChapterImages),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            icon: Icons.translate_rounded,
            label: _isZipSelected(viewModel)
                ? 'Translate ZIP'
                : 'Translate ${viewModel.selectedChapterImages.length} Image(s)',
            color: const Color(0xFF34D399),
            onPressed: () => viewModel.translateChapter(),
          ),
        ],
        const SizedBox(height: 16),

        if (viewModel.isLoading) _buildProgressCard(viewModel),

        if (!viewModel.isLoading &&
            viewModel.translatedChapterPages.isNotEmpty)
          _buildChapterResults(context, viewModel),
      ],
    );
  }

  // -------------------------------------------------------
  // Shared Components
  // -------------------------------------------------------
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
    Color? color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: color != null
          ? ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildProgressCard(HomeViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(
                      viewModel.progressPercent > 0
                          ? const Color(0xFF34D399)
                          : const Color(0xFF60A5FA),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    viewModel.progressMessage,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (viewModel.progressPercent > 0) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: viewModel.progressPercent / 100.0,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor:
                      const AlwaysStoppedAnimation(Color(0xFF34D399)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${viewModel.progressPercent}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Color(0xFF34D399),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard(BuildContext context, String title, File? imageFile) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.image_rounded,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              if (imageFile != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        FullScreenImageViewer(imageFile: imageFile),
                  ),
                );
              }
            },
            child: imageFile != null
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: double.infinity,
                        child: Image.file(imageFile, fit: BoxFit.contain),
                      ),
                    ),
                  )
                : Container(
                    width: double.infinity,
                    height: 200,
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.15),
                        width: 1.5,
                        strokeAlign: BorderSide.strokeAlignInside,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 48,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No image selected',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, Uint8List imageBytes) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 18, color: Color(0xFF34D399)),
                const SizedBox(width: 8),
                Text('Translated Result',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FullScreenImageViewer(imageBytes: imageBytes),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(imageBytes, fit: BoxFit.contain),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailGrid(List<File> images) {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                images[index],
                width: 52,
                height: 72,
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChapterResults(BuildContext context, HomeViewModel viewModel) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 18, color: Color(0xFF34D399)),
                const SizedBox(width: 8),
                Text(
                  'Translated (${viewModel.translatedChapterPages.length} pages)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: viewModel.translatedChapterPages.length,
            itemBuilder: (context, index) {
              final pageBytes = viewModel.translatedChapterPages[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          FullScreenImageViewer(imageBytes: pageBytes),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4, left: 4),
                          child: Text(
                            'Page ${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child:
                            Image.memory(pageBytes, fit: BoxFit.contain),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}