import 'package:flutter/material.dart';
import '../../utils/supabase_client.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatus = 'all';
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    _loadUsers();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('profiles')
          .select('''
            id, username, full_name, role, is_banned, is_premium, avatar_url, 
            created_at, banned_reason, banned_at, banned_by
          ''')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> usersWithAdminInfo = [];
      for (var user in response) {
        final userData = Map<String, dynamic>.from(user);
        
        if (user['banned_by'] != null) {
          try {
            final adminData = await supabase
                .from('profiles')
                .select('username')
                .eq('id', user['banned_by'])
                .maybeSingle();
            
            userData['banned_by_admin_username'] = adminData?['username'] ?? 'Unknown Admin';
          } catch (e) {
            userData['banned_by_admin_username'] = 'Unknown Admin';
          }
        }
        
        usersWithAdminInfo.add(userData);
      }

      if (mounted) {
        setState(() {
          _users = usersWithAdminInfo;
          _applyFilters();
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to load users: $e', isError: true);
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
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF44336), Color(0xFFE57373)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.block_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ban ${user['username']}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select ban reason:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade300,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['spam', 'inappropriate_content', 'harassment', 'fake_account', 'other']
                      .map((reason) {
                    final isSelected = selectedReason == reason;
                    return ChoiceChip(
                      label: Text(
                        _getReasonText(reason),
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.black : Colors.white,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() => selectedReason = reason);
                        }
                      },
                      selectedColor: const Color(0xFFFFD700),
                      backgroundColor: const Color(0xFF2D2D2D),
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
                if (selectedReason == 'other') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter reason...',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      filled: true,
                      fillColor: const Color(0xFF2D2D2D),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF44336), Color(0xFFE57373)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text(
                  'Ban User',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
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
      case 'spam': return 'Spam';
      case 'inappropriate_content': return 'Inappropriate Content';
      case 'harassment': return 'Harassment';
      case 'fake_account': return 'Fake Account';
      case 'other': return 'Other';
      default: return reason;
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

      if (mounted) {
        _showSnackBar('User banned successfully', isError: false);
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  Future<void> _unbanUser(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Unban User', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Are you sure you want to unban ${user['username']}?',
          style: TextStyle(color: Colors.grey.shade300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Unban',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
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

        if (mounted) {
          _showSnackBar('User unbanned successfully', isError: false);
          _loadUsers();
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Error: $e', isError: true);
        }
      }
    }
  }

  Future<void> _togglePremium(Map<String, dynamic> user) async {
    final isPremium = user['is_premium'] == true;
    try {
      await supabase.from('profiles').update({
        'is_premium': !isPremium,
      }).eq('id', user['id']);
      
      if (mounted) {
        _showSnackBar(
          isPremium ? 'Premium removed' : 'Premium granted',
          isError: false,
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildLuxuryAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildSearchAndFilter(),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(60),
                    child: CircularProgressIndicator(color: Color(0xFFFFD700)),
                  )
                else if (_filteredUsers.isEmpty)
                  _buildEmptyState()
                else
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildUserList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLuxuryAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: Colors.black,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.people_alt_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'USER MANAGEMENT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Manage Platform Users',
                              style: TextStyle(
                                color: Color(0xFF4CAF50),
                                fontSize: 13,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      margin: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2D2D2D), Color(0xFF1A1A1A)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
            ),
            child: TextField(
              onChanged: (value) {
                _searchQuery = value;
                _applyFilters();
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search users...',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFFFD700)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Filter Chips
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
            ),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                _buildFilterChip('Active', 'active'),
                _buildFilterChip('Banned', 'banned'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _filterStatus = value);
          _applyFilters();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)])
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.grey.shade500,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) => _buildUserCard(_filteredUsers[index]),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isBanned = user['is_banned'] == true;
    final isAdmin = user['role'] == 'admin';
    final isPremium = user['is_premium'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isBanned
              ? [const Color(0xFF2D1A1A), const Color(0xFF1A1010)]
              : [const Color(0xFF2D2D2D), const Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isBanned
              ? Colors.red.withValues(alpha: 0.3)
              : isAdmin
                  ? const Color(0xFFFFD700).withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1),
          width: isBanned || isAdmin ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isAdmin
                        ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)])
                        : isPremium
                            ? const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)])
                            : null,
                    border: Border.all(
                      color: isAdmin
                          ? const Color(0xFFFFD700)
                          : isPremium
                              ? const Color(0xFF9C27B0)
                              : Colors.grey.shade700,
                      width: 3,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF2D2D2D),
                    backgroundImage:
                        user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                    child: user['avatar_url'] == null
                        ? Text(
                            (user['username'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user['username'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'ADMIN',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                          if (isPremium) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.workspace_premium_rounded,
                              color: Color(0xFF9C27B0),
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                      if (user['full_name'] != null && user['full_name'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          user['full_name'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isBanned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      'BANNED',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
              ],
            ),
            if (isBanned && user['banned_reason'] != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_rounded, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user['banned_reason'],
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: isBanned
                          ? const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)])
                          : const LinearGradient(colors: [Color(0xFFF44336), Color(0xFFE57373)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isAdmin ? null : () => _toggleBanUser(user),
                        borderRadius: BorderRadius.circular(14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isBanned ? Icons.check_circle_rounded : Icons.block_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isBanned ? 'UNBAN' : 'BAN',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isAdmin ? null : () => _togglePremium(user),
                        borderRadius: BorderRadius.circular(14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isPremium ? Icons.workspace_premium : Icons.star_outline_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isPremium ? 'REMOVE' : 'UPGRADE',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(60),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 2),
              ),
              child: Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            Text(
              'No Users Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}