import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item.dart';
import 'item_repository.dart';

class ItemRepositoryFirestore implements ItemRepository {
  final CollectionReference<Map<String, dynamic>> _items;

  ItemRepositoryFirestore({FirebaseFirestore? firestore})
      : _items = (firestore ?? FirebaseFirestore.instance).collection('items');

  @override
  Future<List<Item>> getItems() async {
    final snapshot = await _items.get();
    return snapshot.docs
        .map(Item.fromFirestore)
        .toList();
  }

  Future<void> postItem(Item item) async {
    await _items.add(item.toFirestore());
  }

  Stream<List<Item>> watchMyListings(String sellerId) => _items
      .where('sellerId', isEqualTo: sellerId)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map(Item.fromFirestore)
          .toList());
}
