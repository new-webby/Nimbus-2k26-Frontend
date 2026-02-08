import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'core_club_card.dart';

class CoreClubsPage extends StatefulWidget {
  const CoreClubsPage({super.key});

  @override
  State<CoreClubsPage> createState() => _CoreClubsPageState();
}

class _CoreClubsPageState extends State<CoreClubsPage> {
  late TextEditingController _searchController;
  String _searchQuery = '';
  String? _activeCoreTitle;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Core Clubs',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            if (_activeCoreTitle == null)
              Column(
                children: [
                  _searchBar(),
                  const SizedBox(height: 16),
                  Expanded(child: _clubList()),
                ],
              ),
            if (_activeCoreTitle != null) _buildCoreOverlay(),
          ],
        ),
      ),
    );
  }

  /// 🔍 Search Bar
  Widget _searchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search core clubs',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: const Color(0xFFF4F6FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// 📋 Club List
  List<Map<String, String>> _getAllClubs() {
    return [
      {
        'title': 'Team Public Relation',
        'description':
            'Handles outreach, communication, branding, and public engagement for all Nimbus events.',
        'imagePath': 'assets/clubs/PR.jpg',
      },
      {
        'title': 'App Team',
        'description':
            'Develops and maintains the Hillfair and Nimbus app, organizes HackOnHills .',
        'imagePath': 'assets/clubs/AppTeam.jpg',
      },
      {
        'title': 'Pixonoids',
        'description':
            'For people with passion for photography, videography, and creative visual content.',
        'imagePath': 'assets/clubs/Pixonoids.jpg',
      },
      {
        'title': 'Resurgance',
        'description':
            'Dedicated to gaming, esports, and interactive entertainment experiences.',
        'imagePath': 'assets/clubs/Resurgance.jpg',
      },
      {
        'title': 'Team Finance and Treasury',
        'description':
            'Manages budgeting, finances, and sponsorships for all Nimbus events.',
        'imagePath': 'assets/clubs/TFT.jpg',
      },
      {
        'title': 'Design And Deco',
        'description':
            'Creates props, decorations, and handles all the technical setup for Nimbus events.',
        'imagePath': 'assets/clubs/DesignNDeco.jpg',
      },
    ];
  }

  List<Map<String, String>> _getFilteredClubs() {
    final allClubs = _getAllClubs();
    if (_searchQuery.isEmpty) {
      return allClubs;
    }
    return allClubs
        .where((club) =>
            club['title']!.toLowerCase().contains(_searchQuery) ||
            club['description']!.toLowerCase().contains(_searchQuery))
        .toList();
  }

  /// 📋 Club List
  Widget _clubList() {
    final filteredClubs = _getFilteredClubs();

    if (filteredClubs.isEmpty) {
      return Center(
        child: Text(
          'No clubs found',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView(
      children: filteredClubs
          .map((club) => CoreClubCard(
                title: club['title']!,
                description: club['description']!,
                imagePath: club['imagePath']!,
                onTap: () => setState(() => _activeCoreTitle = club['title']),
                expanded: _activeCoreTitle == club['title'],
              ))
          .toList(),
    );
  }

  Map<String, String>? _findCoreClub(String title) {
    try {
      return _getAllClubs().firstWhere((c) => c['title'] == title);
    } catch (_) {
      return null;
    }
  }

  Widget _buildCoreOverlay() {
    if (_activeCoreTitle == null) return const SizedBox.shrink();
    final club = _findCoreClub(_activeCoreTitle!);
    if (club == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _activeCoreTitle = null),
        child: Container(
          color: Colors.transparent,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: GestureDetector(
            onTap: () {},
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              constraints: BoxConstraints(maxWidth: 800),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: AssetImage(club['imagePath']!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              club['title']!,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _activeCoreTitle = null),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    club['description']!,
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// CoreClubCard is now provided by lib/core_club_card.dart
