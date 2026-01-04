class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    this.contactEmail,
    this.contactPhone,
    this.leadTimeDays,
    this.notes,
  });

  final String id;
  final String name;
  final String? contactEmail;
  final String? contactPhone;
  final int? leadTimeDays;
  final String? notes;

  factory Supplier.fromMap(String id, Map<String, dynamic> data) {
    return Supplier(
      id: id,
      name: data['name'] as String? ?? '',
      contactEmail: data['contactEmail'] as String?,
      contactPhone: data['contactPhone'] as String?,
      leadTimeDays: (data['leadTimeDays'] as num?)?.toInt(),
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (contactEmail != null) 'contactEmail': contactEmail,
      if (contactPhone != null) 'contactPhone': contactPhone,
      if (leadTimeDays != null) 'leadTimeDays': leadTimeDays,
      if (notes != null) 'notes': notes,
    };
  }
}

