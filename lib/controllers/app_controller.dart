import 'package:firebase_auth/firebase_auth.dart';

import '../models/staff_member.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/messaging_service.dart';
import '../services/permission_service.dart';
import '../state/app_state.dart';

/// AppController wraps the shared AppState and exposes semantic getters
/// requested for global access to auth/session data.
class AppController extends AppState {
  AppController()
      : super(
          authService: AuthService(),
          firestoreService: FirestoreService(),
          messagingService: MessagingService(),
        );

  final PermissionService permissions = const PermissionService();

  User? get currentUser => ownerUser;
  StaffMember? get currentStaffMember => currentStaff;
  PermissionSnapshot get currentPermissionSnapshot =>
      permissionSnapshot(permissions);
}
