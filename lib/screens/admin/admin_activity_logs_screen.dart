import 'package:flutter/material.dart';
import '../../utils/supabase_client.dart';
import 'package:intl/intl.dart';

// Mendefinisikan layar halaman Log Aktivitas Admin sebagai StatefulWidget
class AdminActivityLogsScreen extends StatefulWidget {
  const AdminActivityLogsScreen({super.key});

  @override
  State<AdminActivityLogsScreen> createState() => _AdminActivityLogsScreenState();
}

// State class untuk mengelola data dan logika halaman ini
class _AdminActivityLogsScreenState extends State<AdminActivityLogsScreen> {
  // Menyimpan semua log aktivitas yang diambil dari database
  List<Map<String, dynamic>> _logs = [];
  // Menyimpan log yang telah difilter berdasarkan tindakan (action)
  List<Map<String, dynamic>> _filteredLogs = [];
  // Menandai apakah sedang dalam proses memuat data
  bool _isLoading = true;
  // Menyimpan jenis filter action yang sedang dipilih oleh pengguna
  String _filterAction = 'all';
  // Controller untuk mengelola scrolling pada daftar log
  final ScrollController _scrollController = ScrollController();
  // Menyimpan halaman saat ini untuk pagination
  int _currentPage = 0;
  // Jumlah item yang dimuat per halaman
  final int _pageSize = 20;
  // Menandai apakah masih ada data tambahan untuk dimuat
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    // Memuat log pertama kali saat widget dibuat
    _loadLogs();
    // Menambahkan listener untuk mendeteksi scroll dan memuat lebih banyak data
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    // Membersihkan listener scroll dan resource saat widget dihancurkan
    _scrollController.dispose();
    super.dispose();
  }

  // Fungsi yang dipanggil saat pengguna melakukan scroll
  void _onScroll() {
    // Memeriksa apakah pengguna sudah mencapai akhir daftar (90% ke bawah)
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      // Jika tidak sedang memuat dan masih ada data, maka muat data tambahan
      if (!_isLoading && _hasMore) {
        _loadMoreLogs();
      }
    }
  }

  // Fungsi untuk memuat ulang semua log dari awal
  Future<void> _loadLogs() async {
    // Menandai sedang loading dan reset halaman ke 0
    setState(() {
      _isLoading = true;
      _currentPage = 0;
    });

    try {
      // Mengambil data dari tabel 'activity_logs' di Supabase
      // Mengambil juga username dari tabel 'profiles' melalui relasi user_id
      final response = await supabase
          .from('activity_logs')
          .select('*, profiles:user_id(username)')
          .order('created_at', ascending: false)
          .range(_currentPage * _pageSize, (_currentPage + 1) * _pageSize - 1);

      // Memastikan widget masih terpasang sebelum mengubah state
      if (mounted) {
        setState(() {
          // Mengonversi respons menjadi daftar log
          _logs = List<Map<String, dynamic>>.from(response);
          // Menentukan apakah masih ada data berikutnya berdasarkan ukuran respons
          _hasMore = response.length == _pageSize;
          // Menerapkan filter berdasarkan action yang dipilih
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      // Menangani error saat memuat data
      if (mounted) {
        setState(() => _isLoading = false);
        // Menampilkan pesan error menggunakan SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat log: $e')),
        );
      }
    }
  }

  // Fungsi untuk memuat log tambahan saat scroll ke bawah
  Future<void> _loadMoreLogs() async {
    // Menambah halaman saat ini
    setState(() => _currentPage++);

    try {
      // Mengambil data log untuk halaman berikutnya
      // Menggunakan relasi inner join untuk memastikan hanya log dengan profil yang valid
      final response = await supabase
          .from('activity_logs')
          .select('*, profiles!inner(username)')
          .order('created_at', ascending: false)
          .range(_currentPage * _pageSize, (_currentPage + 1) * _pageSize - 1);

      if (mounted) {
        setState(() {
          // Menambahkan log baru ke daftar yang sudah ada
          _logs.addAll(List<Map<String, dynamic>>.from(response));
          // Memperbarui status apakah masih ada data
          _hasMore = response.length == _pageSize;
          // Menerapkan ulang filter
          _applyFilters();
        });
      }
    } catch (e) {
      // Jika gagal, kembalikan nomor halaman sebelumnya
      if (mounted) {
        setState(() => _currentPage--);
      }
    }
  }

  // Fungsi untuk memfilter log berdasarkan tindakan yang dipilih
  void _applyFilters() {
    setState(() {
      if (_filterAction == 'all') {
        // Jika filter 'all', tampilkan semua log
        _filteredLogs = _logs;
      } else {
        // Jika tidak, hanya tampilkan log dengan action yang sesuai
        _filteredLogs = _logs.where((log) => log['action'] == _filterAction).toList();
      }
    });
  }

  // Fungsi untuk mengonversi kode action menjadi teks yang mudah dibaca
  String _getActionDisplay(String action) {
    switch (action) {
      case 'ban_user':
        return 'Ban Pengguna';
      case 'unban_user':
        return 'Aktifkan Pengguna';
      case 'moderate_recipe':
        return 'Moderasi Resep';
      case 'delete_recipe':
        return 'Hapus Resep';
      case 'delete_comment':
        return 'Hapus Komentar';
      default:
        // Untuk action lain, ubah underscore jadi spasi dan huruf besar
        return action.replaceAll('_', ' ').toUpperCase();
    }
  }

  // Fungsi untuk mendapatkan ikon sesuai dengan jenis action
  IconData _getActionIcon(String action) {
    switch (action) {
      case 'ban_user':
        return Icons.block;
      case 'unban_user':
        return Icons.check_circle;
      case 'moderate_recipe':
        return Icons.rate_review;
      case 'delete_recipe':
        return Icons.delete;
      case 'delete_comment':
        return Icons.comment_bank;
      default:
        return Icons.info;
    }
  }

  // Fungsi untuk mendapatkan warna ikon dan border sesuai jenis action
  Color _getActionColor(String action) {
    switch (action) {
      case 'ban_user':
      case 'delete_recipe':
      case 'delete_comment':
        return Colors.red;
      case 'unban_user':
        return Colors.green;
      case 'moderate_recipe':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  // Fungsi untuk memformat waktu menjadi format waktu relatif atau tanggal lengkap
  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      // Menampilkan waktu relatif berdasarkan selisih waktu
      if (difference.inMinutes < 1) {
        return 'Baru saja';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} menit lalu';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} jam lalu';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} hari lalu';
      } else {
        // Jika lebih dari seminggu, tampilkan tanggal lengkap
        return DateFormat('dd MMM yyyy, HH:mm').format(dateTime);
      }
    } catch (e) {
      // Jika format tanggal gagal, kembalikan string asli
      return dateTimeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Warna latar belakang halaman
      backgroundColor: const Color(0xFFF8F4F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD4AF37), // Warna emas
        title: const Text(
          'Log Aktivitas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Panel filter berupa chip horizontal
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Semua', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Ban User', 'ban_user'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Unban User', 'unban_user'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Moderasi', 'moderate_recipe'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Hapus', 'delete_recipe'),
                ],
              ),
            ),
          ),

          // Daftar log aktivitas
          Expanded(
            child: _isLoading && _logs.isEmpty
                ? const Center(child: CircularProgressIndicator()) // Tampilkan loading jika sedang memuat
                : _filteredLogs.isEmpty
                    ? Center( // Tampilkan pesan jika tidak ada data
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada aktivitas ditemukan',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator( // Tambahkan gesture pull-to-refresh
                        onRefresh: _loadLogs,
                        color: const Color(0xFFD4AF37),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredLogs.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _filteredLogs.length) {
                              // Tampilkan loading di akhir daftar jika masih ada data
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final log = _filteredLogs[index];
                            return _buildLogCard(log);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // Membangun widget chip filter
  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterAction == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filterAction = value);
        _applyFilters(); // Terapkan filter saat chip diklik
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // Membangun kartu log aktivitas
  Widget _buildLogCard(Map<String, dynamic> log) {
    final action = log['action'] ?? 'unknown';
    final username = log['profiles']?['username'] ?? 'Unknown User';
    final details = log['details'] as Map<String, dynamic>?;
    final createdAt = log['created_at'];

    final actionColor = _getActionColor(action);
    final actionIcon = _getActionIcon(action);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: actionColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ikon tindakan dengan background warna
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: actionColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                actionIcon,
                color: actionColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Judul tindakan
                  Text(
                    _getActionDisplay(action),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF5C4033),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Nama pengguna yang melakukan tindakan
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        username,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  // Menampilkan detail aktivitas jika tersedia
                  if (details != null && details.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (details['recipe_title'] != null)
                            _buildDetailRow(
                              'Resep',
                              details['recipe_title'],
                            ),
                          if (details['username'] != null)
                            _buildDetailRow(
                              'Target',
                              details['username'],
                            ),
                          if (details['status'] != null)
                            _buildDetailRow(
                              'Status',
                              details['status'].toString().toUpperCase(),
                            ),
                          if (details['action'] != null)
                            _buildDetailRow(
                              'Aksi',
                              details['action'],
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Waktu kejadian
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateTime(createdAt),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Membangun baris detail dalam kartu log
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF5C4033),
              ),
            ),
          ),
        ],
      ),
    );
  }
}