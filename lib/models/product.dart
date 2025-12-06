import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  const Product({
    required this.id,
    required this.companyId,
    required this.name,
    required this.group,
    this.subgroup,
    required this.unit,
    required this.barQuantity,
    required this.barMax,
    required this.warehouseQuantity,
    required this.warehouseTarget,
    this.salePrice,
    this.restockHint,
    this.flagNeedsRestock,
    this.minimalStockThreshold,
  });

  final String id;
  final String companyId;
  final String name;
  final String group;
  final String? subgroup;
  final String unit;
  final int barQuantity;
  final int barMax;
  final int warehouseQuantity;
  final int warehouseTarget;
  final double? salePrice;
  final int? restockHint;
  final bool? flagNeedsRestock;
  final int? minimalStockThreshold;

  bool get isBarLow => barQuantity < barMax;
  bool get isWarehouseLow => warehouseQuantity < warehouseTarget;
  double get barFillPercent =>
      barMax == 0 ? 0 : (barQuantity.clamp(0, barMax) / barMax);
  double get warehouseFillPercent =>
      warehouseTarget == 0 ? 0 : (warehouseQuantity.clamp(0, warehouseTarget) / warehouseTarget);

  Product copyWith({
    int? barQuantity,
    int? barMax,
    int? warehouseQuantity,
    int? warehouseTarget,
    double? salePrice,
    int? restockHint,
    bool? flagNeedsRestock,
    int? minimalStockThreshold,
  }) {
    return Product(
      id: id,
      companyId: companyId,
      name: name,
      group: group,
      subgroup: subgroup,
      unit: unit,
      barQuantity: barQuantity ?? this.barQuantity,
      barMax: barMax ?? this.barMax,
      warehouseQuantity: warehouseQuantity ?? this.warehouseQuantity,
      warehouseTarget: warehouseTarget ?? this.warehouseTarget,
      salePrice: salePrice ?? this.salePrice,
      restockHint: restockHint ?? this.restockHint,
      flagNeedsRestock: flagNeedsRestock ?? this.flagNeedsRestock,
      minimalStockThreshold: minimalStockThreshold ?? this.minimalStockThreshold,
    );
  }

  factory Product.fromMap(String id, Map<String, dynamic> data) {
    return Product(
      id: id,
      companyId: data['companyId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      group: data['group'] as String? ?? '',
      subgroup: data['subgroup'] as String?,
      unit: data['unit'] as String? ?? 'pcs',
      barQuantity: (data['barQuantity'] as num?)?.toInt() ??
          (data['frontStock'] as num?)?.toInt() ??
          0,
      barMax: (data['barMax'] as num?)?.toInt() ?? 0,
      warehouseQuantity: (data['warehouseQuantity'] as num?)?.toInt() ??
          (data['backStock'] as num?)?.toInt() ??
          0,
      warehouseTarget: (data['warehouseTarget'] as num?)?.toInt() ?? 0,
      salePrice: (data['salePrice'] as num?)?.toDouble(),
      restockHint: (data['restockHint'] as num?)?.toInt(),
      flagNeedsRestock: data['flagNeedsRestock'] as bool?,
      minimalStockThreshold: (data['minimalStockThreshold'] as num?)?.toInt(),
    );
  }

  factory Product.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Product.fromMap(doc.id, doc.data() ?? {});
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'name': name,
      'group': group,
      'subgroup': subgroup,
      'unit': unit,
      'barQuantity': barQuantity,
      'barMax': barMax,
      'warehouseQuantity': warehouseQuantity,
      'warehouseTarget': warehouseTarget,
      if (salePrice != null) 'salePrice': salePrice,
      if (restockHint != null) 'restockHint': restockHint,
      if (flagNeedsRestock != null) 'flagNeedsRestock': flagNeedsRestock,
      if (minimalStockThreshold != null) 'minimalStockThreshold': minimalStockThreshold,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
