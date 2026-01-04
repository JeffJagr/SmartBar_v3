import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/app_controller.dart';
import 'repositories/history_repository.dart';
import 'repositories/inventory_repository.dart';
import 'repositories/note_repository.dart';
import 'repositories/orders_repository.dart';
import 'repositories/product_repository.dart';
import 'repositories/users_repository.dart';
import 'repositories/layout_repository.dart';
import 'repositories/group_repository.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/company/company_list_screen.dart';
import 'ui/screens/home/home_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'theme/app_theme.dart';
import 'viewmodels/inventory_view_model.dart';
import 'viewmodels/notes_view_model.dart';
import 'viewmodels/orders_view_model.dart';
import 'viewmodels/history_view_model.dart';
import 'viewmodels/users_view_model.dart';
import 'viewmodels/layout_view_model.dart';

class SmartBarApp extends StatelessWidget {
  const SmartBarApp({super.key, required this.appState});

  final AppController appState;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppController>.value(value: appState),
        ProxyProvider<AppController, InventoryRepository>(
          update: (context, app, previous) => app.activeCompany != null
              ? FirestoreInventoryRepository(companyId: app.activeCompany!.id)
              : InMemoryInventoryRepository(),
          dispose: (_, repo) {
            if (repo is InMemoryInventoryRepository) repo.dispose();
          },
        ),
        ProxyProvider<AppController, GroupRepository?>(
          update: (context, app, previous) => app.activeCompany != null
              ? FirestoreGroupRepository(companyId: app.activeCompany!.id)
              : InMemoryGroupRepository(),
        ),
        ProxyProvider<AppController, HistoryRepository?>(
          update: (context, app, previous) => app.activeCompany != null
              ? FirestoreHistoryRepository(companyId: app.activeCompany!.id)
              : null,
        ),
        ProxyProvider<AppController, NoteRepository>(
          update: (context, app, previous) => app.activeCompany != null
              ? FirestoreNoteRepository(companyId: app.activeCompany!.id)
              : InMemoryNoteRepository(),
          dispose: (_, repo) {
            if (repo is InMemoryNoteRepository) repo.dispose();
          },
        ),
        ProxyProvider<AppController, ProductRepository>(
          update: (context, app, previous) => app.activeCompany != null
              ? FirestoreProductRepository(companyId: app.activeCompany!.id)
              : InMemoryProductRepository(),
          dispose: (_, repo) {
            if (repo is InMemoryProductRepository) repo.dispose();
          },
        ),
        ChangeNotifierProxyProvider3<InventoryRepository, GroupRepository?, HistoryRepository?,
            InventoryViewModel>(
          create: (ctx) => InventoryViewModel(
                ctx.read<InventoryRepository>(),
                ctx.read<GroupRepository?>(),
                ctx.read<HistoryRepository?>(),
              )..init(),
          update: (ctx, repo, groupRepo, historyRepo, vm) {
            vm ??= InventoryViewModel(repo, groupRepo, historyRepo);
            vm.replaceRepository(repo);
            vm.applyPermissionContext(
              snapshot: ctx.read<AppController>().permissionSnapshot(
                    ctx.read<AppController>().permissions,
                  ),
              service: ctx.read<AppController>().permissions,
            );
            return vm;
          },
        ),
        ChangeNotifierProxyProvider3<NoteRepository, ProductRepository, HistoryRepository?,
            NotesViewModel>(
          create: (ctx) => NotesViewModel(
                ctx.read<NoteRepository>(),
                ctx.read<ProductRepository>(),
                ctx.read<HistoryRepository?>(),
              )..init(),
          update: (ctx, noteRepo, productRepo, historyRepo, vm) {
            vm ??= NotesViewModel(noteRepo, productRepo, historyRepo);
            vm.replaceRepository(noteRepo);
            return vm;
          },
        ),
        ProxyProvider<AppController, UsersRepository?>(
          update: (context, app, previous) => app.activeCompany != null
              ? FirestoreUsersRepository(companyId: app.activeCompany!.id)
              : null,
        ),
        ProxyProvider<AppController, LayoutRepository?>(
          update: (context, app, previous) => app.activeCompany != null
              ? FirestoreLayoutRepository(companyId: app.activeCompany!.id)
              : null,
        ),
        ProxyProvider<AppController, HistoryRepository?>(
          update: (context, app, previous) => app.activeCompany != null
              ? FirestoreHistoryRepository(companyId: app.activeCompany!.id)
              : null,
        ),
        ChangeNotifierProxyProvider<HistoryRepository?, HistoryViewModel?>(
          create: (ctx) {
            final repo = ctx.read<HistoryRepository?>();
            if (repo == null) return null;
            return HistoryViewModel(repo)..init();
          },
          update: (ctx, repo, vm) {
            if (repo == null) return null;
            vm ??= HistoryViewModel(repo);
            vm.init();
            return vm;
          },
        ),
        ChangeNotifierProxyProvider2<UsersRepository?, AppController, UsersViewModel?>(
          create: (ctx) {
            final repo = ctx.read<UsersRepository?>();
            if (repo == null) return null;
            final app = ctx.read<AppController>();
            final vm = UsersViewModel(repo)..init();
            vm.applyPermissionContext(
              snapshot: app.permissionSnapshot(app.permissions),
              service: app.permissions,
            );
            return vm;
          },
          update: (ctx, repo, app, vm) {
            if (repo == null) return null;
            vm ??= UsersViewModel(repo);
            vm.init();
            vm.applyPermissionContext(
              snapshot: app.permissionSnapshot(app.permissions),
              service: app.permissions,
            );
            return vm;
          },
        ),
        ProxyProvider<AppController, OrdersRepository?>(
          update: (context, app, previous) => app.activeCompany != null
              ? FirestoreOrdersRepository(companyId: app.activeCompany!.id)
              : null,
        ),
        ChangeNotifierProxyProvider4<OrdersRepository?, InventoryRepository,
            HistoryRepository?, AppController, OrdersViewModel?>(
          create: (ctx) {
            final ordersRepo = ctx.read<OrdersRepository?>();
            if (ordersRepo == null) return null;
            final vm =
                OrdersViewModel(ordersRepo, ctx.read<InventoryRepository>(), historyRepo: ctx.read<HistoryRepository?>())..init();
            vm.applyPermissionContext(
              snapshot: ctx.read<AppController>().permissionSnapshot(
                    ctx.read<AppController>().permissions,
                  ),
              service: ctx.read<AppController>().permissions,
            );
            return vm;
          },
          update: (ctx, ordersRepo, inventoryRepo, historyRepo, app, vm) {
            if (ordersRepo == null) return null;
            vm ??= OrdersViewModel(ordersRepo, inventoryRepo, historyRepo: historyRepo);
            vm.init();
            vm.applyPermissionContext(
              snapshot: app.permissionSnapshot(app.permissions),
              service: app.permissions,
            );
            return vm;
          },
        ),
        ChangeNotifierProxyProvider2<LayoutRepository?, AppController, LayoutViewModel?>(
          create: (ctx) {
            final repo = ctx.read<LayoutRepository?>();
            if (repo == null) return null;
            final app = ctx.read<AppController>();
            final vm = LayoutViewModel(repo);
            vm.applyPermissionContext(
              snapshot: app.permissionSnapshot(app.permissions),
              service: app.permissions,
            );
            return vm;
          },
          update: (ctx, repo, app, vm) {
            if (repo == null) return null;
            vm ??= LayoutViewModel(repo);
            vm.replaceRepository(repo);
            vm.applyPermissionContext(
              snapshot: app.permissionSnapshot(app.permissions),
              service: app.permissions,
            );
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
