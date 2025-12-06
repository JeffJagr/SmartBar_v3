part of 'generated.dart';

class ListAvailableProductsVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  ListAvailableProductsVariablesBuilder(this._dataConnect, );
  Deserializer<ListAvailableProductsData> dataDeserializer = (dynamic json)  => ListAvailableProductsData.fromJson(jsonDecode(json));
  
  Future<QueryResult<ListAvailableProductsData, void>> execute() {
    return ref().execute();
  }

  QueryRef<ListAvailableProductsData, void> ref() {
    
    return _dataConnect.query("ListAvailableProducts", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class ListAvailableProductsProducts {
  final String id;
  final String name;
  final String? description;
  final double? salePrice;
  ListAvailableProductsProducts.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']),
  name = nativeFromJson<String>(json['name']),
  description = json['description'] == null ? null : nativeFromJson<String>(json['description']),
  salePrice = json['salePrice'] == null ? null : nativeFromJson<double>(json['salePrice']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListAvailableProductsProducts otherTyped = other as ListAvailableProductsProducts;
    return id == otherTyped.id && 
    name == otherTyped.name && 
    description == otherTyped.description && 
    salePrice == otherTyped.salePrice;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, name.hashCode, description.hashCode, salePrice.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['name'] = nativeToJson<String>(name);
    if (description != null) {
      json['description'] = nativeToJson<String?>(description);
    }
    if (salePrice != null) {
      json['salePrice'] = nativeToJson<double?>(salePrice);
    }
    return json;
  }

  ListAvailableProductsProducts({
    required this.id,
    required this.name,
    this.description,
    this.salePrice,
  });
}

@immutable
class ListAvailableProductsData {
  final List<ListAvailableProductsProducts> products;
  ListAvailableProductsData.fromJson(dynamic json):
  
  products = (json['products'] as List<dynamic>)
        .map((e) => ListAvailableProductsProducts.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListAvailableProductsData otherTyped = other as ListAvailableProductsData;
    return products == otherTyped.products;
    
  }
  @override
  int get hashCode => products.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['products'] = products.map((e) => e.toJson()).toList();
    return json;
  }

  ListAvailableProductsData({
    required this.products,
  });
}

