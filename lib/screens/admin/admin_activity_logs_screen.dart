import 'package:flutter/material.dart';
import '../../utils/supabase_client.dart';
import 'package:intl/intl.dart';

class AdminActivityLogsScreen extends StatefulWidget {
  const AdminActivityLogsScreen({super.key});

  @override
  State<AdminActivityLogsScreen> createState() => _AdminActivityLogsScreenState();
}

class _AdminActivityLogsScreenState extends State<AdminActivityLogsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  bool _isLoading = true;
  String _filterAction = 'all';
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  final int _pageSize = 20;
  bool _hasMore = true;
  
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
    
    _loadLogs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      if (!_isLoading && _hasMore) {
        _loadMoreLogs();
      }
    }
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
    });

    try {
      final response = await supabase
          .from('activity_logs')
          .select('*, profiles:user_id(username)')
          .order('created_at', ascending: false)
          .range(_currentPage * _pageSize, (_currentPage + 1) * _pageSize - 1);

      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(response);
          _hasMore = response.length == _pageSize;
          _applyFilters();
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to load logs: $e');
      }
    }
  }

  Future<void> _loadMoreLogs() async {
    setState(() => _currentPage++);

    try {
      final response = await supabase
          .from('activity_logs')
          .select('*, profiles!inner(username)')
          .order('created_at', ascending: false)
          .range(_currentPage * _pageSize, (_currentPage + 1) * _pageSize - 1);

      if (mounted) {
        setState(() {
          _logs.addAll(List<Map<String, dynamic>>.from(response));
          _hasMore = response.length == _pageSize;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _currentPage--);
      }
    }
  }

  void _applyFilters() {
    setState(() {
      if (_filterAction == 'all') {
        _filteredLogs = _logs;
      } else {
        _filteredLogs = _logs.where((log) => log['action'] == _filterAction).toList();
      }
    });
  }

  String _getActionDisplay(String action) {
    switch (action) {
      case 'ban_user': return 'Ban User';
      case 'unban_user': return 'Unban User';
      case 'moderate_recipe': return 'Moderate Recipe';
      case 'delete_recipe': return 'Delete Recipe';
      case 'delete_comment': return 'Delete Comment';
      default: return action.replaceAll('_', ' ').toUpperCase();
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'ban_user': return Icons.block_rounded;
      case 'unban_user': return Icons.check_circle_rounded;
      case 'moderate_recipe': return Icons.rate_review_rounded;
      case 'delete_recipe': return Icons.delete_rounded;
      case 'delete_comment': return Icons.comment_bank_rounded;
      default: return Icons.info_rounded;
    }
  }

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

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('dd MMM yyyy, HH:mm').format(dateTime);
      }
    } catch (e) {
      return dateTimeStr;
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
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
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildLuxuryAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildFilterSection(),
                if (_isLoading && _logs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(60),
                    child: CircularProgressIndicator(color: Color(0xFFFFD700)),
                  )
                else if (_filteredLogs.isEmpty)
                  _buildEmptyState()
                else
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildLogsList(),
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
                            colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2196F3).withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.history_rounded,
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
                              'ACTIVITY LOGS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Monitor All Activities',
                              style: TextStyle(
                                color: Color(0xFF2196F3),
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

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', 'all'),
            const SizedBox(width: 8),
            _buildFilterChip('Ban', 'ban_user'),
            const SizedBox(width: 8),
            _buildFilterChip('Unban', 'unban_user'),
            const SizedBox(width: 8),
            _buildFilterChip('Moderate', 'moderate_recipe'),
            const SizedBox(width: 8),
            _buildFilterChip('Delete', 'delete_recipe'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterAction == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filterAction = value);
        _applyFilters();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)])
              : null,
          color: isSelected ? null : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFD700)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.grey.shade400,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildLogsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      itemCount: _filteredLogs.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _filteredLogs.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Color(0xFFFFD700)),
            ),
          );
        }
        return _buildLogCard(_filteredLogs[index]);
      },
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final action = log['action'] ?? 'unknown';
    final username = log['profiles']?['username'] ?? 'Unknown User';
    final details = log['details'] as Map<String, dynamic>?;
    final createdAt = log['created_at'];

    final actionColor = _getActionColor(action);
    final actionIcon = _getActionIcon(action);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D2D2D), Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: actionColor.withValues(alpha: 0.2),
          width: 1,
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    actionColor,
                    actionColor.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: actionColor.withValues(alpha: 0.4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Icon(actionIcon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getActionDisplay(action),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person_rounded, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        username,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (details != null && details.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (details['recipe_title'] != null)
                            _buildDetailRow('Recipe', details['recipe_title']),
                          if (details['username'] != null)
                            _buildDetailRow('Target', details['username']),
                          if (details['status'] != null)
                            _buildDetailRow('Status', details['status'].toString().toUpperCase()),
                          if (details['action'] != null)
                            _buildDetailRow('Action', details['action']),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        _formatDateTime(createdAt),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade300,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
              child: Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            Text(
              'No Activities Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Activity logs will appear here',
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