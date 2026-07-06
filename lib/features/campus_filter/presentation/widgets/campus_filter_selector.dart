import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/campus_constants.dart';
import '../../domain/models/browsing_scope.dart';
import '../../shared/providers.dart';
import '../../../auth/shared/providers.dart';

class CampusFilterSelector extends ConsumerWidget {
  const CampusFilterSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(browsingScopeProvider);
    final user = ref.watch(appUserProvider).valueOrNull;
    final theme = Theme.of(context);

    String label;
    IconData icon;

    switch (scope.type) {
      case BrowsingScopeType.all:
        label = 'All Campuses';
        icon = Icons.public_rounded;
        break;
      case BrowsingScopeType.myCampus:
        final uniName = CampusConstants.getDisplayName(
          CampusConstants.resolveToId(user?.university)
        );
        label = 'My Campus ($uniName)';
        icon = Icons.school_rounded;
        break;
      case BrowsingScopeType.specific:
        label = CampusConstants.getDisplayName(scope.campusId);
        icon = Icons.location_on_rounded;
        break;
    }

    return InkWell(
      onTap: () => showCampusBottomSheet(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.secondary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  static void showCampusBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CampusSelectionSheet(),
    );
  }
}

class _CampusSelectionSheet extends ConsumerWidget {
  const _CampusSelectionSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentScope = ref.watch(browsingScopeProvider);
    final user = ref.watch(appUserProvider).valueOrNull;
    final notifier = ref.read(browsingScopeProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Browsing Scope',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Select which campus results you want to see.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Options
          _buildOption(
            context: context,
            title: 'My Campus',
            subtitle: CampusConstants.getDisplayName(
              CampusConstants.resolveToId(user?.university)
            ),
            icon: Icons.school_outlined,
            selectedIcon: Icons.school_rounded,
            isSelected: currentScope.type == BrowsingScopeType.myCampus,
            onTap: () {
              notifier.setScope(BrowsingScope.myCampus());
              Navigator.pop(context);
            },
          ),
          
          _buildOption(
            context: context,
            title: 'All Campuses',
            subtitle: 'Show results from everywhere',
            icon: Icons.public_outlined,
            selectedIcon: Icons.public_rounded,
            isSelected: currentScope.type == BrowsingScopeType.all,
            onTap: () {
              notifier.setScope(BrowsingScope.all());
              Navigator.pop(context);
            },
          ),
          
          const Divider(height: 32, indent: 24, endIndent: 24),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'SPECIFIC CAMPUS',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ),
          
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: CampusConstants.campuses.length,
              padding: const EdgeInsets.only(bottom: 32),
              itemBuilder: (context, index) {
                final campus = CampusConstants.campuses[index];
                final isSelected = currentScope.type == BrowsingScopeType.specific && 
                                  currentScope.campusId == campus.id;
                
                return _buildOption(
                  context: context,
                  title: campus.name,
                  icon: Icons.location_on_outlined,
                  selectedIcon: Icons.location_on_rounded,
                  isSelected: isSelected,
                  onTap: () {
                    notifier.setScope(BrowsingScope.specific(campus.id));
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required String title,
    String? subtitle,
    required IconData icon,
    required IconData selectedIcon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.secondary.withOpacity(0.1) 
              : theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected ? AppColors.secondary : theme.colorScheme.onSurfaceVariant,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          color: isSelected ? AppColors.secondary : theme.colorScheme.onSurface,
        ),
      ),
      subtitle: subtitle != null 
          ? Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ) 
          : null,
      trailing: isSelected 
          ? const Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 20)
          : null,
    );
  }
}
