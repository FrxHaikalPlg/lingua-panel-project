import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:linguapanel/core/services/auth_service.dart';
import 'package:linguapanel/features/history/view/favorites_view.dart';
import 'package:linguapanel/features/history/view/history_view.dart';
import 'package:linguapanel/features/history/viewmodel/history_viewmodel.dart';
import 'package:linguapanel/features/home/view/home_view.dart';
import 'package:linguapanel/features/home/viewmodel/home_viewmodel.dart';
import 'package:linguapanel/features/settings/view/settings_view.dart';
import 'package:provider/provider.dart';

/// Main app shell with bottom navigation bar.
/// Hosts Home, History, Favorites, and Settings as tabs.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _titles = ['LinguaPanel', 'History', 'Favorites', 'Settings'];

  void _onTabSelected(BuildContext providerContext, int index) {
    // Refresh history data when switching to History or Favorites tab
    if (index == 1 || index == 2) {
      Provider.of<HistoryViewModel>(providerContext, listen: false).refresh();
    }
    setState(() => _currentIndex = index);
  }

  Future<bool> _onBackPressed(BuildContext providerContext) async {
    // If not on Home tab, go back to Home
    if (_currentIndex != 0) {
      _onTabSelected(providerContext, 0);
      return false;
    }

    // On Home tab: show exit confirmation
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      SystemNavigator.pop();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(create: (_) => HistoryViewModel()),
      ],
      // Builder gives us a context that is BELOW the MultiProvider
      child: Builder(
        builder: (providerContext) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) {
                _onBackPressed(providerContext);
              }
            },
            child: Scaffold(
              appBar: AppBar(
                title: Text(_titles[_currentIndex]),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout_rounded),
                    tooltip: 'Logout',
                    onPressed: () => authService.signOut(),
                  ),
                ],
              ),
              body: IndexedStack(
                index: _currentIndex,
                children: const [
                  HomeContent(),
                  HistoryContent(),
                  FavoritesContent(),
                  SettingsView(),
                ],
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) =>
                    _onTabSelected(providerContext, index),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.history_outlined),
                    selectedIcon: Icon(Icons.history_rounded),
                    label: 'History',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.star_outline_rounded),
                    selectedIcon: Icon(Icons.star_rounded),
                    label: 'Favorites',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings_rounded),
                    label: 'Settings',
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
