import 'package:flutter/material.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('About Ulify'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.school_rounded,
                    color: AppColors.primary,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'About Ulify',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your Campus. Connected.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Welcome to your digital campus home! Ulify is built by students, for students—a comprehensive ecosystem that brings together everything you need for a thriving university life. From finding a cozy bedsitter to selling last semester\'s textbooks, earning money through gigs, sharing study notes, and staying connected with your campus community—all in one secure, trusted space.',
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 16),
            Text(
              'The Reality of Student Life: Between searching multiple WhatsApp groups for housing, asking friends if anyone\'s selling furniture, posting gigs on random platforms, hunting through scattered study materials, and trying to coordinate with sellers across different apps—student life can feel fragmented. You\'re constantly switching between apps, wondering if that listing is genuine, and worrying about safety. It doesn\'t have to be this way.',
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'The Ulify Difference: Why juggle multiple platforms when one trusted app can handle it all? We\'ve created a verified campus marketplace where you can confidently buy, sell, and collaborate. Real student profiles with verification badges mean no more guessing if someone\'s legitimate. Whether you\'re a first-year searching for accommodation, an entrepreneur selling notes, a student offering tutoring services, or someone building study groups with classmates—Ulify is your campus community gateway. Seamless messaging keeps all your campus conversations in one place. Security and transparency aren\'t afterthoughts; they\'re the foundation.',
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 40),
            _buildFeatureSection(
              context,
              Icons.shopping_bag_outlined,
              'Marketplace',
              'Buy and sell smart with verified students.',
              'The student marketplace where smart shopping meets verified trust. List items from your dorm—old furniture, textbooks, phones, accessories—and reach thousands of students looking for quality secondhand goods. Incoming students save money, graduating students clear their rooms, and everyone benefits. Built-in messaging means you negotiate prices and arrange pickups without leaving the app.',
            ),

            _buildFeatureSection(
              context,
              Icons.home_work_outlined,
              'Housing',
              'Find your next home with confidence.',
              'Tired of scams and sketchy listings? Ulify connects you with verified House Plugs who understand the local student housing landscape. Browse hostels, bedsitters, shared apartments, and rentals complete with photos, pricing, and owner contact. Plug verification means you\'re talking to someone the community trusts. Message landlords directly, ask questions, and book with peace of mind.',
            ),

            _buildFeatureSection(
              context,
              Icons.menu_book_outlined,
              'Notes',
              'Learn smarter together.',
              'Why rewrite notes from scratch when your classmate already has them? Share lecture materials, revision guides, past papers, and study summaries that help others ace their exams. Whether you\'re an A-student earning money by selling polished notes or someone prepping last-minute for exams, this is where campus knowledge gets traded. Building a stronger, more collaborative student community, one note at a time.',
            ),

            _buildFeatureSection(
              context,
              Icons.work_outline_rounded,
              'Gigs',
              'Earn, help, and grow your skills.',
              'Post a gig: "Need help moving apartment," "Looking for a design portfolio revamp," or "Offering physics tutoring." Connect with students offering services that match what you need. Flexible, campus-based work where you earn pocket money while studying. Students showcase skills, build experience, and help classmates—all while staying on campus. Hourly jobs, project-based work, and service offerings all in one place.',
            ),

            _buildFeatureSection(
              context,
              Icons.calendar_today_outlined,
              'Events & Clubs',
              'Discover and celebrate campus culture.',
              'Find concerts, workshops, sports tournaments, club meetings, and student-organized events happening on campus. Browse events by category, see who\'s attending, and RSVP instantly. Club leaders can create verified organizer profiles to showcase their mission and manage events seamlessly. Students can discover communities matching their interests—whether it\'s tech clubs, cultural groups, sports teams, or social causes. Build connections, join causes you care about, and never miss out on what\'s happening around you.',
            ),

            _buildFeatureSection(
              context,
              Icons.chat_bubble_outline_rounded,
              'Chat',
              'Talk directly, build relationships.',
              'No more scattered conversations across multiple platforms. Message sellers about that laptop, negotiate housing terms with a landlord, discuss study group plans, or ask a tutor questions—all organized in one inbox. Real-time notifications keep you updated, and conversation history stays with you. Building trust in the campus community starts with clear, direct communication.',
            ),

            _buildFeatureSection(
              context,
              Icons.notifications_none_rounded,
              'Notifications',
              'Never miss out on opportunities.',
              'Get instant alerts when someone interested in your listing messages you, when a roommate match might be available, when someone applies for your posted gig, or when your favorite seller posts new items. Customizable notifications mean you\'re always in the loop without feeling overwhelmed. Stay connected to campus opportunities as they happen.',
            ),

            _buildFeatureSection(
              context,
              Icons.verified_user_outlined,
              'Trust & Verification',
              'Community safety through transparency.',
              'A student selling notes, a landlord renting out apartments, someone offering tutoring—their verification badge tells you they\'ve been authenticated and trusted by the community. No anonymous transactions, no mystery sellers. Our verification system is built on academic email verification and community feedback, making every interaction safer. Trust isn\'t guaranteed; it\'s earned and displayed for everyone to see.',
            ),

            const SizedBox(height: 24),
            _buildSimpleSection(
              context,
              '🎓 Built by Students, for Students',
              'Every feature started with a real problem from campus life. We listened to first-years struggling to find housing, watched seniors scramble to clear their dorms, saw entrepreneurs looking for ways to earn money, and noticed students isolated without proper campus connections. Ulify isn\'t built on assumptions—it\'s built on the lived experiences of thousands of students like you. From day one to graduation day, we\'re here to make campus life simpler, safer, and more connected.',
            ),

            _buildSimpleSection(
              context,
              'Our Vision',
              'To transform campus life by creating the most trusted digital community where students support each other, buy and sell with confidence, collaborate academically, and grow together. Imagine a campus where finding housing is simple, trading items is safe, earning money is accessible, and isolation is a choice—not a reality.',
            ),

            _buildSimpleSection(
              context,
              'Our Mission',
              'To eliminate the friction in student life by bringing together housing, commerce, gigs, learning, and communication into one secure platform. We\'re on a mission to replace scattered WhatsApp groups, dodgy classifieds, and risky transactions with a single app where safety, community, and opportunity go hand in hand.',
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Your Feedback Shapes Our Future',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ulify isn\'t static—it evolves based on what you need. Found a bug? Have a feature idea? Know something that\'s missing? Your campus community makes this platform better every day. We actively listen, iterate, and build features that matter to students like you. Every suggestion counts; every voice matters.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Center(
              child: Text(
                'Ulify Version 1.0',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Center(
              child: Text(
                '© ${DateTime.now().year} Ulify. All rights reserved.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureSection(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    String body,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleSection(BuildContext context, String title, String body) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
