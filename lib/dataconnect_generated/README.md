# dataconnect_generated SDK

## Installation
```sh
flutter pub get firebase_data_connect
flutterfire configure
```
For more information, see [Flutter for Firebase installation documentation](https://firebase.google.com/docs/data-connect/flutter-sdk#use-core).

## Data Connect instance
Each connector creates a static class, with an instance of the `DataConnect` class that can be used to connect to your Data Connect backend and call operations.

### Connecting to the emulator

```dart
String host = 'localhost'; // or your host name
int port = 9399; // or your port number
ExampleConnector.instance.dataConnect.useDataConnectEmulator(host, port);
```

You can also call queries and mutations by using the connector class.
## Queries

### ListAvailableProducts
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.listAvailableProducts().execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListAvailableProductsData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.listAvailableProducts();
ListAvailableProductsData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.listAvailableProducts().ref();
ref.execute();

ref.subscribe(...);
```


### ListOrdersForUser
#### Required Arguments
```dart
String creatorId = ...;
ExampleConnector.instance.listOrdersForUser(
  creatorId: creatorId,
).execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListOrdersForUserData, ListOrdersForUserVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.listOrdersForUser(
  creatorId: creatorId,
);
ListOrdersForUserData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String creatorId = ...;

final ref = ExampleConnector.instance.listOrdersForUser(
  creatorId: creatorId,
).ref();
ref.execute();

ref.subscribe(...);
```

## Mutations

### CreateNewOrder
#### Required Arguments
```dart
String creatorId = ...;
String orderType = ...;
String status = ...;
ExampleConnector.instance.createNewOrder(
  creatorId: creatorId,
  orderType: orderType,
  status: status,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<CreateNewOrderData, CreateNewOrderVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createNewOrder(
  creatorId: creatorId,
  orderType: orderType,
  status: status,
);
CreateNewOrderData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String creatorId = ...;
String orderType = ...;
String status = ...;

final ref = ExampleConnector.instance.createNewOrder(
  creatorId: creatorId,
  orderType: orderType,
  status: status,
).ref();
ref.execute();
```


### UpdateProductSalePrice
#### Required Arguments
```dart
String id = ...;
double salePrice = ...;
ExampleConnector.instance.updateProductSalePrice(
  id: id,
  salePrice: salePrice,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<UpdateProductSalePriceData, UpdateProductSalePriceVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.updateProductSalePrice(
  id: id,
  salePrice: salePrice,
);
UpdateProductSalePriceData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;
double salePrice = ...;

final ref = ExampleConnector.instance.updateProductSalePrice(
  id: id,
  salePrice: salePrice,
).ref();
ref.execute();
```

