part of 'generated.dart';

class UpdateProductSalePriceVariablesBuilder {
  String id;
  double salePrice;

  final FirebaseDataConnect _dataConnect;
  UpdateProductSalePriceVariablesBuilder(this._dataConnect, {required  this.id,required  this.salePrice,});
  Deserializer<UpdateProductSalePriceData> dataDeserializer = (dynamic json)  => UpdateProductSalePriceData.fromJson(jsonDecode(json));
  Serializer<UpdateProductSalePriceVariables> varsSerializer = (UpdateProductSalePriceVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<UpdateProductSalePriceData, UpdateProductSalePriceVariables>> execute() {
    return ref().execute();
  }

  MutationRef<UpdateProductSalePriceData, UpdateProductSalePriceVariables> ref() {
    UpdateProductSalePriceVariables vars= UpdateProductSalePriceVariables(id: id,salePrice: salePrice,);
    return _dataConnect.mutation("UpdateProductSalePrice", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class UpdateProductSalePriceProductUpdate {
  final String id;
  UpdateProductSalePriceProductUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateProductSalePriceProductUpdate otherTyped = other as UpdateProductSalePriceProductUpdate;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  UpdateProductSalePriceProductUpdate({
    required this.id,
  });
}

@immutable
class UpdateProductSalePriceData {
  final UpdateProductSalePriceProductUpdate? product_update;
  UpdateProductSalePriceData.fromJson(dynamic json):
  
  product_update = json['product_update'] == null ? null : UpdateProductSalePriceProductUpdate.fromJson(json['product_update']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateProductSalePriceData otherTyped = other as UpdateProductSalePriceData;
    return product_update == otherTyped.product_update;
    
  }
  @override
  int get hashCode => product_update.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (product_update != null) {
      json['product_update'] = product_update!.toJson();
    }
    return json;
  }

  UpdateProductSalePriceData({
    this.product_update,
  });
}

@immutable
class UpdateProductSalePriceVariables {
  final String id;
  final double salePrice;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  UpdateProductSalePriceVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']),
  salePrice = nativeFromJson<double>(json['salePrice']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateProductSalePriceVariables otherTyped = other as UpdateProductSalePriceVariables;
    return id == otherTyped.id && 
    salePrice == otherTyped.salePrice;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, salePrice.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['salePrice'] = nativeToJson<double>(salePrice);
    return json;
  }

  UpdateProductSalePriceVariables({
    required this.id,
    required this.salePrice,
  });
}

