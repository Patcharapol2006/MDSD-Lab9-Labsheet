import 'package:flutter/material.dart';

import '../repositories/favorites_repository.dart';
import '../repositories/item_repository.dart';
import '../services/auth_service.dart';
import '../repositories/listing_draft_repository.dart';
import 'favorites_page.dart';
import 'home_page.dart';
import 'sell_item_page.dart';

class MainScaffold extends StatefulWidget {
  final List<ItemRepository> itemRepositories;
  final FavoritesRepository favoritesRepository;
  final ListingDraftRepository draftRepository;

  const MainScaffold({
    super.key,
    required this.itemRepositories,
    required this.favoritesRepository,
    required this.draftRepository,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  int _favoritesRefreshToken = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        repositories: widget.itemRepositories,
        favoritesRepository: widget.favoritesRepository,
        onSignOut: AuthService().signOut,
      ),
      SellItemPage(draftRepository: widget.draftRepository),
      FavoritesPage(
        repository: widget.favoritesRepository,
        refreshToken: _favoritesRefreshToken,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            if (index == 2) _favoritesRefreshToken++;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront),
            label: 'หน้าหลัก',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_a_photo),
            label: 'ลงประกาศขาย',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'รายการโปรด',
          ),
        ],
      ),
    );
  }
}
