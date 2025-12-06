part of 'generated.dart';

class ListOrdersForUserVariablesBuilder {
  String creatorId;

  final FirebaseDataConnect _dataConnect;
  ListOrdersForUserVariablesBuilder(this._dataConnect, {required  this.creatorId,});
  Deserializer<ListOrdersForUserData> dataDeserializer = (dynamic json)  => ListOrdersForUserData.fromJson(jsonDecode(json));
  Serializer<ListOrdersForUserVariables> varsSerializer = (ListOrdersForUserVariables vars) => jsonEncode(vars.toJson());
  Future<QueryResult<ListOrdersForUserData, ListOrdersForUserVariables>> execute() {
    return ref().execute();
  }

  QueryRef<ListOrdersForUserData, ListOrdersForUserVariables> ref() {
    ListOrdersForUserVariables vars= ListOrdersForUserVariables(creatorId: creatorId,);
    return _dataConnect.query("ListOrdersForUser", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class ListOrdersForUserOrders {
  final String id;
  final Timestamp orderDate;
  final String orderType;
  final String status;
  ListOrdersForUserOrders.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']),
  orderDate = Timestamp.fromJson(json['orderDate']),
  orderType = nativeFromJson<String>(json['orderType']),
  status = nativeFromJson<String>(json['status']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListOrdersForUserOrders otherTyped = other as ListOrdersForUserOrders;
    return id == otherTyped.id && 
    orderDate == otherTyped.orderDate && 
    orderType == otherTyped.orderType && 
    status == otherTyped.status;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, orderDate.hashCode, orderType.hashCode, status.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['orderDate'] = orderDate.toJson();
    json['orderType'] = nativeToJson<String>(orderType);
    json['status'] = nativeToJson<String>(status);
    return json;
  }

  ListOrdersForUserOrders({
    required this.id,
    required this.orderDate,
    required this.orderType,
    required this.status,
  });
}

@immutable
class ListOrdersForUserData {
  final List<ListOrdersForUserOrders> orders;
  ListOrdersForUserData.fromJson(dynamic json):
  
  orders = (json['orders'] as List<dynamic>)
        .map((e) => ListOrdersForUserOrders.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListOrdersForUserData otherTyped = other as ListOrdersForUserData;
    return orders == otherTyped.orders;
    
  }
  @override
  int get hashCode => orders.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['orders'] = orders.map((e) => e.toJson()).toList();
    return json;
  }

  ListOrdersForUserData({
    required this.orders,
  });
}

@immutable
class ListOrdersForUserVariables {
  final String creatorId;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  ListOrdersForUserVariables.fromJson(Map<String, dynamic> json):
  
  creatorId = nativeFromJson<String>(json['creatorId']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListOrdersForUserVariables otherTyped = other as ListOrdersForUserVariables;
    return creatorId == otherTyped.creatorId;
    
  }
  @override
  int get hashCode => creatorId.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['creatorId'] = nativeToJson<String>(creatorId);
    return json;
  }

  ListOrdersForUserVariables({
    required this.creatorId,
  });
}

