import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/core/constants/campus_constants.dart';
import 'package:unihub_mobile/core/location/models/location_data.dart';
import 'package:unihub_mobile/core/widgets/creation_success_dialog.dart';
import '../../domain/models/event.dart';
import '../../domain/models/event_category.dart';
import '../../shared/providers.dart';
import '../controllers/create_event_controller.dart';
import '../widgets/event_card.dart';
import 'event_detail_screen.dart';
import 'package:unihub_mobile/features/ads/ads_module.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  final Event? event;
  final String organizerId;
  final String campusId;

  const CreateEventScreen({
    super.key,
    this.event,
    required this.organizerId,
    required this.campusId,
  });

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final args = (event: widget.event, organizerId: widget.organizerId, campusId: widget.campusId);
    final state = ref.watch(createEventControllerProvider(args));
    final controller = ref.read(createEventControllerProvider(args).notifier);

    // Listen for errors
    ref.listen(createEventControllerProvider(args).select((s) => s.error), (previous, next) {
      if (next != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface, size: 20),
          onPressed: () {
            if (state.currentStep > 0) {
              _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              controller.previousStep();
            } else {
              context.pop();
            }
          },
        ),
        title: Column(
          children: [
            Text(
              state.isEditing ? 'Edit Event' : 'Create Event',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            _buildStepIndicator(state.currentStep),
          ],
        ),
      ),
      body: state.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStep1(state, controller),
              _buildStep2(state, controller),
              _buildStep3(state, controller),
              _buildStep4(state, controller),
              _buildStep5(state, controller),
              _buildStep6(state, controller),
            ],
          ),
      bottomNavigationBar: _buildBottomAction(state, controller),
    );
  }

  Widget _buildStepIndicator(int currentStep) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(6, (index) {
        final bool isActive = index <= currentStep;
        return Container(
          width: 20,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildStep1(CreateEventState state, CreateEventController controller) {
    final categoriesAsync = ref.watch(eventCategoriesProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Basic Information', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Give your event a clear title and category.'),
          const SizedBox(height: 32),
          _buildTextField(
            label: 'Event Title',
            hint: 'e.g. Annual Tech Symposium 2026',
            initialValue: state.title,
            onChanged: controller.updateTitle,
          ),
          const SizedBox(height: 24),
          const Text('Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          categoriesAsync.when(
            data: (cats) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cats.map((cat) {
                final isSelected = state.categoryId == cat.id;
                return ChoiceChip(
                  label: Text('${cat.icon} ${cat.label}'),
                  selected: isSelected,
                  onSelected: (val) => controller.updateCategory(cat.id),
                );
              }).toList(),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Error loading categories'),
          ),
          const SizedBox(height: 24),
          _buildTextField(
            label: 'Description',
            hint: 'Tell students what to expect...',
            initialValue: state.description,
            maxLines: 5,
            onChanged: controller.updateDescription,
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(CreateEventState state, CreateEventController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Date & Time', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 32),
          _buildDateTimePicker(
            label: 'Starts at',
            value: state.startAt,
            onChanged: controller.updateStartAt,
          ),
          const SizedBox(height: 24),
          _buildDateTimePicker(
            label: 'Ends at',
            value: state.endAt,
            onChanged: controller.updateEndAt,
          ),
        ],
      ),
    );
  }

  Widget _buildStep3(CreateEventState state, CreateEventController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Venue', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Campus: ${CampusConstants.getDisplayName(widget.campusId)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 32),
          _buildTextField(
            label: 'Building / Landmark',
            hint: 'e.g. Student Center, Lecture Hall 4',
            initialValue: state.venue?.address,
            onChanged: (val) {
              controller.updateVenue(LocationData(
                latitude: 0, // Placeholder
                longitude: 0,
                address: val,
                campusId: widget.campusId,
              ));
            },
          ),
          const SizedBox(height: 24),
          _buildTextField(
            label: 'Specific Room (Optional)',
            hint: 'e.g. Room 201, Second Floor',
            initialValue: state.venueRoom,
            onChanged: controller.updateVenueRoom,
          ),
        ],
      ),
    );
  }

  Widget _buildStep4(CreateEventState state, CreateEventController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Media', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 32),
          const Text('Cover Image', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => controller.pickImages(),
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: state.selectedImages.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(state.selectedImages.first, fit: BoxFit.cover),
                    )
                  : state.existingImageUrls.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(state.existingImageUrls.first, fit: BoxFit.cover),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Tap to add cover image', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
            ),
          ),
          if (state.selectedImages.isNotEmpty || state.existingImageUrls.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                if (state.selectedImages.isNotEmpty) {
                  controller.removeSelectedImage(state.selectedImages.first);
                } else {
                  controller.removeExistingImage(state.existingImageUrls.first);
                }
              },
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              label: const Text('Remove', style: TextStyle(color: AppColors.error)),
            ),
        ],
      ),
    );
  }

  Widget _buildStep5(CreateEventState state, CreateEventController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Registration', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 32),
          SwitchListTile(
            title: const Text('Registration Required', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Students must RSVP to attend'),
            value: state.isRegistrationRequired,
            onChanged: controller.toggleRegistration,
            contentPadding: EdgeInsets.zero,
          ),
          if (state.isRegistrationRequired) ...[
            const SizedBox(height: 24),
            _buildTextField(
              label: 'External Registration Link (Optional)',
              hint: 'e.g. Google Form or Eventbrite link',
              initialValue: state.registrationUrl,
              onChanged: controller.updateRegistrationUrl,
            ),
            const SizedBox(height: 24),
            _buildTextField(
              label: 'Maximum Capacity (Optional)',
              hint: 'e.g. 100',
              initialValue: state.maxCapacity?.toString(),
              keyboardType: TextInputType.number,
              onChanged: (val) => controller.updateMaxCapacity(int.tryParse(val)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep6(CreateEventState state, CreateEventController controller) {
    // This is the review/preview step
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Preview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          const Text('This is how your event will appear in the feed:'),
          const SizedBox(height: 24),
          Center(
            child: EventCard(
              event: _previewEvent(state),
              index: 0,
            ),
          ),
          const SizedBox(height: 40),
          const Text('Review Information', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildReviewRow('Title', state.title),
          _buildReviewRow('Start', state.startAt != null ? DateFormat('MMM dd, HH:mm').format(state.startAt!) : 'Not set'),
          _buildReviewRow('Venue', state.venue?.address ?? 'Not set'),
          const SizedBox(height: 32),
          const Text(
            'By submitting, you agree to follow Ulify community guidelines. Your event may require admin approval before being published.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Event _previewEvent(CreateEventState state) {
    return Event(
      id: state.id,
      organizerId: state.organizerId,
      campusId: state.campusId,
      title: state.title.isEmpty ? 'Event Title' : state.title,
      description: state.description,
      categoryId: state.categoryId,
      venue: state.venue ?? LocationData(latitude: 0, longitude: 0, address: 'TBA'),
      startAt: state.startAt ?? DateTime.now(),
      endAt: state.endAt ?? DateTime.now().add(const Duration(hours: 2)),
      status: EventStatus.approved, // Show as approved for preview
      createdAt: DateTime.now(),
      createdBy: 'preview',
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTextField({required String label, required String hint, required Function(String) onChanged, String? initialValue, int maxLines = 1, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: initialValue,
          onChanged: onChanged,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimePicker({required String label, required DateTime? value, required Function(DateTime) onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null && mounted) {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(value ?? DateTime.now()),
              );
              if (time != null) {
                onChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value != null ? DateFormat('EEEE, MMM dd, HH:mm').format(value) : 'Select date and time'),
                const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction(CreateEventState state, CreateEventController controller) {
    final theme = Theme.of(context);
    final bool isLastStep = state.currentStep >= 5;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          if (state.currentStep > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  controller.previousStep();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: state.isLoading ? null : () async {
                if (isLastStep) {
                  final success = await controller.submit();
                  if (success && mounted) {
                    // Attempt to show interstitial ad before success dialog
                    ref.read(adServiceProvider).loadInterstitialAd(
                      onAdLoaded: (ad) {
                        ref.read(adServiceProvider).showInterstitialAd(
                          ad,
                          onAdDismissed: () {
                            if (mounted) _showEventSuccessDialog(context);
                          },
                        );
                      },
                      onAdFailedToLoad: (_) {
                        if (mounted) _showEventSuccessDialog(context);
                      },
                    );
                  }
                } else {
                  _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  controller.nextStep();
                }
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isLastStep ? (state.isEditing ? 'Save Changes' : 'Submit Event') : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }

  void _showEventSuccessDialog(BuildContext context) {
    CreationSuccessDialog.show(
      context,
      title: 'Event Submitted!',
      message: 'Your event has been sent for review. You\'ll be notified once it is approved and published.',
    );
  }
}
