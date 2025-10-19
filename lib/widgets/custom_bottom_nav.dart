import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/searching_screen.dart';
import '../screens/create_recipe_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/profile_screen.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final String? avatarUrl;
  final VoidCallback? onRefresh;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    this.avatarUrl,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        // Jangan navigate jika sudah di halaman yang sama
        if (index == currentIndex) return;

        switch (index) {
          case 0:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
            break;
          case 1:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SearchingScreen()),
            );
            break;
          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateRecipeScreen()),
            ).then((_) {
              if (onRefresh != null) onRefresh!();
            });
            break;
          case 3:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            );
            break;
          case 4:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
            break;
        }
      },
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: 'Search',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.add_circle),
          label: 'Create',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.bookmark_border),
          label: 'Favorites',
        ),
        BottomNavigationBarItem(
          icon: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade300,
              border: Border.all(color: Colors.grey.shade400, width: 1.5),
            ),
            child: ClipOval(
              child: avatarUrl != null
                  ? Image.network(
                      avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.person,
                        color: Colors.grey.shade600,
                        size: 16,
                      ),
                    )
                  : Icon(Icons.person, color: Colors.grey.shade600, size: 16),
            ),
          ),
          label: 'Profile',
        ),
      ],
      selectedItemColor: const Color(0xFFE89A6F),
      unselectedItemColor: const Color(0xFF8BC34A),
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      elevation: 8,
      showSelectedLabels: false,
      showUnselectedLabels: false,
    );
  }
}