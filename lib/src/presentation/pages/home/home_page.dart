// lib/src/presentation/pages/home/home_page.dart
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'OZN',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF27AE60)),
        ),
        actions: [IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {})],
      ),
      body: _buildCurrentPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Rechercher'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Créer'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_outlined), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () {},
              backgroundColor: const Color(0xFF27AE60),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return _buildSearchContent();
      case 2:
        return _buildCreateContent();
      case 3:
        return _buildMessagesContent();
      case 4:
        return _buildProfileContent();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher un supermarché...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
            ),
          ),
        ),

        // Tabs
        DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                tabs: const [
                  Tab(text: 'Carte'),
                  Tab(text: 'Liste'),
                ],
                onTap: (index) {},
              ),
              SizedBox(
                height: 400,
                child: TabBarView(
                  children: [
                    // Vue Carte (simplifiée)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.map, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('Carte des courses', style: TextStyle(fontSize: 18)),
                          const SizedBox(height: 8),
                          Text('3 conducteurs à proximité', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ),

                    // Vue Liste
                    ListView.builder(itemCount: 3, itemBuilder: (context, index) => _buildTripCard(index)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTripCard(int index) {
    final drivers = ['Marie D.', 'Pierre L.', 'Sophie M.'];
    final prices = ['3,50€', '2,80€', '2,20€'];
    final distances = ['0,8km', '0,5km', '0,3km'];

    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF27AE60),
          child: Icon(Icons.person, color: Colors.white),
        ),
        title: Text(drivers[index]),
        subtitle: Text('Super U • ${distances[index]}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              prices[index],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF27AE60)),
            ),
            const Text('Réserver', style: TextStyle(fontSize: 12)),
          ],
        ),
        onTap: () {},
      ),
    );
  }

  Widget _buildSearchContent() {
    return const Center(child: Text('Recherche - À implémenter'));
  }

  Widget _buildCreateContent() {
    return const Center(child: Text('Créer une course - À implémenter'));
  }

  Widget _buildMessagesContent() {
    return const Center(child: Text('Messages - À implémenter'));
  }

  Widget _buildProfileContent() {
    return const Center(child: Text('Profil - À implémenter'));
  }
}
