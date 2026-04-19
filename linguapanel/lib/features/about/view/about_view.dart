import 'package:flutter/material.dart';
import 'package:linguapanel/features/about/viewmodel/about_viewmodel.dart';
import 'package:provider/provider.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AboutViewModel(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('About'),
        ),
        body: Consumer<AboutViewModel>(
          builder: (context, viewModel, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset('lib/images/logo.png', height: 100),
                  const SizedBox(height: 16),
                  Text(
                    viewModel.appName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text('Version ${viewModel.version}'),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildSectionTitle(context, 'Quick Guide'),
                  const SizedBox(height: 8),
                  const ListTile(
                    leading: Icon(Icons.image_search),
                    title: Text('Use high-resolution images for best results.'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.touch_app),
                    title: Text('Tap on an image to view it in full screen.'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.star),
                    title: Text('Mark your favorite translations for easy access.'),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildSectionTitle(context, 'Feedback'),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.rate_review),
                    title: const Text('Rate on Google Play'),
                    onTap: () {
                      // TODO: Replace with your app's Play Store URL
                      viewModel.launchURL('https://play.google.com/store/apps/details?id=your.package.name');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('Send Feedback'),
                    onTap: () => viewModel.sendFeedback(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge,
    );
  }
}