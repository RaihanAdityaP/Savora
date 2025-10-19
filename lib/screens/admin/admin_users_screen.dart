import 'package:flutter/material.dart';
import '../../utils/supabase_client.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('profiles')
          .select('''
            id, username, full_name, role, is_banned, is_premium, avatar_url, 
            created_at, banned_reason, banned_at, banned_by,
            banned_by_admin:profiles!banned_by(username)
          ''')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(response);
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat pengguna: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredUsers = _users.where((user) {
        final matchesSearch = _searchQuery.isEmpty ||
            (user['username']?.toLowerCase() ?? '').contains(_searchQuery.toLowerCase()) ||
            (user['full_name']?.toLowerCase() ?? '').contains(_searchQuery.toLowerCase());

        final isBanned = user['is_banned'] == true;
        final matchesStatus = _filterStatus == 'all' ||
            (_filterStatus == 'banned' && isBanned) ||
            (_filterStatus == 'active' && !isBanned);

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  Future<void> _toggleBanUser(Map<String, dynamic> user) async {
    final isBanned = user['is_banned'] == true;
    
    if (isBanned) {
      await _unbanUser(user);
    } else {
      await _showBanDialog(user);
    }
  }

  Future<void> _showBanDialog(Map<String, dynamic> user) async {
    final reasonController = TextEditingController();
    String selectedReason = 'spam';
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Ban ${user['username']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih alasan ban:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'spam',
                    'inappropriate_content',
                    'harassment',
                    'fake_account',
                    'other'
                  ].map((reason) {
                    final isSelected = selectedReason == reason;
                    return ChoiceChip(
                      label: Text(
                        _getReasonText(reason),
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() => selectedReason = reason);
                        }
                      },
                      selectedColor: const Color(0xFFD4AF37),
                      backgroundColor: Colors.grey.shade200,
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    );
                  }).toList(),
                ),
                if (selectedReason == 'other') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Masukkan alasan...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFFD4AF37),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ban User'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final reason = selectedReason == 'other' && reasonController.text.isNotEmpty
          ? reasonController.text
          : _getReasonText(selectedReason);
      
      await _banUser(user, reason);
    }
  }

  String _getReasonText(String reason) {
    switch (reason) {
      case 'spam':
        return 'Spam';
      case 'inappropriate_content':
        return 'Konten Tidak Pantas';
      case 'harassment':
        return 'Pelecehan';
      case 'fake_account':
        return 'Akun Palsu';
      case 'other':
        return 'Lainnya';
      default:
        return reason;
    }
  }

  Future<void> _banUser(Map<String, dynamic> user, String reason) async {
    try {
      final adminId = supabase.auth.currentUser?.id;
      final now = DateTime.now().toIso8601String();
      
      await supabase.from('profiles').update({
        'is_banned': true,
        'banned_at': now,
        'banned_reason': reason,
        'banned_by': adminId,
      }).eq('id', user['id']);

      await supabase.rpc('log_ban_activity', params: {
        'p_user_id': adminId,
        'p_target_user_id': user['id'],
        'p_action': 'ban_user',
        'p_reason': reason,
        'p_is_ban': true,
      });

      await supabase.rpc('create_notification', params: {
        'p_user_id': user['id'],
        'p_title': 'Akun Dinonaktifkan',
        'p_message': 'Akun Anda telah dinonaktifkan. Alasan: $reason',
        'p_type': 'admin',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User berhasil dibanned'),
            backgroundColor: Colors.red,
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _unbanUser(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aktifkan Pengguna'),
        content: Text(
          'Apakah Anda yakin ingin mengaktifkan kembali ${user['username']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Aktifkan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final adminId = supabase.auth.currentUser?.id;
        
        await supabase.from('profiles').update({
          'is_banned': false,
          'banned_at': null,
          'banned_reason': null,
          'banned_by': null,
        }).eq('id', user['id']);

        await supabase.rpc('log_ban_activity', params: {
          'p_user_id': adminId,
          'p_target_user_id': user['id'],
          'p_action': 'unban_user',
          'p_is_ban': false,
        });

        await supabase.rpc('create_notification', params: {
          'p_user_id': user['id'],
          'p_title': 'Akun Diaktifkan Kembali',
          'p_message': 'Akun Anda telah diaktifkan kembali. Silakan login.',
          'p_type': 'admin',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User berhasil diaktifkan kembali'),
              backgroundColor: Colors.green,
            ),
          );
          _loadUsers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _showBanDetails(Map<String, dynamic> user) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detail Ban'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Username', user['username'] ?? '-'),
              _buildDetailRow('Alasan', user['banned_reason'] ?? '-'),
              _buildDetailRow(
                'Waktu',
                user['banned_at'] != null
                    ? _formatDateTime(user['banned_at'])
                    : '-',
              ),
              _buildDetailRow(
                'Oleh',
                user['banned_by_admin']?['username'] ?? '-',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String dateTimeStr) {
    final dateTime = DateTime.parse(dateTimeStr);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} hari lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam lalu';
    } else {
      return '${difference.inMinutes} menit lalu';
    }
  }

  Future<void> _togglePremium(Map<String, dynamic> user) async {
    final isPremium = user['is_premium'] == true;
    
    try {
      await supabase.from('profiles').update({
        'is_premium': !isPremium,
      }).eq('id', user['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPremium ? 'Premium status dihapus' : 'Premium status diberikan',
            ),
            backgroundColor: const Color(0xFFE5BFA5),
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD4AF37),
        title: const Text(
          'Kelola Pengguna',
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
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                _searchQuery = value;
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: 'Cari pengguna...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF5C4033)),
                filled: true,
                fillColor: const Color(0xFFF8F4F0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(child: _buildFilterChip('Semua', 'all')),
                const SizedBox(width: 8),
                Expanded(child: _buildFilterChip('Aktif', 'active')),
                const SizedBox(width: 8),
                Expanded(child: _buildFilterChip('Banned', 'banned')),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada pengguna ditemukan',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        color: const Color(0xFFD4AF37),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) => _buildUserCard(_filteredUsers[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filterStatus = value);
        _applyFilters();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isBanned = user['is_banned'] == true;
    final isAdmin = user['role'] == 'admin';
    final isPremium = user['is_premium'] == true;
    final username = user['username'] ?? 'Unknown';
    final fullName = user['full_name'] ?? '';
    final avatarUrl = user['avatar_url'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBanned
              ? Colors.red.shade200
              : isAdmin
                  ? const Color(0xFFD4AF37).withValues(alpha: 0.3)
                  : Colors.transparent,
          width: isBanned || isAdmin ? 2 : 0,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isAdmin
                      ? const Color(0xFFD4AF37)
                      : isPremium
                          ? const Color(0xFFE5BFA5)
                          : Colors.grey.shade300,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(
                          username[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              username,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF5C4033),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4AF37),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ADMIN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          if (isPremium) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.workspace_premium, color: Color(0xFFE5BFA5), size: 16),
                          ],
                        ],
                      ),
                      if (fullName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          fullName,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (isBanned)
                  GestureDetector(
                    onTap: () => _showBanDetails(user),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'BANNED',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.info_outline, size: 14, color: Colors.red.shade700),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (isBanned && user['banned_reason'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, size: 16, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        user['banned_reason'],
                        style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isAdmin ? null : () => _toggleBanUser(user),
                    icon: Icon(isBanned ? Icons.check_circle : Icons.block, size: 18),
                    label: Text(isBanned ? 'Aktifkan' : 'Ban'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isBanned ? Colors.green : Colors.red,
                      side: BorderSide(color: isBanned ? Colors.green : Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isAdmin ? null : () => _togglePremium(user),
                    icon: Icon(isPremium ? Icons.workspace_premium : Icons.star_outline, size: 18),
                    label: Text(isPremium ? 'Premium' : 'Upgrade'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE5BFA5),
                      side: const BorderSide(color: Color(0xFFE5BFA5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}