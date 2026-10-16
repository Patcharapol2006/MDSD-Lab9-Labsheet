import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart_model.dart';
import '../models/item.dart';
import '../repositories/favorites_repository.dart';
import '../repositories/item_repository.dart';
import 'checkout_page.dart';

class HomePage extends StatefulWidget {
  final ItemRepository? repository;
  final List<ItemRepository>? repositories;
  final FavoritesRepository favoritesRepository;
  final Future<void> Function()? onSignOut;

  const HomePage({
    super.key,
    this.repository,
    this.repositories,
    required this.favoritesRepository,
    this.onSignOut,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Item>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _loadItems();
  }

  Future<List<Item>> _loadItems() async {
    final sources = widget.repositories ?? [if (widget.repository != null) widget.repository!];
    final groups = await Future.wait(sources.map((source) => source.getItems()));
    return groups.expand((items) => items).toList();
  }

  void _retry() {
    setState(() {
      _itemsFuture = _loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Marketplace'),
        actions: [
          if (widget.onSignOut != null)
            IconButton(tooltip: 'ออกจากระบบ', icon: const Icon(Icons.logout), onPressed: widget.onSignOut),
          IconButton(
            tooltip: 'ตะกร้าสินค้า',
            icon: Badge(
              label: Text('${context.watch<CartModel>().itemCount}'),
              child: const Icon(Icons.shopping_cart),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CheckoutPage()),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Item>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'เกิดข้อผิดพลาด: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('ลองใหม่'),
                    ),
                  ],
                ),
              ),
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('ไม่พบสินค้า'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: item.imageUrl.startsWith('assets/')
                    ? Image.asset(
                        item.imageUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      )
                    : item.imageUrl.isEmpty
                    ? const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.inventory_2_outlined),
                      )
                    : item.imageUrl.startsWith('http://') ||
                          item.imageUrl.startsWith('https://')
                    ? Image.network(
                        item.imageUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image),
                      )
                    : Image.file(
                        File(item.imageUrl),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image),
                      ),
                title: Row(children: [Expanded(child: Text(item.title)), if (item.sellerId != null) const Chip(label: Text('🎓 ประกาศจริง')) else const Chip(label: Text('🏪 API'))]),
                subtitle: Text('${item.price.toStringAsFixed(2)} บาท'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'เพิ่มในรายการโปรด',
                      icon: const Icon(Icons.favorite_border),
                      onPressed: () async {
                        try {
                          await widget.favoritesRepository.addFavorite(
                            item.id,
                            item.title,
                            item.price,
                            item.imageUrl,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'เพิ่ม "${item.title}" ในรายการโปรดแล้ว',
                              ),
                            ),
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('เพิ่มรายการโปรดไม่สำเร็จ: $error'),
                            ),
                          );
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'เพิ่มลงตะกร้า',
                      icon: const Icon(Icons.add_shopping_cart),
                      onPressed: () {
                        context.read<CartModel>().add(item);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('เพิ่ม "${item.title}" ลงตะกร้าแล้ว'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
