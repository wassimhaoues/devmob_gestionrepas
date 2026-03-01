import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/recipe_provider.dart';
import '../recipe/recipe_list_page.dart';

const String dashboardRoute = '/dashboard';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? _lastSyncedUid;

  @override
  Widget build(BuildContext context) {
    _syncRecipeWatcher(context);

    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.currentUser?.displayName.trim();
    final greeting = userName == null || userName.isEmpty
        ? 'Welcome back'
        : 'Welcome back, $userName';

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion Repas'),
        actions: [
          IconButton(
            onPressed: authProvider.isLoading ? null : _signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              colorScheme.primaryContainer.withValues(alpha: 0.4),
              colorScheme.surface,
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(greeting, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Plan your meals with a clean workflow. Start from your dashboard.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            _DashboardTile(
              title: 'Recipes',
              subtitle: 'Create, edit, and organize your personal recipes.',
              icon: Icons.restaurant_menu,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RecipeListPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _DashboardTile(
              title: 'Meal Plan',
              subtitle: 'Weekly calendar and meal assignment.',
              icon: Icons.calendar_month,
              onTap: () => _showComingSoon('Meal Plan'),
            ),
            const SizedBox(height: 12),
            _DashboardTile(
              title: 'Shopping List',
              subtitle: 'Generated shopping list from planned meals.',
              icon: Icons.shopping_cart,
              onTap: () => _showComingSoon('Shopping List'),
            ),
          ],
        ),
      ),
    );
  }

  void _syncRecipeWatcher(BuildContext context) {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null || uid == _lastSyncedUid) {
      return;
    }

    _lastSyncedUid = uid;
    unawaited(context.read<RecipeProvider>().startWatching(uid: uid));
  }

  Future<void> _signOut() async {
    final recipeProvider = context.read<RecipeProvider>();
    final authProvider = context.read<AuthProvider>();

    await recipeProvider.stopWatching();
    await authProvider.signOut();
  }

  void _showComingSoon(String moduleName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$moduleName module is coming next.')),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.primary,
                child: Icon(icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
