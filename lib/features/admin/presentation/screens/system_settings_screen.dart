import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/system_settings.dart';
import '../../domain/models/admin_stats.dart';
import '../../shared/providers.dart';
import '../layout/admin_layout.dart';

class SystemSettingsScreen extends ConsumerStatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  ConsumerState<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends ConsumerState<SystemSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _supportEmailController;
  late TextEditingController _privacyUrlController;
  late TextEditingController _termsUrlController;
  late TextEditingController _websiteUrlController;
  late TextEditingController _maintenanceMessageController;
  
  final Map<String, TextEditingController> _socialControllers = {};
  
  bool _maintenanceMode = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _supportEmailController = TextEditingController();
    _privacyUrlController = TextEditingController();
    _termsUrlController = TextEditingController();
    _websiteUrlController = TextEditingController();
    _maintenanceMessageController = TextEditingController();
  }

  @override
  void dispose() {
    _supportEmailController.dispose();
    _privacyUrlController.dispose();
    _termsUrlController.dispose();
    _websiteUrlController.dispose();
    _maintenanceMessageController.dispose();
    for (var controller in _socialControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeControllers(SystemSettings settings) {
    if (_isInitialized) return;
    
    _supportEmailController.text = settings.supportEmail;
    _privacyUrlController.text = settings.privacyPolicyUrl;
    _termsUrlController.text = settings.termsOfServiceUrl;
    _websiteUrlController.text = settings.websiteUrl;
    _maintenanceMessageController.text = settings.maintenanceMessage;
    _maintenanceMode = settings.maintenanceMode;
    
    settings.socialLinks.forEach((key, value) {
      _socialControllers[key] = TextEditingController(text: value);
    });
    
    _isInitialized = true;
  }

  Future<void> _saveSettings(SystemSettings currentSettings) async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(appUserProvider).valueOrNull;
    
    final updatedSocialLinks = <String, String>{};
    _socialControllers.forEach((key, controller) {
      if (controller.text.isNotEmpty) {
        updatedSocialLinks[key] = controller.text;
      }
    });

    final updatedSettings = currentSettings.copyWith(
      supportEmail: _supportEmailController.text,
      privacyPolicyUrl: _privacyUrlController.text,
      termsOfServiceUrl: _termsUrlController.text,
      websiteUrl: _websiteUrlController.text,
      maintenanceMode: _maintenanceMode,
      maintenanceMessage: _maintenanceMessageController.text,
      socialLinks: updatedSocialLinks,
      lastUpdated: DateTime.now(),
      updatedBy: user?.fullName ?? 'Unknown Admin',
    );

    try {
      await ref.read(systemSettingsRepositoryProvider).updateSettings(updatedSettings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('System settings updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating settings: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(systemSettingsProvider);
    final statsAsync = ref.watch(adminStatsProvider);

    return AdminLayout(
      title: 'System Settings',
      child: settingsAsync.when(
        data: (settings) {
          _initializeControllers(settings);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('General Information'),
                  _buildInfoCard(settings, statsAsync),
                  const SizedBox(height: 32),
                  
                  _buildSectionHeader('Support & Legal'),
                  _buildSupportLegalSection(),
                  const SizedBox(height: 32),
                  
                  _buildSectionHeader('Official Links'),
                  _buildSocialLinksSection(),
                  const SizedBox(height: 32),
                  
                  _buildSectionHeader('Maintenance Mode'),
                  _buildMaintenanceSection(),
                  const SizedBox(height: 40),
                  
                  SizedBox(
                    width: 200,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _saveSettings(settings),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildInfoCard(SystemSettings settings, AsyncValue<AdminStats> statsAsync) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInfoRow('App Version', settings.appVersion),
            const Divider(height: 24),
            _buildInfoRow('Last Updated', DateFormat('MMM dd, yyyy HH:mm').format(settings.lastUpdated)),
            const Divider(height: 24),
            _buildInfoRow('Updated By', settings.updatedBy),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Platform Status', style: TextStyle(color: AppColors.grey600)),
                statsAsync.when(
                  data: (stats) => Text(
                    '${stats.totalUsers} users • ${stats.totalMarketplaceListings + stats.totalHousingListings + stats.totalNotes} items',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  loading: () => const Text('Loading...'),
                  error: (_, __) => const Text('Error loading stats'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.grey600)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSupportLegalSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextFormField(
              controller: _supportEmailController,
              decoration: const InputDecoration(
                labelText: 'Support Email',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _websiteUrlController,
              decoration: const InputDecoration(
                labelText: 'Website URL',
                prefixIcon: Icon(Icons.language),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _privacyUrlController,
              decoration: const InputDecoration(
                labelText: 'Privacy Policy URL',
                prefixIcon: Icon(Icons.policy_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _termsUrlController,
              decoration: const InputDecoration(
                labelText: 'Terms of Service URL',
                prefixIcon: Icon(Icons.gavel_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialLinksSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSocialField('instagram', 'Instagram', Icons.camera_alt_outlined),
            const SizedBox(height: 16),
            _buildSocialField('twitter', 'Twitter (X)', Icons.alternate_email),
            const SizedBox(height: 16),
            _buildSocialField('facebook', 'Facebook', Icons.facebook_outlined),
            const SizedBox(height: 16),
            _buildSocialField('linkedin', 'LinkedIn', Icons.work_outline),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialField(String key, String label, IconData icon) {
    if (!_socialControllers.containsKey(key)) {
      _socialControllers[key] = TextEditingController();
    }
    return TextFormField(
      controller: _socialControllers[key],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        hintText: 'https://...',
      ),
    );
  }

  Widget _buildMaintenanceSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _maintenanceMode ? AppColors.error : Theme.of(context).dividerColor,
          width: _maintenanceMode ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Enable Maintenance Mode', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('While enabled, only administrators can access the app.'),
              value: _maintenanceMode,
              activeColor: AppColors.error,
              onChanged: (val) => setState(() => _maintenanceMode = val),
            ),
            if (_maintenanceMode) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _maintenanceMessageController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Maintenance Message',
                  hintText: 'Describe why the app is down and when it will be back...',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => _maintenanceMode && v?.isEmpty == true ? 'Required when Maintenance Mode is ON' : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
