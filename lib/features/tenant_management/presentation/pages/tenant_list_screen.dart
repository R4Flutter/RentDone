import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/tenant_management/presentation/providers/tenant_providers.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';

class TenantListScreen extends ConsumerStatefulWidget {
  const TenantListScreen({super.key});

  @override
  ConsumerState<TenantListScreen> createState() => _TenantListScreenState();
}

class _TenantListScreenState extends ConsumerState<TenantListScreen> {
  int _currentPage = 1;
  String _filterStatus = 'active';
  final TextEditingController _searchController = TextEditingController();
  late String _userId;

  @override
  void initState() {
    super.initState();
    _userId = ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tenantsAsync = ref.watch(
      tenantsProvider((
        ownerId: _userId,
        page: _currentPage,
        filterStatus: _filterStatus.isEmpty ? null : _filterStatus,
      )),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Tenants'),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'analytics') {
                  context.push('/tenant-management/analytics');
                } else if (value == 'logout') {
                  ref.read(firebaseAuthProvider).signOut();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'analytics',
                  child: Row(
                    children: [
                      Icon(Icons.analytics, color: Colors.black87),
                      SizedBox(width: 12),
                      Text('Analytics'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.more_vert, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context, ref),
      body: Column(
        children: [
          // Filter and Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Status Filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', '', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Active', 'active', 'active'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Inactive', 'inactive', 'inactive'),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Notice Period',
                        'notice_period',
                        'notice_period',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Search Box
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search tenants by name or phone',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _currentPage = 1;
                    });
                  },
                ),
              ],
            ),
          ),

          // Tenants List
          Expanded(
            child: tenantsAsync.when(
              data: (tenants) {
                if (tenants.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No tenants found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchController.text.isEmpty
                              ? 'Click the + button to add your first tenant'
                              : 'Try adjusting your search filters',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Filter by search if needed
                final filteredTenants = _searchController.text.isEmpty
                    ? tenants
                    : tenants.where((tenant) {
                        final query = _searchController.text.toLowerCase();
                        return tenant.fullName.toLowerCase().contains(query) ||
                            tenant.phone.contains(query);
                      }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredTenants.length + 1,
                  itemBuilder: (context, index) {
                    if (index == filteredTenants.length) {
                      // Pagination controls
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_currentPage > 1)
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _currentPage--;
                                  });
                                },
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Previous'),
                              ),
                            const SizedBox(width: 12),
                            Text(
                              'Page $_currentPage',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 12),
                            if (tenants.length == 20)
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _currentPage++;
                                  });
                                },
                                icon: const Icon(Icons.arrow_forward),
                                label: const Text('Next'),
                              ),
                          ],
                        ),
                      );
                    }

                    final tenant = filteredTenants[index];
                    return _buildTenantCard(context, tenant);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading tenants',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Retry by navigating to this screen again
                        context.go('/tenant-management/list');
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryBlue,
        onPressed: () {
          // Navigate to add tenant screen
          context.push('/tenant-management/add-tenant');
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String key) {
    final isSelected = _filterStatus == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = selected ? value : 'all';
          _currentPage = 1;
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: AppTheme.primaryBlue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildTenantCard(BuildContext context, dynamic tenant) {
    final statusColor = _getStatusColor(tenant.status);
    final statusLabel = _getStatusLabel(tenant.status);

    return GestureDetector(
      onTap: () {
        // Navigate to tenant detail/edit screen
        context.push(
          '/tenant-management/edit-tenant/${tenant.id}',
          extra: tenant,
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Name and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tenant.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tenant.phone,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Details: Room, Rent, Lease
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDetailItem('Room', tenant.roomNumber),
                  _buildDetailItem('Rent', '₹${tenant.rentAmount}'),
                  _buildDetailItem('Due', 'Day ${tenant.rentDueDate}'),
                ],
              ),
              const SizedBox(height: 12),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.push(
                          '/tenant-management/record-payment/${tenant.id}',
                          extra: tenant,
                        );
                      },
                      icon: const Icon(Icons.attach_money, size: 18),
                      label: const Text('Record Payment'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.push(
                          '/tenant-management/edit-tenant/${tenant.id}',
                          extra: tenant,
                        );
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showDeactivateDialog(context, tenant),
                      icon: const Icon(Icons.block, size: 18),
                      label: const Text('Deactivate'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.grey;
      case 'notice_period':
        return Colors.orange;
      case 'suspended':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'inactive':
        return 'Inactive';
      case 'notice_period':
        return 'Notice Period';
      case 'suspended':
        return 'Suspended';
      default:
        return status;
    }
  }

  void _showDeactivateDialog(BuildContext context, dynamic tenant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Tenant'),
        content: Text(
          'Are you sure you want to deactivate ${tenant.fullName}? They will not be able to access the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deactivateTenant(tenant.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  Future<void> _deactivateTenant(String tenantId) async {
    try {
      await ref
          .read(tenantNotifierProvider.notifier)
          .deactivateTenant(tenantId);

      if (!mounted) return;

      // Refresh the list
      setState(() {
        _currentPage = 1;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tenant deactivated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseAuthProvider).currentUser;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: AppTheme.primaryBlue),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person,
                    size: 32,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.email ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Tenant List'),
            onTap: () {
              Navigator.pop(context);
              context.go('/tenant-management/list');
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text('Add Tenant'),
            onTap: () {
              Navigator.pop(context);
              context.push('/tenant-management/add-tenant?propertyId=default');
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Analytics'),
            onTap: () {
              Navigator.pop(context);
              context.push('/tenant-management/analytics');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pop(context);
              context.go('/owner/dashboard');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              context.go('/owner/settings');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              ref.read(firebaseAuthProvider).signOut();
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
