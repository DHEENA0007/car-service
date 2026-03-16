import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import '../../utils/theme.dart';
import '../../utils/constants.dart';
import '../../services/api_service.dart';
import '../../models/booking_model.dart';
import '../login_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _tabs = const [
    _DashboardTab(),
    _UsersTab(),
    _AgentsTab(),
    _HistoryTab(),
  ];

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout from Admin Panel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ApiService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    final tabLabels = ['Dashboard', 'Users', 'Agents', 'History'];
    final tabIcons = [
      Icons.dashboard_rounded,
      Icons.people_rounded,
      Icons.support_agent_rounded,
      Icons.history_rounded,
    ];

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: isWide ? null : AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        elevation: 0,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: const Icon(Icons.admin_panel_settings_rounded,
              color: Colors.white, size: 22),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) =>
              AppTheme.primaryGradient.createShader(bounds),
          child: const Text(
            'Admin Panel',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: AppTheme.error, size: 20),
            ),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (isWide)
            _AdminSideNav(
              selectedIndex: _selectedIndex,
              onSelected: (i) => setState(() => _selectedIndex = i),
              labels: tabLabels,
              icons: tabIcons,
              onLogout: _logout,
            ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _tabs,
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : Container(
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: List.generate(4, (index) {
                      final selected = _selectedIndex == index;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedIndex = index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            decoration: BoxDecoration(
                              gradient:
                                  selected ? AppTheme.primaryGradient : null,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  tabIcons[index],
                                  size: 22,
                                  color: selected
                                      ? Colors.white
                                      : AppTheme.textMuted,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  tabLabels[index],
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? Colors.white
                                        : AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 1 – DASHBOARD
// ─────────────────────────────────────────────────────────────

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiService.getAdminStats();
      if (resp['success'] == true) {
        setState(() {
          _stats = resp['data'] ?? {};
        });
      } else {
        setState(() => _error = resp['message'] ?? 'Failed to load stats');
      }
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  static const _statCards = [
    _StatCardConfig(
      key: 'total_users',
      label: 'Total Users',
      icon: Icons.people_alt_rounded,
      gradientColors: [Color(0xFF7C3AED), Color(0xFF9F67FF)],
    ),
    _StatCardConfig(
      key: 'total_agents',
      label: 'Agents',
      icon: Icons.support_agent_rounded,
      gradientColors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    ),
    _StatCardConfig(
      key: 'total_bookings',
      label: 'Total Bookings',
      icon: Icons.book_online_rounded,
      gradientColors: [Color(0xFFEC4899), Color(0xFFF472B6)],
    ),
    _StatCardConfig(
      key: 'pending_bookings',
      label: 'Pending',
      icon: Icons.hourglass_empty_rounded,
      gradientColors: [Color(0xFFF43F5E), Color(0xFFFB7185)],
    ),
    _StatCardConfig(
      key: 'completed_bookings',
      label: 'Completed',
      icon: Icons.check_circle_rounded,
      gradientColors: [Color(0xFF8B5CF6), Color(0xFFC084FC)],
    ),
    _StatCardConfig(
      key: 'paid_bookings',
      label: 'Paid',
      icon: Icons.payments_rounded,
      gradientColors: [Color(0xFFF06292), Color(0xFFF8BBD0)],
    ),
    _StatCardConfig(
      key: 'total_scans',
      label: 'Total Scans',
      icon: Icons.document_scanner_rounded,
      gradientColors: [Color(0xFFD946EF), Color(0xFFFBCFE8)],
    ),
    _StatCardConfig(
      key: 'pending_agents',
      label: 'Pending Agents',
      icon: Icons.pending_actions_rounded,
      gradientColors: [Color(0xFFA18CD1), Color(0xFFFBC2EB)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadStats,
      color: AppTheme.primaryColor,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overview',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Platform-wide statistics at a glance',
                    style: TextStyle(
                        fontSize: 14, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null)
            SliverToBoxAdapter(
              child: _ErrorBanner(message: _error!, onRetry: _loadStats),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final config = _statCards[index];
                    if (_loading) return _ShimmerStatCard();
                    final value = _stats[config.key];
                    return _StatCard(
                      config: config,
                      value: value?.toString() ?? '0',
                      index: index,
                    );
                  },
                  childCount: _statCards.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:
                      MediaQuery.of(context).size.width > 1200 ? 4 : 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio:
                      MediaQuery.of(context).size.width > 1200 ? 1.8 : 1.5,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _StatCardConfig {
  final String key;
  final String label;
  final IconData icon;
  final List<Color> gradientColors;

  const _StatCardConfig({
    required this.key,
    required this.label,
    required this.icon,
    required this.gradientColors,
  });
}

class _StatCard extends StatelessWidget {
  final _StatCardConfig config;
  final String value;
  final int index;

  const _StatCard({
    required this.config,
    required this.value,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: config.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: config.gradientColors.first.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Icon(config.icon,
                      color: Colors.white, size: 20),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  config.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 80))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.15, end: 0, duration: 400.ms,
            curve: Curves.easeOut);
  }
}

class _ShimmerStatCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceBg,
      highlightColor: AppTheme.cardBg,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 2 – USERS
// ─────────────────────────────────────────────────────────────

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  String _roleFilter = 'all';

  static const _roles = ['all', 'user', 'agent', 'admin'];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiService.getAdminUsers(
          role: _roleFilter == 'all' ? null : _roleFilter);
      if (resp['success'] == true) {
        final raw = resp['data'] as List? ?? [];
        setState(() {
          _users = raw.cast<Map<String, dynamic>>();
        });
      } else {
        setState(() => _error = resp['message'] ?? 'Failed to load users');
      }
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _changeRole(Map<String, dynamic> user) async {
    String selectedRole = user['role'] ?? 'user';
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
          title: Text('Change Role – ${user['username']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['user', 'agent', 'admin'].map((role) {
              return RadioListTile<String>(
                title: Text(role.toUpperCase()),
                value: role,
                groupValue: selectedRole,
                activeColor: AppTheme.primaryColor,
                onChanged: (v) {
                  if (v != null) setDlg(() => selectedRole = v);
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selectedRole),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result != user['role']) {
      try {
        final id = user['id'] as int;
        final resp = await ApiService.updateUserRole(id, result);
        if (resp['success'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Role updated to $result'),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadUsers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return AppTheme.error;
      case 'agent':
        return AppTheme.primaryColor;
      default:
        return AppTheme.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadUsers,
      color: AppTheme.primaryColor,
      child: Column(
        children: [
          // Filter chips
          Container(
            color: AppTheme.scaffoldBg,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _roles.map((role) {
                    final selected = _roleFilter == role;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(role.toUpperCase()),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _roleFilter = role);
                          _loadUsers();
                        },
                        selectedColor:
                            AppTheme.primaryColor.withValues(alpha: 0.15),
                        checkmarkColor: AppTheme.primaryColor,
                        labelStyle: TextStyle(
                          color: selected
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondary,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: _loading
                ? _buildShimmer()
                : _error != null
                    ? _ErrorBanner(message: _error!, onRetry: _loadUsers)
                    : _users.isEmpty
                        ? _EmptyState(
                            icon: Icons.people_outline_rounded,
                            message: 'No users found',
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              final role = user['role'] ?? 'user';
                              final username =
                                  user['username'] ?? 'Unknown';
                              final email = user['email'] ?? '';
                              final initials = username.isNotEmpty
                                  ? username[0].toUpperCase()
                                  : '?';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardBg,
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMd),
                                  boxShadow: AppTheme.cardShadow,
                                ),
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    radius: 22,
                                    backgroundColor: AppTheme.primaryColor
                                        .withValues(alpha: 0.15),
                                    child: Text(
                                      initials,
                                      style: const TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    username,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  subtitle: Text(
                                    email,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  trailing: GestureDetector(
                                    onTap: () => _changeRole(user),
                                    child: Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: _roleColor(role)
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _roleColor(role)
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Text(
                                        role.toUpperCase(),
                                        style: TextStyle(
                                          color: _roleColor(role),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  onTap: () => _changeRole(user),
                                ),
                              ).animate(
                                  delay: Duration(
                                      milliseconds: index * 50))
                                  .fadeIn(duration: 300.ms)
                                  .slideX(
                                      begin: 0.05,
                                      end: 0,
                                      duration: 300.ms);
                            },
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 8,
      itemBuilder: (context, _) => Shimmer.fromColors(
        baseColor: AppTheme.surfaceBg,
        highlightColor: AppTheme.cardBg,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 72,
          decoration: BoxDecoration(
            color: AppTheme.surfaceBg,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 3 – AGENTS
// ─────────────────────────────────────────────────────────────

class _AgentsTab extends StatefulWidget {
  const _AgentsTab();

  @override
  State<_AgentsTab> createState() => _AgentsTabState();
}

class _AgentsTabState extends State<_AgentsTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _agents = [];

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiService.getAdminAgents();
      if (resp['success'] == true) {
        final raw = resp['data'] as List? ?? [];
        setState(() {
          _agents = raw.cast<Map<String, dynamic>>();
        });
      } else {
        setState(() => _error = resp['message'] ?? 'Failed to load agents');
      }
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleApproval(Map<String, dynamic> agent) async {
    final id = agent['id'] as int;
    final isApproved = agent['is_approved'] as bool? ?? false;
    final action = isApproved ? 'Suspend' : 'Approve';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: Text('$action Agent'),
        content: Text(
            'Are you sure you want to $action ${agent['full_name']?.toString().trim().isNotEmpty == true ? agent['full_name'] : agent['username'] ?? 'this agent'}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isApproved ? AppTheme.error : AppTheme.success,
            ),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final resp = await ApiService.approveAgent(id, !isApproved);
        if (resp['success'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Agent ${!isApproved ? 'approved' : 'suspended'} successfully'),
              backgroundColor:
                  !isApproved ? AppTheme.success : AppTheme.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadAgents();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _showCreateAgentDialog() async {
    final isWide = MediaQuery.of(context).size.width > 900;

    if (isWide) {
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: _AgentCreateForm(
              onSuccess: () {
                Navigator.pop(ctx);
                _loadAgents();
              },
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppTheme.cardBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => _AgentCreateForm(
          onSuccess: () {
            Navigator.pop(ctx);
            _loadAgents();
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateAgentDialog,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Add Agent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAgents,
        color: AppTheme.primaryColor,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: _loading
                ? _buildShimmer()
                : _error != null
                    ? _ErrorBanner(message: _error!, onRetry: _loadAgents)
                    : _agents.isEmpty
                        ? _EmptyState(
                            icon: Icons.support_agent_outlined,
                            message: 'No agents yet. Tap + Add Agent to create one.',
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            itemCount: _agents.length,
                            itemBuilder: (context, index) {
                              final agent = _agents[index];
                              final isApproved =
                                  agent['is_approved'] as bool? ?? false;
                              final name = (agent['full_name'] as String?)
                                      ?.trim()
                                      .isNotEmpty ==
                                  true
                                  ? agent['full_name'] as String
                                  : (agent['username'] ?? 'Unknown') as String;
                              final email = agent['email'] ?? '';
                              final completed =
                                  agent['total_completed'] ?? 0;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardBg,
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusLg),
                                  boxShadow: AppTheme.cardShadow,
                                  border: Border.all(
                                    color: isApproved
                                        ? AppTheme.success
                                            .withValues(alpha: 0.2)
                                        : AppTheme.warning
                                            .withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              gradient:
                                                  AppTheme.primaryGradient,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppTheme.radiusMd),
                                            ),
                                            child: Center(
                                              child: Text(
                                                name.isNotEmpty
                                                    ? name[0].toUpperCase()
                                                    : 'A',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppTheme.textPrimary,
                                                  ),
                                                ),
                                                Text(
                                                  email,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color:
                                                        AppTheme.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5),
                                            decoration: BoxDecoration(
                                              color: (isApproved
                                                      ? AppTheme.success
                                                      : AppTheme.warning)
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: (isApproved
                                                        ? AppTheme.success
                                                        : AppTheme.warning)
                                                    .withValues(alpha: 0.5),
                                              ),
                                            ),
                                            child: Text(
                                              isApproved
                                                  ? 'APPROVED'
                                                  : 'PENDING',
                                              style: TextStyle(
                                                color: isApproved
                                                    ? AppTheme.success
                                                    : AppTheme.warning,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          _InfoChip(
                                            icon: Icons.check_circle_rounded,
                                            label: '$completed completed',
                                            color: AppTheme.success,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _toggleApproval(agent),
                                          icon: Icon(
                                            isApproved
                                                ? Icons.block_rounded
                                                : Icons.check_rounded,
                                            size: 16,
                                          ),
                                          label: Text(
                                              isApproved ? 'Suspend' : 'Approve'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isApproved
                                                ? AppTheme.error
                                                : AppTheme.success,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppTheme.radiusMd),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                                  .animate(
                                      delay: Duration(
                                          milliseconds: index * 70))
                                  .fadeIn(duration: 350.ms)
                                  .slideY(
                                      begin: 0.1,
                                      end: 0,
                                      duration: 350.ms,
                                      curve: Curves.easeOut);
                            },
                          ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: 5,
      itemBuilder: (context, _) => Shimmer.fromColors(
        baseColor: AppTheme.surfaceBg,
        highlightColor: AppTheme.cardBg,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 160,
          decoration: BoxDecoration(
            color: AppTheme.surfaceBg,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 4 – HISTORY (Scans + Bookings)
// ─────────────────────────────────────────────────────────────

class _AgentCreateForm extends StatefulWidget {
  final VoidCallback onSuccess;
  const _AgentCreateForm({required this.onSuccess});

  @override
  State<_AgentCreateForm> createState() => _AgentCreateFormState();
}

class _AgentCreateFormState extends State<_AgentCreateForm> {
  final _formKey = GlobalKey<FormState>();
  final usernameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  bool submitting = false;
  bool obscure = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceBg,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.support_agent_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Create New Agent',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Agent will be auto-approved and can start accepting bookings.',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: usernameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Username *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: firstNameCtrl,
                      decoration: const InputDecoration(labelText: 'First Name'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: lastNameCtrl,
                      decoration: const InputDecoration(labelText: 'Last Name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          setState(() => submitting = true);
                          final resp = await ApiService.createAgentByAdmin({
                            'username': usernameCtrl.text.trim(),
                            'email': emailCtrl.text.trim(),
                            'first_name': firstNameCtrl.text.trim(),
                            'last_name': lastNameCtrl.text.trim(),
                            'phone_number': phoneCtrl.text.trim(),
                            'password': passwordCtrl.text,
                          });
                          setState(() => submitting = false);
                          if (resp['success'] == true) {
                            widget.onSuccess();
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(resp['message'] ??
                                      'Failed to create agent'),
                                  backgroundColor: AppTheme.error,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Create Agent',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppTheme.scaffoldBg,
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textMuted,
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 3,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              tabs: const [
                Tab(text: 'Scan History'),
                Tab(text: 'Bookings'),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _ScansSubTab(),
              _BookingsSubTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Scans sub-tab ──────────────────────────────────────────

class _ScansSubTab extends StatefulWidget {
  const _ScansSubTab();

  @override
  State<_ScansSubTab> createState() => _ScansSubTabState();
}

class _ScansSubTabState extends State<_ScansSubTab>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _scans = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadScans();
  }

  Future<void> _loadScans() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiService.getAdminScans();
      if (resp['success'] == true) {
        final raw = resp['data'] as List? ?? [];
        setState(() => _scans = raw.cast<Map<String, dynamic>>());
      } else {
        setState(() => _error = resp['message'] ?? 'Failed to load scans');
      }
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _loadScans,
      color: AppTheme.primaryColor,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: _loading
              ? _buildShimmer()
              : _error != null
                  ? _ErrorBanner(message: _error!, onRetry: _loadScans)
                  : _scans.isEmpty
                      ? _EmptyState(
                          icon: Icons.document_scanner_outlined,
                          message: 'No scans found',
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount: _scans.length,
                          itemBuilder: (context, index) {
                        final scan = _scans[index];
                        final urgency =
                            scan['urgency_level'] ?? 'medium';
                        final imageUrl = scan['image'];
                        final username = scan['user_name'] ?? 'Unknown';
                        final issue =
                            scan['detected_issue'] ?? 'No issue detected';
                        final date = _formatDate(
                            scan['created_at']?.toString() ?? '');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Row(
                            children: [
                              // Thumbnail
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(
                                      AppTheme.radiusMd),
                                  bottomLeft: Radius.circular(
                                      AppTheme.radiusMd),
                                ),
                                child: SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: imageUrl != null &&
                                          imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl.startsWith('http')
                                              ? imageUrl
                                              : '${AppConstants.serverUrl}$imageUrl',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _placeholder(),
                                        )
                                      : _placeholder(),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                              Icons.person_rounded,
                                              size: 13,
                                              color:
                                                  AppTheme.textMuted),
                                          const SizedBox(width: 4),
                                          Text(
                                            username,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textMuted,
                                              fontWeight:
                                                  FontWeight.w600,
                                            ),
                                          ),
                                          const Spacer(),
                                          _UrgencyBadge(
                                              urgency: urgency),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        issue,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        date,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                            .animate(
                                delay: Duration(
                                    milliseconds: index * 40))
                            .fadeIn(duration: 280.ms);
                      },
                    ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppTheme.surfaceBg,
        child: const Icon(Icons.image_outlined,
            color: AppTheme.textMuted, size: 28),
      );

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: 7,
      itemBuilder: (context, _) => Shimmer.fromColors(
        baseColor: AppTheme.surfaceBg,
        highlightColor: AppTheme.cardBg,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.surfaceBg,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
      ),
    );
  }
}

// ── Bookings sub-tab ───────────────────────────────────────

class _BookingsSubTab extends StatefulWidget {
  const _BookingsSubTab();

  @override
  State<_BookingsSubTab> createState() => _BookingsSubTabState();
}

class _BookingsSubTabState extends State<_BookingsSubTab>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _error;
  List<BookingModel> _bookings = [];
  String _statusFilter = 'all';

  static const _statuses = [
    'all',
    'pending',
    'accepted',
    'in_progress',
    'completed',
    'cancelled',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiService.getAdminBookings(
          statusFilter: _statusFilter == 'all' ? null : _statusFilter);
      if (resp['success'] == true) {
        final raw = resp['data'] as List? ?? [];
        setState(() {
          _bookings = raw
              .cast<Map<String, dynamic>>()
              .map(BookingModel.fromMap)
              .toList();
        });
      } else {
        setState(
            () => _error = resp['message'] ?? 'Failed to load bookings');
      }
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warning;
      case 'accepted':
        return AppTheme.info;
      case 'in_progress':
        return AppTheme.primaryColor;
      case 'completed':
        return AppTheme.success;
      case 'cancelled':
        return AppTheme.error;
      default:
        return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // Status filter chips
        Container(
          color: AppTheme.scaffoldBg,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statuses.map((status) {
                  final selected = _statusFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(status == 'all'
                          ? 'ALL'
                          : status.replaceAll('_', ' ').toUpperCase()),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _statusFilter = status);
                        _loadBookings();
                      },
                      selectedColor:
                          AppTheme.primaryColor.withValues(alpha: 0.15),
                      checkmarkColor: AppTheme.primaryColor,
                      labelStyle: TextStyle(
                        color: selected
                            ? AppTheme.primaryColor
                            : AppTheme.textSecondary,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadBookings,
            color: AppTheme.primaryColor,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: _loading
                    ? _buildShimmer()
                    : _error != null
                        ? _ErrorBanner(
                            message: _error!, onRetry: _loadBookings)
                        : _bookings.isEmpty
                            ? _EmptyState(
                                icon: Icons.book_online_outlined,
                                message: 'No bookings found',
                              )
                            : ListView.builder(
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: _bookings.length,
                            itemBuilder: (context, index) {
                              final booking = _bookings[index];
                              final statusColor =
                                  _statusColor(booking.status);

                              return Container(
                                margin:
                                    const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardBg,
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMd),
                                  boxShadow: AppTheme.cardShadow,
                                  border: Border(
                                    left: BorderSide(
                                      color: statusColor,
                                      width: 4,
                                    ),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '#${booking.id}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.textMuted,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 9,
                                                    vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      20),
                                            ),
                                            child: Text(
                                              booking.statusLabel,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        booking.detectedIssue.isNotEmpty
                                            ? booking.detectedIssue
                                            : 'Service Request',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          _MiniInfo(
                                            icon: Icons.person_rounded,
                                            label: booking.userName,
                                          ),
                                          if (booking.agentName !=
                                              null) ...[
                                            const SizedBox(width: 12),
                                            _MiniInfo(
                                              icon: Icons
                                                  .support_agent_rounded,
                                              label: booking.agentName!,
                                            ),
                                          ],
                                          const Spacer(),
                                          Text(
                                            booking.dateString,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              )
                                  .animate(
                                      delay: Duration(
                                          milliseconds: index * 40))
                                  .fadeIn(duration: 280.ms)
                                  .slideX(
                                      begin: 0.05,
                                      end: 0,
                                      duration: 280.ms);
                            },
                          ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 6,
      itemBuilder: (context, _) => Shimmer.fromColors(
        baseColor: AppTheme.surfaceBg,
        highlightColor: AppTheme.cardBg,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 90,
          decoration: BoxDecoration(
            color: AppTheme.surfaceBg,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SHARED HELPERS
// ─────────────────────────────────────────────────────────────

class _UrgencyBadge extends StatelessWidget {
  final String urgency;
  const _UrgencyBadge({required this.urgency});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getUrgencyColor(urgency);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        urgency.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color = AppTheme.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniInfo({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.textMuted),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: AppTheme.error, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.surfaceBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.textMuted, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pull down to refresh',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

String _formatDate(String raw) {
  try {
    final dt = DateTime.parse(raw).toLocal();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  } catch (_) {
    return raw;
  }
}

class _AdminSideNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<String> labels;
  final List<IconData> icons;
  final VoidCallback onLogout;

  const _AdminSideNav({
    required this.selectedIndex,
    required this.onSelected,
    required this.labels,
    required this.icons,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Logo Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ANTIGRAVITY',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      Text(
                        'ADMIN PORTAL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          // Nav Items
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: labels.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final selected = selectedIndex == index;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onSelected(index),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primaryColor.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primaryColor.withValues(alpha: 0.2)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icons[index],
                            color: selected
                                ? AppTheme.primaryColor
                                : AppTheme.textMuted,
                            size: 22,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            labels[index],
                            style: TextStyle(
                              color: selected
                                  ? AppTheme.primaryColor
                                  : AppTheme.textSecondary,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          if (selected) ...[
                            const Spacer(),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Logout Section
          Padding(
            padding: const EdgeInsets.all(24),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onLogout,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.logout_rounded,
                          color: AppTheme.error, size: 22),
                      const SizedBox(width: 16),
                      Text(
                        'Logout',
                        style: TextStyle(
                          color: AppTheme.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
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
    );
  }
}

