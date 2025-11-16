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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context: context,
                index: 0,
                icon: Icons.home_rounded,
                label: 'Home',
              ),
              _buildNavItem(
                context: context,
                index: 1,
                icon: Icons.search_rounded,
                label: 'Search',
              ),
              _buildCenterButton(context),
              _buildNavItem(
                context: context,
                index: 3,
                icon: Icons.bookmark_rounded,
                label: 'Saved',
              ),
              _buildProfileButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isActive = currentIndex == index; // Menentukan apakah item ini aktif
    
    return GestureDetector(
      onTap: () => _navigateTo(context, index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 14 : 10, // Padding horizontal lebih besar jika aktif
          vertical: 8,
        ),
        decoration: BoxDecoration(
          gradient: isActive // Gunakan gradient jika aktif, null jika tidak
              ? LinearGradient(
                  colors: [Colors.orange.shade400, Colors.deepOrange.shade500],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.grey.shade600, // Warna ikon berubah jika aktif
              size: 22,
            ),
            if (isActive) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white, // Teks hanya muncul dan berwarna putih jika aktif
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCenterButton(BuildContext context) {
    // Di sini, kita tidak menggunakan isActive karena tombol tengah selalu memiliki tampilan yang sama
    // Jika Anda ingin menyesuaikan tampilan tombol tengah saat aktif, Anda bisa menambahkan logika serupa.
    // Misalnya, jika currentIndex == 2, maka tampilan tombol bisa berbeda.
    // Untuk saat ini, kita biarkan seperti sebelumnya karena tidak berubah.
    return GestureDetector(
      onTap: () => _navigateTo(context, 2),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient( // Tombol tengah selalu memiliki gradient
            colors: [Colors.orange.shade400, Colors.deepOrange.shade500],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.add_rounded,
          color: Colors.white, // Ikon selalu putih
          size: 28,
        ),
      ),
    );
  }

  Widget _buildProfileButton(BuildContext context) {
    final isActive = currentIndex == 4; // Menentukan apakah tombol profil ini aktif
    
    return GestureDetector(
      onTap: () => _navigateTo(context, 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isActive // Gunakan gradient jika aktif, null jika tidak
              ? LinearGradient(
                  colors: [Colors.orange.shade400, Colors.deepOrange.shade500],
                )
              : null,
        ),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.white : Colors.grey.shade200, // Warna latar belakang berubah jika aktif
            border: Border.all(
              color: isActive ? Colors.white : Colors.grey.shade300, // Warna border berubah jika aktif
              width: 2,
            ),
          ),
          child: ClipOval(
            child: avatarUrl != null
                ? Image.network(
                    avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.person,
                      color: isActive ? Colors.orange.shade600 : Colors.grey.shade600, // Warna ikon jika error berubah jika aktif
                      size: 20,
                    ),
                  )
                : Icon(
                    Icons.person,
                    color: isActive ? Colors.orange.shade600 : Colors.grey.shade600, // Warna ikon default berubah jika aktif
                    size: 20,
                  ),
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, int index) {
    if (index == currentIndex && index != 2) return; // Jangan navigasi jika sudah di halaman yang sama (kecuali tombol tengah)

    Widget destination;
    switch (index) {
      case 0:
        destination = const HomeScreen();
        break;
      case 1:
        destination = const SearchingScreen();
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateRecipeScreen()),
        ).then((_) {
          if (onRefresh != null) onRefresh!(); // Panggil onRefresh setelah kembali dari CreateRecipeScreen
        });
        return;
      case 3:
        destination = const FavoritesScreen();
        break;
      case 4:
        destination = const ProfileScreen();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.1);
          const end = Offset.zero;
          const curve = Curves.easeOut;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          var fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(animation);

          return SlideTransition(
            position: animation.drive(tween),
            child: FadeTransition(
              opacity: fadeAnimation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}