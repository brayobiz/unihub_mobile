import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/monetization/shared/providers.dart';
import 'package:unihub_mobile/features/monetization/domain/models/subscription_record.dart';

class BusinessUpgradeScreen extends ConsumerStatefulWidget {
  const BusinessUpgradeScreen({super.key});

  @override
  ConsumerState<BusinessUpgradeScreen> createState() => _BusinessUpgradeScreenState();
}

class _BusinessUpgradeScreenState extends ConsumerState<BusinessUpgradeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _handleUpgrade() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = ref.read(appUserProvider).valueOrNull;
      if (user == null) return;

      final monetizationRepo = ref.read(monetizationRepositoryProvider);
      
      // 1. Check uniqueness
      final isUnique = await monetizationRepo.isBusinessNameUnique(_nameController.text.trim());
      if (!isUnique) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This business name is already taken. Please choose another one.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 2. Perform upgrade
      await monetizationRepo.upgradeToBusinessAccount(
        userId: user.uid,
        businessName: _nameController.text.trim(),
        businessCategory: _categoryController.text.trim(),
        tier: SubscriptionTier.businessBasic, // During growth phase, this maps to Pro for free if verified
      );

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Congratulations! Your Business Account is now active. 🚀'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(appUserProvider).valueOrNull;
    final bool isVerified = user?.isIdentityVerified == true || user?.isStudentVerified == true;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Business Upgrade', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHero(context),
            const SizedBox(height: 32),
            Text(
              'Business Profile',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTextField(
                    label: 'Business Name',
                    hint: 'e.g. Mike\'s Electronics',
                    controller: _nameController,
                    icon: Icons.business_rounded,
                    maxLength: 25,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter a name';
                      if (v.length < 3) return 'Name too short';
                      if (v.length > 25) return 'Name too long (max 25)';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Business Category',
                    hint: 'e.g. Retail, Food, Services',
                    controller: _categoryController,
                    icon: Icons.category_outlined,
                    validator: (v) => v == null || v.isEmpty ? 'Please enter a category' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildPerksSection(context),
            const SizedBox(height: 48),
            _buildUpgradeButton(context, isVerified),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, const Color(0xFF19D3C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.business_center_rounded, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Sell Like a Pro',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Unlock advanced tools to manage and grow your campus business.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildPerksSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Business Perks',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildPerkItem(Icons.verified_rounded, 'Business Badge', 'Get a dedicated business verification badge.'),
        const SizedBox(height: 12),
        _buildPerkItem(Icons.rocket_launch_rounded, 'Free Promotions', 'Enjoy free Boosts and Featured slots during our Early Bird phase.'),
        const SizedBox(height: 12),
        _buildPerkItem(Icons.analytics_outlined, 'Sales Insights', 'Track your performance with advanced analytics (Coming Soon).'),
      ],
    );
  }

  Widget _buildPerkItem(IconData icon, String title, String subtitle) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(subtitle, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            counterText: "", // Hide the character counter for a cleaner look
          ),
        ),
      ],
    );
  }

  Widget _buildUpgradeButton(BuildContext context, bool isVerified) {
    final theme = Theme.of(context);
    
    if (!isVerified) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, color: Colors.orange),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Verification required to upgrade to a Business Account.',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => context.push('/trust-center'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Go to Trust Center', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.celebration_rounded, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text(
                'Growth Phase Benefit: Upgrade for FREE!',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleUpgrade,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Active Business Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
