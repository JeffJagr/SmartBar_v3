library dataconnect_generated;
import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

part 'create_new_order.dart';

part 'list_available_products.dart';

part 'update_product_sale_price.dart';

part 'list_orders_for_user.dart';







class ExampleConnector {
  
  
  CreateNewOrderVariablesBuilder createNewOrder ({required String creatorId, required String orderType, required String status, }) {
    return CreateNewOrderVariablesBuilder(dataConnect, creatorId: creatorId,orderType: orderType,status: status,);
  }
  
  
  ListAvailableProductsVariablesBuilder listAvailableProducts () {
    return ListAvailableProductsVariablesBuilder(dataConnect, );
  }
  
  
  UpdateProductSalePriceVariablesBuilder updateProductSalePrice ({required String id, required double salePrice, }) {
    return UpdateProductSalePriceVariablesBuilder(dataConnect, id: id,salePrice: salePrice,);
  }
  
  
  ListOrdersForUserVariablesBuilder listOrdersForUser ({required String creatorId, }) {
    return ListOrdersForUserVariablesBuilder(dataConnect, creatorId: creatorId,);
  }
  

  static ConnectorConfig connectorConfig = ConnectorConfig(
    'us-east4',
    'example',
    'smartbarappv3',
  );

  ExampleConnector({required this.dataConnect});
  static ExampleConnector get instance {
    return ExampleConnector(
        dataConnect: FirebaseDataConnect.instanceFor(
            connectorConfig: connectorConfig,
            sdkType: CallerSDKType.generated));
  }

  FirebaseDataConnect dataConnect;
}
