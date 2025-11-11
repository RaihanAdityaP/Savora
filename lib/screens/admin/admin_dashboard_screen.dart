import 'package:flutter/material.dart';
import '../../utils/supabase_client.dart';
import 'admin_users_screen.dart';
import 'admin_activity_logs_screen.dart';
import 'admin_recipes_screen.dart';

// Mendefinisikan layar dashboard admin sebagai StatefulWidget
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

// State class untuk mengelola data dan tampilan dashboard admin
class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Menandai apakah sedang dalam proses memuat data
  bool _isLoading = true;
  // Menyimpan data statistik yang diambil dari database
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    // Memuat statistik saat widget pertama kali dibuat
    _loadStatistics();
  }

  // Fungsi untuk mengambil data statistik dari tabel 'admin_statistics' di Supabase
  Future<void> _loadStatistics() async {
    try {
      final response = await supabase
          .from('admin_statistics')
          .select()
          .single();

      // Memastikan widget masih terpasang sebelum memperbarui state
      if (mounted) {
        setState(() {
          _stats = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Jika terjadi error, hentikan loading dan tampilkan pesan error
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat statistik: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Warna latar belakang halaman
      backgroundColor: const Color(0xFFF8F4F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD4AF37),
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // Menampilkan indikator loading jika sedang memuat, atau konten jika sudah selesai
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              color: const Color(0xFFD4AF37),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner header di bagian atas
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFD4AF37), Color(0xFFF4E5C3)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              // Ikon admin
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.admin_panel_settings,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Pesan selamat datang
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Selamat Datang!',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Kelola platform Savora',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Judul untuk bagian statistik
                          const Text(
                            'Statistik Platform',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5C4033),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Grid statistik dengan 3 kolom per baris
                          GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 0.95,
                            children: [
                              _buildCompactStatCard(
                                'Users',
                                _stats['total_users']?.toString() ?? '0',
                                Icons.people,
                                const Color(0xFF4CAF50),
                              ),
                              _buildCompactStatCard(
                                'Banned',
                                _stats['banned_users']?.toString() ?? '0',
                                Icons.block,
                                const Color(0xFFF44336),
                              ),
                              _buildCompactStatCard(
                                'Pending',
                                _stats['pending_recipes']?.toString() ?? '0',
                                Icons.hourglass_empty,
                                const Color(0xFFFF9800),
                              ),
                              _buildCompactStatCard(
                                'Approved',
                                _stats['approved_recipes']?.toString() ?? '0',
                                Icons.check_circle,
                                const Color(0xFF2196F3),
                              ),
                              _buildCompactStatCard(
                                'Recipes',
                                _stats['total_recipes']?.toString() ?? '0',
                                Icons.restaurant_menu,
                                const Color(0xFF9C27B0),
                              ),
                              _buildCompactStatCard(
                                'Comments',
                                _stats['total_comments']?.toString() ?? '0',
                                Icons.comment,
                                const Color(0xFF00BCD4),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Judul untuk bagian menu manajemen
                          const Text(
                            'Menu Manajemen',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5C4033),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Kartu navigasi ke halaman pengelolaan pengguna
                          _buildMenuCard(
                            'Kelola Pengguna',
                            '${_stats['total_users'] ?? 0} pengguna terdaftar',
                            Icons.people_alt,
                            const Color(0xFF4CAF50),
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AdminUsersScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),

                          // Kartu navigasi ke halaman moderasi resep
                          _buildMenuCard(
                            'Moderasi Resep',
                            '${_stats['pending_recipes'] ?? 0} resep menunggu',
                            Icons.restaurant,
                            const Color(0xFFFF9800),
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AdminRecipesScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),

                          // Kartu navigasi ke halaman log aktivitas
                          _buildMenuCard(
                            'Log Aktivitas',
                            'Monitor semua aktivitas',
                            Icons.history,
                            const Color(0xFF2196F3),
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AdminActivityLogsScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Membangun kartu statistik kecil (compact) untuk ditampilkan dalam grid
  Widget _buildCompactStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ikon dengan background warna transparan
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(height: 6),
          // Nilai statistik
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          // Label deskriptif
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Membangun kartu menu navigasi dengan efek tap
  Widget _buildMenuCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Ikon dengan background berwarna
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                // Judul dan subjudul
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5C4033),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Ikon panah ke kanan
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade400,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}