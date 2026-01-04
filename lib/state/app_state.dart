import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/company.dart';
import '../models/history_entry.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/staff_member.dart';
import '../models/staff_session.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/messaging_service.dart';
import '../services/permission_service.dart';
import '../repositories/membership_repository.dart';

class AppState extends ChangeNotifier {
  AppState({
    required AuthService authService,
    required FirestoreService firestoreService,
    required MessagingService messagingService,
    MembershipRepository? membershipRepository,
  }) : _authService = authService,
       _firestoreService = firestoreService,
       _messagingService = messagingService,
       _membershipRepository =
           membershipRepository ?? FirestoreMembershipRepository();

  final AuthService _authService;
  final FirestoreService _firestoreService;
  final MessagingService _messagingService;
  final MembershipRepository _membershipRepository;

  User? ownerUser;
  StaffSession? staffSession;
  StaffMember? currentStaff;
  Company? activeCompany;
  List<Company> companies = [];
  List<Product> products = [];
  List<OrderModel> orders = [];
  List<HistoryEntry> history = [];
  Map<String, bool> currentUserPermissions = {};
  String? currentUserRole;

  ThemeMode themeMode = ThemeMode.system;
  bool isBootstrapped = false;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<Product>>? _productsSubscription;
  StreamSubscription<List<OrderModel>>? _ordersSubscription;
  StreamSubscription<List<HistoryEntry>>? _historySubscription;

  bool get isAuthenticated => ownerUser != null || staffSession != null;
  bool get isOwner => ownerUser != null;
  MessagingService get messagingService => _messagingService;
  UserRole get role {
    if (isOwner) return UserRole.owner;
    final roleLower = (currentUserRole ?? currentStaff?.role ?? '')
        .toLowerCase();
    if (roleLower.contains('manager')) return UserRole.manager;
    if (roleLower.contains('owner')) return UserRole.owner;
    return UserRole.staff;
  }

  /// Re-attach company streams (products/orders/history) for the active company.
  Future<void> refreshActiveCompany() async {
    final id = activeCompany?.id;
    if (id == null || id.isEmpty) return;
    await _attachCompanyStreams(id);
    notifyListeners();
  }

  String get roleLabel {
    if (isOwner) return 'owner';
    if (currentUserRole != null && currentUserRole!.isNotEmpty)
      return currentUserRole!;
    if (currentStaff?.role.isNotEmpty == true) return currentStaff!.role;
    return 'staff';
  }

  String get displayName =>
      ownerUser?.email ?? staffSession?.displayName ?? 'Guest';

  PermissionSnapshot permissionSnapshot(PermissionService service) {
    final perms = currentUserPermissions.isNotEmpty
        ? currentUserPermissions
        : _defaultsForRole(role);
    return service.fromApp(app: this, explicitFlags: perms);
  }

  Future<void> bootstrap() async {
    final existing = FirebaseAuth.instance.currentUser;
    if (existing != null && existing.isAnonymous) {
      await _authService.signOut();
    }
    // Defensive: ensure we never start owner flows under anonymous/stale sessions.
    if (FirebaseAuth.instance.currentUser?.isAnonymous == true) {
      await _authService.signOut();
    }
    try {
      final opts = Firebase.app().options;
      debugPrint(
        '[AppStart] projectId=${opts.projectId} uid=${FirebaseAuth.instance.currentUser?.uid ?? 'none'} isAnon=${FirebaseAuth.instance.currentUser?.isAnonymous ?? false}',
      );
    } catch (_) {
      // best-effort diagnostics
    }
    await _messagingService.init();
    await _messagingService.requestPermission();
    await _messagingService.fetchToken();
    _messagingService.listenToForegroundMessages();

    _authSubscription = _authService.onAuthStateChanged.listen((user) async {
      if (user != null && user.isAnonymous) {
        // Staff sessions sign in anonymously for Firestore access; skip owner handling.
        ownerUser = null;
        notifyListeners();
        return;
      }
      ownerUser = user;
      if (ownerUser != null) {
        await _ensureUserProfile(ownerUser!.uid, fallbackRole: 'owner');
      }
      // Staff auth is not driven by FirebaseAuth so we keep staffSession intact.
      if (ownerUser == null) {
        companies = [];
        activeCompany = null;
      } else {
        companies = await _firestoreService.fetchCompaniesForUser(
          ownerId: ownerUser!.uid,
          email: ownerUser!.email,
        );
        if (companies.isNotEmpty) {
          await setActiveCompany(activeCompany ?? companies.first);
        } else {
          activeCompany = null;
        }
      }
      notifyListeners();
    });

    isBootstrapped = true;
    notifyListeners();
  }

