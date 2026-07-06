import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/audit_log.dart';
import '../../shared/providers.dart';
import '../layout/admin_layout.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  String? _searchQuery;
  bool? _isBanned;
  bool? _isSuspended;
  bool? _isVerified;
  String? _selectedRole;
  String? _selectedUniversity;
  String _sortBy = 'name';
  bool _descending = false;
  DateTimeRange? _dateRange;
  final Set<String> _selectedIds = {};
  bool _isBulkProcessing = false;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _handleBulkAction(String action, List<AppUser> users) async {
    final selectedUsers = users.where((u) => _selectedIds.contains(u.uid)).toList();
    if (selectedUsers.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bulk $action'),
        content: Text('Are you sure you want to $action ${selectedUsers.length} users?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isBulkProcessing = true);
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      final admin = ref.read(appUserProvider).valueOrNull;
      if (admin == null) throw Exception('Admin session not found');

      await ref.read(adminServiceProvider).bulkUpdateUserStatus(
        userIds: selectedUsers.map((u) => u.uid).toList(),
        isBanned: action == 'ban',
        adminId: admin.uid,
        adminName: admin.fullName,
      );
      
      if (mounted) {
        setState(() {
          _selectedIds.clear();
          _isBulkProcessing = false;
        });
        messenger.showSnackBar(SnackBar(content: Text('Bulk $action completed successfully')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBulkProcessing = false);
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = (
      search: _searchQuery,
      isBanned: _isBanned,
      isSuspended: _isSuspended,
      isVerified: _isVerified,
      role: _selectedRole,
      university: _selectedUniversity,
      sortBy: _sortBy,
      descending: _descending,
      startDate: _dateRange?.start,
      endDate: _dateRange?.end,
    );
    final usersAsync = ref.watch(adminUsersProvider(filters));

    return AdminLayout(
      title: 'User Management',
      child: Column(
        children: [
          _buildTopPanel(usersAsync.valueOrNull?.length ?? 0, usersAsync.valueOrNull ?? []),
          Expanded(
            child: usersAsync.when(
              data: (users) => _buildUserList(users),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPanel(int count, List<AppUser> users) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search Name, Email, Username, Phone, ID...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery != null && _searchQuery!.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = null);
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  onSubmitted: (val) {
                    setState(() => _searchQuery = val.isEmpty ? null : val);
                  },
                ),
              ),
              const SizedBox(width: 16),
              _buildSortDropdown(),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(_descending ? Icons.arrow_downward : Icons.arrow_upward),
                onPressed: () => setState(() => _descending = !_descending),
                tooltip: 'Toggle Order',
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildUniFilter(),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Verified',
                  isSelected: _isVerified == true,
                  onSelected: (selected) {
                    setState(() => _isVerified = selected ? true : null);
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Banned',
                  isSelected: _isBanned == true,
                  onSelected: (selected) {
                    setState(() => _isBanned = selected ? true : null);
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Suspended',
                  isSelected: _isSuspended == true,
                  onSelected: (selected) {
                    setState(() => _isSuspended = selected ? true : null);
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Admins',
                  isSelected: _selectedRole == 'admin',
                  onSelected: (selected) {
                    setState(() => _selectedRole = selected ? 'admin' : null);
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Plugs',
                  isSelected: _selectedRole == 'housing_plug',
                  onSelected: (selected) {
                    setState(() => _selectedRole = selected ? 'housing_plug' : null);
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.date_range, size: 14),
                  label: Text(
                    _dateRange == null 
                        ? 'Date Range' 
                        : '${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd').format(_dateRange!.end)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                if (_dateRange != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    onPressed: () => setState(() => _dateRange = null),
                  ),
                const SizedBox(width: 16),
                Text('$count Users',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant, 
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    )),
              ],
            ),
          ),
          if (_selectedIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text('${_selectedIds.length} Selected', 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(width: 24),
                  if (_isBulkProcessing) 
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else ...[
                    TextButton.icon(
                      onPressed: () => _handleBulkAction('ban', users),
                      icon: const Icon(Icons.block, color: AppColors.error),
                      label: const Text('Ban Selected', style: TextStyle(color: AppColors.error)),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _handleBulkAction('restore', users),
                      icon: const Icon(Icons.restore, color: AppColors.success),
                      label: const Text('Restore Selected', style: TextStyle(color: AppColors.success)),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => setState(() => _selectedIds.clear()),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSortDropdown() {
    return DropdownButton<String>(
      value: _sortBy,
      underline: const SizedBox(),
      icon: const Icon(Icons.sort),
      items: const [
        DropdownMenuItem(value: 'name', child: Text('Sort: Name')),
        DropdownMenuItem(value: 'date', child: Text('Sort: Joined')),
        DropdownMenuItem(value: 'trust', child: Text('Sort: Trust')),
        DropdownMenuItem(value: 'active', child: Text('Sort: Active')),
      ],
      onChanged: (val) => setState(() => _sortBy = val!),
    );
  }

  Widget _buildUniFilter() {
    // In a real app, this would be fetched from a collection.
    const unis = ['All', 'University of Nairobi', 'Kenyatta University', 'Strathmore', 'Jkuat', 'USIU'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButton<String>(
        value: _selectedUniversity ?? 'All',
        underline: const SizedBox(),
        style: TextStyle(
          fontSize: 12, 
          color: Theme.of(context).colorScheme.onSurface,
        ),
        items: unis.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
        onChanged: (val) => setState(() => _selectedUniversity = val == 'All' ? null : val),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (range != null) {
      setState(() => _dateRange = range);
    }
  }

  Widget _buildUserList(List<AppUser> users) {
    if (users.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: AppColors.grey400),
            SizedBox(height: 16),
            Text('No users found matching your criteria.',
                style: TextStyle(color: AppColors.grey600)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = users[index];
        final isSelected = _selectedIds.contains(user.uid);

        return Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleSelection(user.uid),
            ),
            Expanded(child: _UserListItem(user: user)),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Function(bool) onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _UserListItem extends StatelessWidget {
  final AppUser user;

  const _UserListItem({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        onTap: () => context.push('/admin/users/${user.uid}', extra: user),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: AppColors.primary, size: 16),
                        ],
                        if (user.isAdmin) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(color: Colors.purple, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: const TextStyle(color: AppColors.grey600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (user.isBanned)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'BANNED',
                        style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    )
                  else if (user.isCurrentlySuspended)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'SUSPENDED',
                        style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    Text(
                      'Score: ${user.trustScore.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Joined ${user.createdAt != null ? DateFormat('MMM yyyy').format(user.createdAt!) : "N/A"}',
                    style: const TextStyle(color: AppColors.grey600, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right, color: AppColors.grey400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.primary.withOpacity(0.1),
      backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
      child: user.photoUrl == null
          ? Text(
              user.fullName.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            )
          : null,
    );
  }
}
