/// Lightweight grouping entity for inventory items.
class Group {
  const Group({
    required this.id,
    required this.companyId,
    required this.name,
    this.color, // e.g., hex string for UI tag
    this.metadata,
  });

  final String id;
  final String companyId;
  final String name;
  final String? color;
  final Map<String, dynamic>? metadata;

  factory Group.fromMap(String id, Map<String, dynamic> data) {
    return Group(
      id: id,
      companyId: data['companyId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      color: data['color'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'name': name,
      if (color != null) 'color': color,
      if (metadata != null) 'metadata': metadata,
    };
  }
}
