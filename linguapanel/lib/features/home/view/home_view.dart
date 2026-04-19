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
                      ElevatedButton.icon(
                        onPressed:
                            viewModel.isLoading ? null : () => viewModel.pickImage(),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Select Manga Panel'),
                      ),
                      const SizedBox(height: 20),
                      _buildImageDisplay(
                          context, 'Original Image', viewModel.selectedImage),
                      const SizedBox(height: 20),
                      if (viewModel.selectedImage != null && !viewModel.isLoading)
                        ElevatedButton.icon(
                          onPressed: () => viewModel.translateImage(),
                          icon:
                              const Icon(Icons.translate, color: Colors.white),
                          label: const Text('Translate'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                        ),
                      const SizedBox(height: 20),
                      if (viewModel.isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (viewModel.translatedImageBytes != null)
                        _buildImageDisplayFromBytes(context, 'Translated Image',
                            viewModel.translatedImageBytes),
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
                    child: const Text('No image selected', style: TextStyle(color: Colors.grey)),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageDisplayFromBytes(BuildContext context, String title, Uint8List? imageBytes) {
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
                  builder: (context) => FullScreenImageViewer(imageBytes: imageBytes),
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
                    child: const Text('No image to display', style: TextStyle(color: Colors.grey)),
                  ),
          ),
        ),
      ],
    );
  }
}