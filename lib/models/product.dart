import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  const Product({
    required this.id,
    required this.companyId,
    required this.name,
    required this.group,
    this.groupId,
    this.groupColor,
    this.groupMetadata,
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
    this.trackVolume = false,
    this.unitVolumeMl,
    this.minVolumeThresholdMl,
    this.trackWarehouse = true,
    this.barVolumeMl,
    this.warehouseVolumeMl,
    this.supplierId,
    this.supplierName,
  });

  final String id;
  final String companyId;
  final String name;
  final String group;
  /// Optional reference to a Group entity for structured grouping.
  final String? groupId;
  /// Optional color tag pulled from the Group entity (e.g., hex value).
  final String? groupColor;
  /// Optional metadata map coming from a Group entity.
  final Map<String, dynamic>? groupMetadata;
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
  final bool trackVolume;
  final int? unitVolumeMl;
  final int? minVolumeThresholdMl;
  final bool trackWarehouse;
  final int? barVolumeMl;
  final int? warehouseVolumeMl;
  final String? supplierId;
  final String? supplierName;

  factory Product.empty() => const Product(
        id: '',
        companyId: '',
        name: '',
        group: '',
        unit: '',
        barQuantity: 0,
        barMax: 0,
        warehouseQuantity: 0,
        warehouseTarget: 0,
      );

  bool get isBarLow => barQuantity < barMax;
  bool get isWarehouseLow => warehouseQuantity < warehouseTarget;
  double get barFillPercent =>
      barMax == 0 ? 0 : (barQuantity.clamp(0, barMax) / barMax);
  double get warehouseFillPercent =>
      warehouseTarget == 0 ? 0 : (warehouseQuantity.clamp(0, warehouseTarget) / warehouseTarget);

  Product copyWith({
    String? groupId,
    String? groupColor,
    Map<String, dynamic>? groupMetadata,
    String? group,
    int? barQuantity,
    int? barMax,
    int? warehouseQuantity,
    int? warehouseTarget,
    double? salePrice,
    int? restockHint,
    bool? flagNeedsRestock,
    int? minimalStockThreshold,
    bool? trackVolume,
    int? unitVolumeMl,
    int? minVolumeThresholdMl,
    bool? trackWarehouse,
    int? barVolumeMl,
    int? warehouseVolumeMl,
    String? supplierId,
    String? supplierName,
  }) {
    return Product(
      id: id,
      companyId: companyId,
      name: name,
      group: group ?? this.group,
      groupId: groupId ?? this.groupId,
      groupColor: groupColor ?? this.groupColor,
      groupMetadata: groupMetadata ?? this.groupMetadata,
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
      trackVolume: trackVolume ?? this.trackVolume,
      unitVolumeMl: unitVolumeMl ?? this.unitVolumeMl,
      minVolumeThresholdMl: minVolumeThresholdMl ?? this.minVolumeThresholdMl,
      trackWarehouse: trackWarehouse ?? this.trackWarehouse,
      barVolumeMl: barVolumeMl ?? this.barVolumeMl,
      warehouseVolumeMl: warehouseVolumeMl ?? this.warehouseVolumeMl,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
    );
  }

  factory Product.fromMap(String id, Map<String, dynamic> data) {
    return Product(
      id: id,
      companyId: data['companyId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      group: data['group'] as String? ?? '',
      groupId: data['groupId'] as String?,
      groupColor: data['groupColor'] as String?,
      groupMetadata: (data['groupMetadata'] as Map<String, dynamic>?) ??
          (data['groupMeta'] as Map<String, dynamic>?), // backward compatibility key
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
      trackVolume: data['trackVolume'] as bool? ?? false,
      unitVolumeMl: (data['unitVolumeMl'] as num?)?.toInt(),
      minVolumeThresholdMl: (data['minVolumeThresholdMl'] as num?)?.toInt(),
      trackWarehouse: data['trackWarehouse'] as bool? ?? true,
      barVolumeMl: (data['barVolumeMl'] as num?)?.toInt(),
      warehouseVolumeMl: (data['warehouseVolumeMl'] as num?)?.toInt(),
      supplierId: data['supplierId'] as String?,
      supplierName: data['supplierName'] as String?,
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
      if (groupId != null) 'groupId': groupId,
      if (groupColor != null) 'groupColor': groupColor,
      if (groupMetadata != null) 'groupMetadata': groupMetadata,
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
      'trackVolume': trackVolume,
      if (unitVolumeMl != null) 'unitVolumeMl': unitVolumeMl,
      if (minVolumeThresholdMl != null) 'minVolumeThresholdMl': minVolumeThresholdMl,
      'trackWarehouse': trackWarehouse,
      if (barVolumeMl != null) 'barVolumeMl': barVolumeMl,
      if (warehouseVolumeMl != null) 'warehouseVolumeMl': warehouseVolumeMl,
      if (supplierId != null) 'supplierId': supplierId,
      if (supplierName != null) 'supplierName': supplierName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
