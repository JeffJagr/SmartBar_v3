class StaffSession {
  const StaffSession({
    required this.companyId,
    required this.displayName,
    required this.staffId,
    this.role = 'staff',
    this.permissions = const {},
  });

  final String companyId;
  final String displayName;
  final String staffId;
  final String role;
  final Map<String, dynamic> permissions;
}
