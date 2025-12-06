part of 'generated.dart';

class CreateNewOrderVariablesBuilder {
  String creatorId;
  String orderType;
  String status;

  final FirebaseDataConnect _dataConnect;
  CreateNewOrderVariablesBuilder(this._dataConnect, {required  this.creatorId,required  this.orderType,required  this.status,});
  Deserializer<CreateNewOrderData> dataDeserializer = (dynamic json)  => CreateNewOrderData.fromJson(jsonDecode(json));
  Serializer<CreateNewOrderVariables> varsSerializer = (CreateNewOrderVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<CreateNewOrderData, CreateNewOrderVariables>> execute() {
    return ref().execute();
  }

  MutationRef<CreateNewOrderData, CreateNewOrderVariables> ref() {
    CreateNewOrderVariables vars= CreateNewOrderVariables(creatorId: creatorId,orderType: orderType,status: status,);
    return _dataConnect.mutation("CreateNewOrder", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class CreateNewOrderOrderInsert {
  final String id;
  CreateNewOrderOrderInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateNewOrderOrderInsert otherTyped = other as CreateNewOrderOrderInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  CreateNewOrderOrderInsert({
    required this.id,
  });
}

@immutable
class CreateNewOrderData {
  final CreateNewOrderOrderInsert order_insert;
  CreateNewOrderData.fromJson(dynamic json):
  
  order_insert = CreateNewOrderOrderInsert.fromJson(json['order_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateNewOrderData otherTyped = other as CreateNewOrderData;
    return order_insert == otherTyped.order_insert;
    
  }
  @override
  int get hashCode => order_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['order_insert'] = order_insert.toJson();
    return json;
  }

  CreateNewOrderData({
    required this.order_insert,
  });
}

@immutable
class CreateNewOrderVariables {
  final String creatorId;
  final String orderType;
  final String status;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  CreateNewOrderVariables.fromJson(Map<String, dynamic> json):
  
  creatorId = nativeFromJson<String>(json['creatorId']),
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

    final CreateNewOrderVariables otherTyped = other as CreateNewOrderVariables;
    return creatorId == otherTyped.creatorId && 
    orderType == otherTyped.orderType && 
    status == otherTyped.status;
    
  }
  @override
  int get hashCode => Object.hashAll([creatorId.hashCode, orderType.hashCode, status.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['creatorId'] = nativeToJson<String>(creatorId);
    json['orderType'] = nativeToJson<String>(orderType);
    json['status'] = nativeToJson<String>(status);
    return json;
  }

  CreateNewOrderVariables({
    required this.creatorId,
    required this.orderType,
    required this.status,
  });
}

