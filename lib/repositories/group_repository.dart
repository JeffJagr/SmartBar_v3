import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Simple group metadata: name/color and list of itemIds.
class GroupMeta {
  GroupMeta({
    required this.id,
    required this.name,
    this.color,
    this.itemIds = const [],
  });

  final String id;
  final String name;
  final String? color;
  final List<String> itemIds;

  GroupMeta copyWith({
    String? name,
    String? color,
    List<String>? itemIds,
  }) {
    return GroupMeta(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      itemIds: itemIds ?? this.itemIds,
    );
  }
}

abstract class GroupRepository {
  Future<List<GroupMeta>> listGroups();
  Future<void> upsertGroup({
    required String id,
    required String name,
    String? color,
    List<String>? itemIds,
  });

  Future<void> removeItemsFromGroup(List<String> itemIds);

  Future<void> deleteGroup(String id);
}

class InMemoryGroupRepository implements GroupRepository {
  final Map<String, GroupMeta> _groups = {};
  final _controller = StreamController<List<GroupMeta>>.broadcast();

  @override
  Future<List<GroupMeta>> listGroups() async => _groups.values.toList();

  @override
  Future<void> upsertGroup({
    required String id,
    required String name,
    String? color,
    List<String>? itemIds,
  }) async {
    final existing = _groups[id];
    final mergedIds = <String>{
      if (existing != null) ...existing.itemIds,
      if (itemIds != null) ...itemIds,
    }.toList();
    _groups[id] = GroupMeta(
      id: id,
      name: name,
      color: color ?? existing?.color,
      itemIds: mergedIds,
    );
    _controller.add(_groups.values.toList());
  }

  @override
  Future<void> removeItemsFromGroup(List<String> itemIds) async {
    if (itemIds.isEmpty) return;
    _groups.updateAll((key, value) {
      final remaining = value.itemIds.where((id) => !itemIds.contains(id)).toList();
      return GroupMeta(id: value.id, name: value.name, color: value.color, itemIds: remaining);
    });
    _controller.add(_groups.values.toList());
  }

  @override
  Future<void> deleteGroup(String id) async {
    _groups.remove(id);
    _controller.add(_groups.values.toList());
  }
}

class FirestoreGroupRepository implements GroupRepository {
  FirestoreGroupRepository({
    required this.companyId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String companyId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('companies').doc(companyId).collection('groups');

  @override
  Future<List<GroupMeta>> listGroups() async {
    final snap = await _col.orderBy('name').get();
    return snap.docs
        .map((d) => GroupMeta(
              id: d.id,
              name: d.data()['name'] as String? ?? '',
              color: d.data()['color'] as String?,
              itemIds: (d.data()['itemIds'] as List<dynamic>? ?? []).cast<String>(),
            ))
        .toList();
  }

  @override
  Future<void> upsertGroup({
    required String id,
    required String name,
    String? color,
    List<String>? itemIds,
  }) async {
    final doc = _col.doc(id);
    await doc.set(
      {
        'name': name,
        if (color != null) 'color': color,
        if (itemIds != null) 'itemIds': itemIds,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> removeItemsFromGroup(List<String> itemIds) async {
    if (itemIds.isEmpty) return;
    final snap = await _col.get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      final existing = (doc.data()['itemIds'] as List<dynamic>? ?? []).cast<String>();
      final remaining = existing.where((id) => !itemIds.contains(id)).toList();
      batch.update(doc.reference, {'itemIds': remaining});
    }
    await batch.commit();
  }

  @override
  Future<void> deleteGroup(String id) async {
    await _col.doc(id).delete();
  }
}
