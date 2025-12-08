import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

class AppState extends ChangeNotifier {
  AppState({
    required AuthService authService,
    required FirestoreService firestoreService,
    required MessagingService messagingService,
  })  : _authService = authService,
        _firestoreService = firestoreService,
        _messagingService = messagingService;

  final AuthService _authService;
  final FirestoreService _firestoreService;
  final MessagingService _messagingService;

  User? ownerUser;
  StaffSession? staffSession;
  StaffMember? currentStaff;
  Company? activeCompany;
  List<Company> companies = [];
  List<Product> products = [];
  List<OrderModel> orders = [];
  List<HistoryEntry> history = [];
  Map<String, bool> currentUserPermissions = {};

  ThemeMode themeMode = ThemeMode.system;
  bool isBootstrapped = false;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<Product>>? _productsSubscription;
  StreamSubscription<List<OrderModel>>? _ordersSubscription;
  StreamSubscription<List<HistoryEntry>>? _historySubscription;

  bool get isAuthenticated => ownerUser != null || staffSession != null;
  bool get isOwner => ownerUser != null;
  UserRole get role => isOwner ? UserRole.owner : UserRole.staff;
  String get displayName =>
      ownerUser?.email ?? staffSession?.displayName ?? 'Guest';

  PermissionSnapshot permissionSnapshot(PermissionService service) {
    // TODO: fetch and hydrate explicit permissions from user/company docs.
    return service.fromApp(app: this, explicitFlags: currentUserPermissions);
  }

  Future<void> bootstrap() async {
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
      // Staff auth is not driven by FirebaseAuth so we keep staffSession intact.
      if (ownerUser == null) {
        companies = [];
        activeCompany = null;
      } else {
        companies = await _firestoreService.fetchCompaniesForOwner(ownerUser!.uid);
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

  Future<void> registerOwner(String email, String password,
      {String? displayName}) async {
    final credential =
        await _authService.registerOwner(email: email, password: password);
    final user = credential.user;
    final name = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!.trim()
        : email;

    if (user != null) {
      await user.updateDisplayName(name);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': name,
        'email': email,
        'role': 'owner',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    // TODO: add better error handling and validation for registration inputs.
  }

  Future<void> signInOwner(String email, String password) async {
    await _authService.signInOwner(email: email, password: password);
    // Auth listener will populate companies and active company.
  }

  Future<void> signInStaff({
    required String companyCode,
    required String pin,
  }) async {
    // TODO: Replace this lookup with a Cloud Function + hashed PIN storage.
    staffSession = await _authService.signInStaff(
      companyCode: companyCode,
      pin: pin,
    );
    activeCompany ??= await _firestoreService.fetchCompanyByCode(companyCode) ??
        _sampleCompany(staffSession!.staffId);
    companies = activeCompany != null ? [activeCompany!] : [];
    final companyId = (staffSession?.companyId.isNotEmpty ?? false)
        ? staffSession!.companyId
        : activeCompany?.id ?? '';
    // Ensure Firestore security rules work for staff sessions.
    await FirebaseAuth.instance.signInAnonymously();
    currentStaff = await _fetchStaffMember(companyId, pin) ??
        StaffMember(
          id: staffSession?.staffId ?? 'staff',
          companyId: companyId,
          name: staffSession?.displayName ?? 'Staff',
          pin: pin,
          role: 'Worker',
        );
    await _attachCompanyStreams(companyId);
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authService.signOut();
    staffSession = null;
    currentStaff = null;
    ownerUser = null;
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
    await _attachCompanyStreams(company.id);
    notifyListeners();
  }

  Future<void> _attachCompanyStreams(String companyId) async {
    await _closeCompanyStreams();
    if (companyId.isEmpty) return;

    _productsSubscription =
        _firestoreService.productsStream(companyId).listen((data) {
      products = data;
      notifyListeners();
    }, onError: (_) {
      products = _sampleProducts(companyId);
      notifyListeners();
    });

    _ordersSubscription = _firestoreService.ordersStream(companyId).listen((data) {
      orders = data;
      notifyListeners();
    }, onError: (_) {
      orders = _sampleOrders(companyId);
      notifyListeners();
    });

    _historySubscription =
        _firestoreService.historyStream(companyId).listen((data) {
      history = data;
      notifyListeners();
    }, onError: (_) {
      history = _sampleHistory(companyId);
      notifyListeners();
    });
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

  Company _sampleCompany(String ownerId) {
    return Company(
      id: 'demo-company',
      name: 'Demo Bar',
      companyCode: 'DEMO-001',
      ownerIds: [ownerId],
      createdAt: DateTime.now(),
    );
  }

  Future<Company> createCompany({
    required String name,
    String? companyCode,
  }) async {
    if (ownerUser == null) {
      throw StateError('Only owners can create companies.');
    }
    final company = await _firestoreService.createCompany(
      name: name,
      ownerId: ownerUser!.uid,
      companyCode: companyCode,
    );
    companies = [...companies, company];
    await setActiveCompany(company);
    return company;
  }

  List<OrderModel> _sampleOrders(String companyId) {
    return [
      OrderModel(
        id: 'o1',
        companyId: companyId,
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

  Future<StaffMember?> _fetchStaffMember(String companyId, String pin) async {
    if (companyId.isEmpty) return null;
    try {
      final firestore = FirebaseFirestore.instance;
      final central = await firestore
          .collection('staff')
          .where('companyId', isEqualTo: companyId)
          .where('pin', isEqualTo: pin)
          .limit(1)
          .get();
      if (central.docs.isNotEmpty) {
        return StaffMember.fromFirestore(central.docs.first);
      }
      final sub = await firestore
          .collection('companies')
          .doc(companyId)
          .collection('staff')
          .where('pin', isEqualTo: pin)
          .limit(1)
          .get();
      if (sub.docs.isNotEmpty) {
        return StaffMember.fromFirestore(sub.docs.first);
      }
    } catch (_) {
      debugPrint('Staff lookup failed for $companyId');
    }
    return null;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _closeCompanyStreams();
    super.dispose();
  }
}
