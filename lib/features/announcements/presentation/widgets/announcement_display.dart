import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/models/announcement.dart';
import '../../shared/providers.dart';

class RelevantAnnouncementsWidget extends ConsumerWidget {
  final String? feature;

  const RelevantAnnouncementsWidget({super.key, this.feature});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeAnnouncementsProvider);
    
    return activeAsync.when(
      data: (_) {
        final announcements = ref.watch(relevantAnnouncementsProvider(feature));
        final dismissed = ref.watch(dismissedAnnouncementsProvider);
        
        // Filter out dismissed announcements
        final visible = announcements.where((a) => !dismissed.contains(a.id)).toList();
        if (visible.isEmpty) return const SizedBox.shrink();

        // Sort by priority and then by date
        final sorted = List<Announcement>.from(visible);
        sorted.sort((a, b) {
          final priorityDiff = b.priority.index.compareTo(a.priority.index);
          if (priorityDiff != 0) return priorityDiff;
          return b.publishAt.compareTo(a.publishAt);
        });

        // Modal Logic: Find first modal announcement that hasn't been shown in session yet
        final sessionShown = ref.watch(sessionShownModalsProvider);
        
        final pendingModals = sorted.where((a) => 
          a.displayStyle == AnnouncementDisplayStyle.modal && 
          !dismissed.contains(a.id) &&
          !sessionShown.contains(a.id)
        ).toList();

        if (pendingModals.isNotEmpty) {
          final targetModal = pendingModals.first;
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Mark as shown in session immediately to avoid duplicate triggers
            ref.read(sessionShownModalsProvider.notifier).update((s) => {...s, targetModal.id});
            _showFullModal(context, ref, targetModal);
          });
        }

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: sorted.map<Widget>((a) => _AnnouncementItem(announcement: a, key: ValueKey(a.id))).toList(),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) {
        if (kDebugMode) {
          debugPrint('📣 Announcement System Error: $err');
        }
        return const SizedBox.shrink();
      },
    );
  }

  void _showFullModal(BuildContext context, WidgetRef ref, Announcement a) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.campaign_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w900))),
          ],
        ),
        content: Text(a.content, style: const TextStyle(fontSize: 15, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(dismissedAnnouncementsProvider.notifier).dismiss(a.id);
              Navigator.pop(context);
            },
            child: const Text('Close & Don\'t show again', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementItem extends ConsumerStatefulWidget {
  final Announcement announcement;

  const _AnnouncementItem({super.key, required this.announcement});

  @override
  ConsumerState<_AnnouncementItem> createState() => _AnnouncementItemState();
}

class _AnnouncementItemState extends ConsumerState<_AnnouncementItem> with TickerProviderStateMixin {
  bool _dismissed = false;
  
  late AnimationController _entryController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late AnimationController _attentionController;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
    ));

    _attentionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _attentionController, curve: Curves.easeInOutSine),
    );

    _floatAnimation = Tween<double>(begin: 0.0, end: 4.0).animate(
      CurvedAnimation(parent: _attentionController, curve: Curves.easeInOutSine),
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _attentionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final a = widget.announcement;
    final isPriority = a.priority == AnnouncementPriority.critical || a.priority == AnnouncementPriority.high;

    Widget child;
    switch (a.displayStyle) {
      case AnnouncementDisplayStyle.modal:
        child = _buildBanner(context, a);
        break;
      case AnnouncementDisplayStyle.card:
        child = _buildCard(context, a);
        break;
      case AnnouncementDisplayStyle.sticky:
      case AnnouncementDisplayStyle.banner:
      default:
        child = _buildBanner(context, a);
        break;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedBuilder(
            animation: _attentionController,
            builder: (context, child) {
              return Transform.translate(
                offset: isPriority ? Offset(0, -_floatAnimation.value) : Offset.zero,
                child: child,
              );
            },
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildBanner(BuildContext context, Announcement a) {
    final isCritical = a.priority == AnnouncementPriority.critical;
    final isHigh = a.priority == AnnouncementPriority.high;

    List<Color> gradientColors;
    IconData icon;
    String tagText = 'UPDATE';

    if (isCritical) {
      gradientColors = [const Color(0xFFDC2626), const Color(0xFF991B1B)];
      icon = Icons.bolt_rounded;
      tagText = 'URGENT';
    } else if (isHigh) {
      gradientColors = [const Color(0xFFF59E0B), const Color(0xFFD97706)];
      icon = Icons.campaign_rounded;
      tagText = 'IMPORTANT';
    } else {
      gradientColors = [AppColors.primary, AppColors.secondary];
      icon = Icons.info_rounded;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            
            AnimatedBuilder(
              animation: _attentionController,
              builder: (context, child) {
                return Positioned.fill(
                  child: FractionallySizedBox(
                    widthFactor: 0.3,
                    alignment: Alignment(_shimmerAnimation.value, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(0.2),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  _PulseIcon(icon: icon, isCritical: isCritical),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tagText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                a.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          a.content,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    onPressed: () {
                      ref.read(dismissedAnnouncementsProvider.notifier).dismiss(a.id);
                      setState(() => _dismissed = true);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, Announcement a, {bool isCritical = false}) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCritical ? AppColors.error.withOpacity(0.05) : theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCritical ? AppColors.error : theme.dividerColor,
          width: isCritical ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCritical ? Icons.report_problem : Icons.campaign,
                color: isCritical ? AppColors.error : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  a.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isCritical ? AppColors.error : null,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  ref.read(dismissedAnnouncementsProvider.notifier).dismiss(a.id);
                  setState(() => _dismissed = true);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            a.content,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _PulseIcon extends StatefulWidget {
  final IconData icon;
  final bool isCritical;

  const _PulseIcon({required this.icon, required this.isCritical});

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
            boxShadow: widget.isCritical ? [
              BoxShadow(
                color: Colors.white.withOpacity(0.2 * _controller.value),
                blurRadius: 10 * _controller.value,
                spreadRadius: 4 * _controller.value,
              )
            ] : null,
          ),
          child: Icon(
            widget.icon,
            color: Colors.white,
            size: 20,
          ),
        );
      },
    );
  }
}
