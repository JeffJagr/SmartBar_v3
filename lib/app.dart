import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/app_controller.dart';
import 'repositories/history_repository.dart';
import 'repositories/inventory_repository.dart';
import 'repositories/note_repository.dart';
import 'repositories/product_repository.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/company/company_list_screen.dart';
import 'ui/screens/home/home_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'theme/app_theme.dart';
import 'viewmodels/inventory_view_model.dart';
import 'viewmodels/notes_view_model.dart';

class SmartBarApp extends StatelessWidget {
  const SmartBarApp({super.key, required this.appState});

  final AppController appState;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppController>.value(value: appState),
        ProxyProvider<AppController, InventoryRepository>(
          update: (_, app, __) => app.activeCompany != null
              ? FirestoreInventoryRepository(companyId: app.activeCompany!.id)
              : InMemoryInventoryRepository(),
          dispose: (_, repo) {
            if (repo is InMemoryInventoryRepository) repo.dispose();
          },
        ),
        ProxyProvider<AppController, HistoryRepository?>(
          update: (_, app, __) => app.activeCompany != null
              ? FirestoreHistoryRepository(companyId: app.activeCompany!.id)
              : null,
        ),
        ProxyProvider<AppController, NoteRepository>(
          update: (_, app, __) => app.activeCompany != null
              ? FirestoreNoteRepository(companyId: app.activeCompany!.id)
              : InMemoryNoteRepository(),
          dispose: (_, repo) {
            if (repo is InMemoryNoteRepository) repo.dispose();
          },
        ),
        ProxyProvider<AppController, ProductRepository>(
          update: (_, app, __) => app.activeCompany != null
              ? FirestoreProductRepository(companyId: app.activeCompany!.id)
              : InMemoryProductRepository(),
          dispose: (_, repo) {
            if (repo is InMemoryProductRepository) repo.dispose();
          },
        ),
        ChangeNotifierProxyProvider<InventoryRepository, InventoryViewModel>(
          create: (ctx) => InventoryViewModel(ctx.read<InventoryRepository>())..init(),
          update: (ctx, repo, vm) {
            vm ??= InventoryViewModel(repo);
            vm.replaceRepository(repo);
            return vm;
          },
        ),
        ChangeNotifierProxyProvider2<NoteRepository, ProductRepository, NotesViewModel>(
          create: (ctx) =>
              NotesViewModel(ctx.read<NoteRepository>(), ctx.read<ProductRepository>())..init(),
          update: (ctx, noteRepo, productRepo, vm) {
            vm ??= NotesViewModel(noteRepo, productRepo);
            vm.replaceRepository(noteRepo);
            return vm;
          },
        ),
      ],
      child: Consumer<AppController>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'Smart Bar Stock',
            debugShowCheckedModeBanner: false,
            themeMode: state.themeMode,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: _buildHome(state),
          );
        },
      ),
    );
  }

  Widget _buildHome(AppController state) {
    if (!state.isBootstrapped) {
      return const SplashScreen();
    }
    if (!state.isAuthenticated) {
      return const RoleSelectionScreen();
    }
    if (state.isOwner && state.activeCompany == null) {
      return const CompanyListScreen();
    }
    return const HomeScreen();
  }
}