  Future<void> registerOwner(
    String email,
    String password, {
    String? displayName,
  }) async {
    final trimmedEmail = email.trim();
    final trimmedPassword = password.trim();
    final current = FirebaseAuth.instance.currentUser;
    if (current != null && current.isAnonymous) {
      await _authService.signOut();
    }
    if (trimmedEmail.isEmpty) {
      throw FormatException('Email is required');
    }
    final emailValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailValid.hasMatch(trimmedEmail)) {
      throw FormatException('Enter a valid email address');
    }
    if (trimmedPassword.length < 8) {
      throw FormatException('Password must be at least 8 characters');
    }

    try {
      final credential = await _authService.registerOwner(
        email: trimmedEmail,
        password: trimmedPassword,
      );
      final user = credential.user;
      final name = (displayName?.trim().isNotEmpty ?? false)
          ? displayName!.trim()
          : trimmedEmail;

      if (user != null) {
        await user.updateDisplayName(name);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'displayName': name,
          'email': trimmedEmail,
          'role': 'owner',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Registration failed');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signInOwner(String email, String password) async {
    // If currently signed in anonymously (e.g., after staff use), sign out first.
    final current = FirebaseAuth.instance.currentUser;
    if (current != null && current.isAnonymous) {
      await _authService.signOut();
    }
    await _authService.signInOwner(email: email, password: password);
    await _ensureUserProfile(
      FirebaseAuth.instance.currentUser?.uid,
      fallbackRole: 'owner',
    );
    // Auth listener will populate companies and active company.
  }

  Future<void> signInStaff({
    required String companyCode,
    required String pin,
  }) async {
    try {
      staffSession = await _authService.signInStaff(
        companyCode: companyCode,
        pin: pin,
      );
      final companyId = staffSession?.companyId ?? '';
      final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final staffDocId = staffSession?.staffId.isNotEmpty == true
          ? staffSession!.staffId
          : authUid;
      if (companyId.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-company',
          message:
              'No company found for this PIN. Ask your manager to recreate the staff code.',
        );
      }
      if (authUid.isEmpty) {
        throw FirebaseAuthException(
          code: 'no-auth-uid',
          message: 'Could not establish authentication for staff login.',
        );
      }

      currentStaff = StaffMember(
        id: staffDocId,
        companyId: companyId,
        name: staffSession?.displayName ?? 'Staff',
        pin: pin,
        role: staffSession?.role ?? 'staff',
        permissions: (staffSession?.permissions ?? {}).map(
          (k, v) => MapEntry(k, v == true),
        ),
      );
      currentUserPermissions = (currentStaff?.permissions ?? {});
      currentUserRole = currentUserRole ?? currentStaff?.role;
      if (currentUserPermissions.isEmpty) {
        currentUserPermissions = _defaultsForRole(role);
      }

      // Fetch company after membership docs exist so rules pass.
      activeCompany = companyId.isNotEmpty
          ? await _firestoreService.fetchCompanyById(companyId)
          : null;
      companies = activeCompany != null ? [activeCompany!] : [];

      // Clear company-scoped data to avoid leaking previous company state.
      products = [];
      orders = [];
      history = [];
      notifyListeners();

      if (activeCompany == null && companyId.isNotEmpty) {
        activeCompany = Company(
          id: companyId,
          name: staffSession?.displayName ?? 'Company',
          companyCode: companyCode,
          ownerIds: const [],
          createdAt: DateTime.now(),
        );
      }

      await _attachCompanyStreams(companyId);
      await _hydrateMemberPermissions(companyId);
      notifyListeners();
    } on FirebaseException catch (e) {
      debugPrint(
        'Staff login FirebaseException: code=${e.code} message=${e.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint('Staff login error: $e');
      rethrow;
    }
  }

  Map<String, bool> _defaultsForRole(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return {
          'editProducts': true,
          'adjustQuantities': true,
          'createOrders': true,
          'confirmOrders': true,
          'receiveOrders': true,
          'transferStock': true,
          'setRestockHint': true,
          'viewHistory': true,
          'addNotes': true,
          'manageUsers': true,
          'manageSuppliers': true,
        };
      case UserRole.manager:
        return {
          'editProducts': true,
          'adjustQuantities': true,
          'createOrders': true,
          'confirmOrders': true,
          'receiveOrders': true,
          'transferStock': true,
          'setRestockHint': true,
          'viewHistory': true,
          'addNotes': true,
          'manageUsers': false,
          'manageSuppliers': true,
        };
      case UserRole.staff:
        return {
          'editProducts': false,
          'adjustQuantities': false,
          'createOrders': true,
          'confirmOrders': false,
          'receiveOrders': false,
          'transferStock': false,
          'setRestockHint': true,
          'viewHistory': false,
          'addNotes': true,
          'manageUsers': false,
          'manageSuppliers': false,
        };
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    staffSession = null;
    currentStaff = null;
    ownerUser = null;
    currentUserPermissions = {};
    currentUserRole = null;
    await _closeCompanyStreams();
    companies = [];
    products = [];
    orders = [];
    history = [];
    activeCompany = null;
    notifyListeners();
  }

  Future<void> setActiveCompany(Company company) async {
    if (activeCompany?.id == company.id) return;
    activeCompany = company;
    // Clear stale data before reattaching streams.
    products = [];
    orders = [];
    history = [];
    notifyListeners();
    await _ensureCompanyMembershipDoc(company.id);
    await _hydrateMemberPermissions(company.id);
    await _attachCompanyStreams(company.id);
    notifyListeners();
  }

  Future<void> _attachCompanyStreams(String companyId) async {
    await _closeCompanyStreams();
    if (companyId.isEmpty) return;

    _productsSubscription = _firestoreService
        .productsStream(companyId)
        .listen(
          (data) {
            products = data;
            notifyListeners();
          },
          onError: (_) {
            products = _sampleProducts(companyId);
            notifyListeners();
          },
        );

    _ordersSubscription = _firestoreService
        .ordersStream(companyId)
        .listen(
          (data) {
            orders = data;
            notifyListeners();
          },
          onError: (_) {
            orders = _sampleOrders(companyId);
            notifyListeners();
          },
        );

    _historySubscription = _firestoreService
        .historyStream(companyId)
        .listen(
          (data) {
            history = data;
            notifyListeners();
          },
          onError: (_) {
            history = _sampleHistory(companyId);
            notifyListeners();
          },
        );

    // Hydrate role/permissions from membership doc for UI/permission checks.
    await _hydrateMemberPermissions(companyId);
  }

  Future<void> _closeCompanyStreams() async {
    await _productsSubscription?.cancel();
    await _ordersSubscription?.cancel();
    await _historySubscription?.cancel();
  }

  void toggleThemeMode() {
    if (themeMode == ThemeMode.dark) {
      themeMode = ThemeMode.light;
    } else if (themeMode == ThemeMode.light) {
      themeMode = ThemeMode.system;
    } else {
      themeMode = ThemeMode.dark;
    }
    notifyListeners();
  }

  List<Product> _sampleProducts(String companyId) {
    return [
      Product(
        id: 'p1',
        companyId: companyId,
        name: 'House Lager',
        group: 'Beer',
        subgroup: 'Draft',
        unit: 'keg',
        barQuantity: 3,
        barMax: 5,
        warehouseQuantity: 6,
        warehouseTarget: 10,
        salePrice: 5.50,
        restockHint: 0,
      ),
      Product(
        id: 'p2',
        companyId: companyId,
        name: 'Gin Bottle',
        group: 'Spirits',
        subgroup: 'Gin',
        unit: 'bottle',
        barQuantity: 8,
        barMax: 12,
        warehouseQuantity: 12,
        warehouseTarget: 20,
        salePrice: 9.00,
        restockHint: 0,
      ),
    ];
  }

  Future<Company> createCompany({
    required String name,
    required String companyCode,
  }) async {
    if (ownerUser == null || ownerUser!.isAnonymous) {
      throw StateError('Only signed-in owners can create companies.');
    }
    final result = await _firestoreService.createCompany(
      name: name,
      ownerId: ownerUser!.uid,
      companyCode: companyCode,
    );
    companies = [...companies, result];
    await setActiveCompany(result);
    return result;
  }

  List<OrderModel> _sampleOrders(String companyId) {
    return [
      OrderModel(
        id: 'o1',
        companyId: companyId,
        orderNumber: 1,
        createdByUserId: 'demo',
        supplier: 'Local Brewery',
        status: OrderStatus.pending,
        items: const [
          OrderItem(
            productId: 'p1',
            productNameSnapshot: 'House Lager',
            quantityOrdered: 4,
            unitCost: 120,
          ),
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      OrderModel(
        id: 'o2',
        companyId: companyId,
        orderNumber: 2,
        createdByUserId: 'demo',
        supplier: 'Spirits Co',
        status: OrderStatus.delivered,
        items: const [
          OrderItem(
            productId: 'p2',
            productNameSnapshot: 'Gin Bottle',
            quantityOrdered: 6,
            unitCost: 22,
          ),
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];
  }

  List<HistoryEntry> _sampleHistory(String companyId) {
    return [
      HistoryEntry(
        id: 'h1',
        companyId: companyId,
        actionType: 'restock',
        itemName: 'House Lager',
        description: 'Moved 2 kegs from warehouse to bar',
        performedBy: displayName,
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        details: {'quantity': 2, 'unit': 'keg'},
      ),
      HistoryEntry(
        id: 'h2',
        companyId: companyId,
        actionType: 'order',
        itemName: 'Order #SO-1001',
        description: 'Order to Spirits Co delivered',
        performedBy: displayName,
        timestamp: DateTime.now().subtract(const Duration(hours: 10)),
        details: {'status': 'delivered'},
      ),
    ];
  }

  // Deprecated legacy staff lookup kept for reference.
  // ignore: unused_element
  Future<StaffMember?> _fetchStaffMember(String companyId, String pin) async =>
      null;

  Future<void> _hydrateMemberPermissions(String companyId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) return;
      final member = await _membershipRepository.getMember(
        companyId: companyId,
        uid: uid,
      );
      if (member != null) {
        currentUserPermissions = member.permissions;
        currentUserRole = member.role;
      } else {
        currentUserPermissions = {};
        currentUserRole = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint(
        'Hydrate member permissions failed for company $companyId: $e',
      );
    }
  }

  Future<void> _ensureCompanyMembershipDoc(String companyId) async {
    if (ownerUser == null || companyId.isEmpty) return;
    try {
      final uid = ownerUser!.uid;
      await _membershipRepository.upsertMemberSelf(
        companyId: companyId,
        uid: uid,
        role: 'owner',
        permissions: _defaultsForRole(UserRole.owner),
        displayName: ownerUser?.displayName ?? ownerUser?.email ?? 'Owner',
      );
    } catch (_) {
      // best effort; rules still allow owner via ownerIds
    }
  }

  Future<void> _ensureUserProfile(
    String? uid, {
    String fallbackRole = 'staff',
  }) async {
    if (uid == null) return;
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(uid);
      final doc = await ref.get();
      if (!doc.exists) {
        await ref.set({
          'role': fallbackRole,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // ignore profile load errors
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _closeCompanyStreams();
    super.dispose();
  }
}
