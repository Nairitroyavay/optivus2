import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/services/event_service.dart';
import 'package:optivus2/services/firestore_service.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/views/routine/widgets/photo_picker_button.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. App Bar
                _buildAppBar(context),
                const SizedBox(height: 32),

                // 2. Avatar
                _buildAvatarSection(context, ref),
                const SizedBox(height: 16),

                // 3. Name & Handle
                Text(
                  FirebaseAuth.instance.currentUser?.displayName ?? 'User',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${(FirebaseAuth.instance.currentUser?.email ?? 'user').split('@').first}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: kSub.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 32),

                // 4. Profile insights
                _buildProfileInsights(),
                const SizedBox(height: 24),
                // 7. Account
                _buildSectionHeader('ACCOUNT'),
                const SizedBox(height: 12),
                _buildAccountSettings(context),
                const SizedBox(height: 24),

                // 8. App
                _buildSectionHeader('APP'),
                const SizedBox(height: 12),
                _buildAppSettings(context),
                const SizedBox(height: 24),

                // 9. About
                _buildSectionHeader('ABOUT'),
                const SizedBox(height: 12),
                _buildAboutSettings(),
                const SizedBox(height: 40),

                // 10. Log Out
                _buildLogOutSetting(context),
                const SizedBox(height: 16),

                // 11. Delete Account
                _buildDeleteAccountSetting(context),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return const Center(
      child: Text(
        'PROFILE',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: kSub,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildAvatarSection(BuildContext context, WidgetRef ref) {
    return Center(
      child: FutureBuilder<Map<String, dynamic>?>(
        future: FirestoreService().getProfile(),
        builder: (context, snapshot) {
          final profile = snapshot.data ?? const <String, dynamic>{};
          final rawAvatarMetadata = profile['avatarImage'];
          final avatarMetadata = rawAvatarMetadata is Map
              ? _r2MetadataOnly(rawAvatarMetadata)
              : null;
          final flags = ref.watch(appFeatureFlagsProvider);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glassy rim background
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.8),
                            blurRadius: 8,
                            offset: const Offset(-2, -2),
                          ),
                        ],
                      ),
                    ),
                    // Inner picture
                    ClipOval(
                      child: Image.asset(
                        'assets/images/placeholder_avatar.png',
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 110,
                          height: 110,
                          color: const Color(0xFFEBA587),
                          child: const Center(
                            child: Icon(Icons.person,
                                size: 60, color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              PhotoPickerButton(
                routineType: 'profile',
                initialMetadata: avatarMetadata,
                label: flags.profileImageUploadReady
                    ? 'Change photo'
                    : 'Photo uploads soon',
                onChanged: (metadata) async {
                  await FirestoreService().saveProfile({
                    'avatarImage': _r2MetadataOnly(metadata),
                  });
                },
              ),
            ],
          );
        },
      ),
    );
  }

  static Map<String, dynamic>? _r2MetadataOnly(Map? metadata) {
    if (metadata == null) return null;
    final objectKey = metadata['objectKey']?.toString() ?? '';
    final path = metadata['path']?.toString() ?? objectKey;
    final contentType = metadata['contentType']?.toString() ?? '';
    final provider = metadata['provider']?.toString() ?? '';
    final sizeBytes = metadata['sizeBytes'];
    if (objectKey.isEmpty || path.isEmpty || provider != 'cloudflare_r2') {
      return null;
    }
    return {
      'objectKey': objectKey,
      'path': path,
      if (contentType.isNotEmpty) 'contentType': contentType,
      if (sizeBytes is num) 'sizeBytes': sizeBytes.toInt(),
      'provider': provider,
    };
  }

  Widget _buildProfileInsights() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: FirestoreService().getUserProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data ?? const <String, dynamic>{};
        final onboarding = Map<String, dynamic>.from(
          profile['onboarding'] as Map? ?? const <String, dynamic>{},
        );
        final goals =
            List<String>.from(onboarding['goals'] as List? ?? const []);
        final categories = List<String>.from(
            onboarding['selectedCategories'] as List? ?? const []);
        final badHabits =
            List<String>.from(onboarding['badHabits'] as List? ?? const []);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildIdentityStatement(goals),
            const SizedBox(height: 24),
            _buildSectionHeader('FOCUS AREAS'),
            const SizedBox(height: 12),
            _buildPills(
              values: categories,
              emptyLabel: 'No focus areas selected',
              icon: Icons.track_changes_rounded,
              baseColor: const Color(0xFF4DB685),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('HABITS TO BREAK'),
            const SizedBox(height: 12),
            _buildPills(
              values: badHabits,
              emptyLabel: 'No habits selected',
              icon: Icons.hourglass_empty_rounded,
              baseColor: const Color(0xFFD66A3D),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIdentityStatement(List<String> goals) {
    final text = goals.isEmpty
        ? 'Complete onboarding to define your active identity goals.'
        : 'Working toward ${goals.take(3).join(', ').replaceAll('\n', ' ')}.';

    return LiquidCard(
      frosted: true,
      padding: const EdgeInsets.all(20),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fingerprint_rounded,
                  size: 18, color: const Color(0xFF5577A8)),
              const SizedBox(width: 8),
              Text(
                'IDENTITY STATEMENT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: kSub.withValues(alpha: 0.8),
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: kInk,
              height: 1.5,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: kSub.withValues(alpha: 0.8),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildPills({
    required List<String> values,
    required String emptyLabel,
    required IconData icon,
    required Color baseColor,
  }) {
    if (values.isEmpty) {
      return Text(
        emptyLabel,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: kSub.withValues(alpha: 0.8),
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: values
          .map((value) => _GlassPill(
                icon: icon,
                label: value.replaceAll('\n', ' '),
                baseColor: baseColor,
              ))
          .toList(),
    );
  }

  Widget _buildAccountSettings(BuildContext context) {
    return LiquidCard(
      frosted: true,
      padding: EdgeInsets.zero,
      radius: 20,
      child: Column(
        children: [
          _buildPrefTile(
            icon: Icons.email_outlined,
            iconColor: const Color(0xFF4B8EE3),
            title: 'Email',
          ),
          _buildDivider(),
          _buildPrefTile(
            icon: Icons.star_border_rounded,
            iconColor: const Color(0xFFC48E33),
            title: 'Subscription',
          ),
          _buildDivider(),
          _buildPrefTile(
            icon: Icons.archive_outlined,
            iconColor: const Color(0xFF5E4B9C),
            title: 'Archived identities',
            hasArrow: true,
            onTap: () {
              context.push('/settings/archived-identities');
            },
          ),
          _buildDivider(),
          _buildPrefTile(
            icon: Icons.notifications_outlined,
            iconColor: const Color(0xFF4DB685),
            title: 'Notification',
            hasArrow: true,
            onTap: () {
              context.push('/settings/notifications');
            },
          ),
          _buildDivider(),
          _buildPrefTile(
            icon: Icons.cloud_download_outlined,
            iconColor: const Color(0xFF5E4B9C),
            title: 'Export account data',
            hasArrow: true,
            onTap: () => _handleExportData(context),
          ),
          _buildDivider(),
          _buildPrefTile(
            icon: Icons.lock_outline_rounded,
            iconColor: const Color(0xFFD66A3D),
            title: 'Security',
          ),
        ],
      ),
    );
  }

  Widget _buildAppSettings(BuildContext context) {
    return LiquidCard(
      frosted: true,
      padding: EdgeInsets.zero,
      radius: 20,
      child: Column(
        children: [
          _buildPrefTile(
            icon: Icons.vibration_rounded,
            iconColor: const Color(0xFF4B8EE3),
            title: 'Haptic Feedback',
            trailing: SizedBox(
              height: 38,
              width: 70,
              child: _DualDropToggle(value: true, onChanged: (v) {}),
            ),
          ),
          _buildDivider(),
          _buildPrefTile(
            icon: Icons.spellcheck_rounded,
            iconColor: const Color(0xFFC48E33),
            title: 'Correct spelling automatically',
            trailing: SizedBox(
              height: 38,
              width: 70,
              child: _DualDropToggle(value: true, onChanged: (v) {}),
            ),
          ),
          _buildDivider(),
          _buildPrefTile(
            icon: Icons.settings_suggest_outlined,
            iconColor: const Color(0xFF5E4B9C),
            title: 'Routine Settings',
            hasArrow: true,
            onTap: () {
              context.push('/settings/routine');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSettings() {
    return LiquidCard(
      frosted: true,
      padding: EdgeInsets.zero,
      radius: 20,
      child: Column(
        children: [
          _buildPrefTile(
            icon: Icons.bug_report_outlined,
            iconColor: const Color(0xFFD66A3D),
            title: 'Report bug',
          ),
          _buildDivider(),
          _buildPrefTile(
            icon: Icons.help_outline_rounded,
            iconColor: const Color(0xFF4B8EE3),
            title: 'Help center',
          ),
          _buildDivider(),
          _buildPrefTile(
            icon: Icons.description_outlined,
            iconColor: const Color(0xFF4DB685),
            title: 'Terms of use',
          ),
          _buildDivider(),
          _buildPrefTile(
            icon: Icons.privacy_tip_outlined,
            iconColor: const Color(0xFF5E4B9C),
            title: 'Privacy policy',
          ),
          _buildDivider(),
          _buildPrefTile(
            icon: Icons.info_outline_rounded,
            iconColor: const Color(0xFFC48E33),
            title: 'Version',
            trailing: Text(
              'Optivus v1.0.0',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kSub.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogOutSetting(BuildContext context) {
    return LiquidCard(
      frosted: true,
      padding: EdgeInsets.zero,
      radius: 20,
      child: _buildPrefTile(
        icon: Icons.logout_rounded,
        iconColor: kCoral,
        title: 'Log out',
        hasArrow: false,
        onTap: () async {
          try {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              context.go('/');
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Failed to log out. Please try again.')),
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildDeleteAccountSetting(BuildContext context) {
    return LiquidCard(
      frosted: true,
      padding: EdgeInsets.zero,
      radius: 20,
      child: _buildPrefTile(
        icon: Icons.person_remove_rounded,
        iconColor: Colors.redAccent,
        title: 'Delete account',
        hasArrow: false,
        onTap: () => _handleDeleteAccount(context),
      ),
    );
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final confirmed = await _showDeleteAccountConfirmation(context);
    if (!confirmed || !context.mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (user.email == null || user.email!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account email is missing. Account not deleted.'),
        ),
      );
      return;
    }

    final password = await _showPasswordDialog(context);
    if (password == null || password.isEmpty || !context.mounted) return;

    _showBlockingProgress(context, Colors.redAccent);

    try {
      await _reauthenticateWithPassword(user, password);
      await _performDeletion(user);

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        context.go('/');
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!context.mounted) return;

      var message = 'Failed to delete account: ${e.message ?? e.code}';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Incorrect password. Account not deleted.';
      } else if (e.code == 'requires-recent-login') {
        message = 'Please log out, log back in, and try deleting again.';
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Account was not deleted: $e')),
      );
    }
  }

  Future<void> _performDeletion(User user) async {
    await EventService().emit(
      eventName: EventNames.accountDeleted,
      payload: {
        'uid': user.uid,
        'email': user.email,
      },
      priority: 'high',
    );
    debugPrint(
        '[ProfileTab] ${EventNames.accountDeleted} emitted for ${user.uid}');

    await FirestoreService().deleteUserOwnedData();
    await user.delete();
    await FirebaseAuth.instance.signOut();
  }

  Future<bool> _showDeleteAccountConfirmation(BuildContext context) async {
    final controller = TextEditingController();

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) {
            final canDelete = controller.text.trim() == 'DELETE';

            return AlertDialog(
              backgroundColor: const Color(0xFF1E202A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Delete Account',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This permanently removes your profile and account data from /users/{uid}. This cannot be undone.',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Type DELETE to confirm.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.redAccent,
                    decoration: InputDecoration(
                      hintText: 'DELETE',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                TextButton(
                  onPressed: canDelete ? () => Navigator.pop(ctx, true) : null,
                  child: const Text(
                    'Delete Permanently',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      return confirmed == true;
    } finally {
      controller.dispose();
    }
  }

  Future<void> _reauthenticateWithPassword(User user, String password) async {
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'Account email is missing, so deletion could not be verified.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  void _showBlockingProgress(BuildContext context, Color color) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(child: CircularProgressIndicator(color: color)),
    );
  }

  Future<void> _handleExportData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E202A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Export Account Data',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Generate a JSON export of your profile and account collections.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Export',
              style: TextStyle(
                color: Color(0xFF5E4B9C),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    _showBlockingProgress(context, const Color(0xFF5E4B9C));

    try {
      final jsonString = await FirestoreService().exportUserData();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E202A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Exported Data',
              style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Text(
                jsonString,
                style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'monospace',
                    fontSize: 12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Close', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonString));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
              child: const Text('Copy to Clipboard',
                  style: TextStyle(
                      color: Color(0xFF5E4B9C), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export data: $e')),
      );
    }
  }

  Future<String?> _showPasswordDialog(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E202A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Password',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'For security, please enter your password to confirm account deletion.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.redAccent,
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.lock_outline,
                    color: Colors.white54, size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, null);
            },
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final pass = controller.text;
              Navigator.pop(ctx, pass);
            },
            child: const Text('Confirm',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPrefTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    bool hasArrow = false,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // 3D Glass Bead Icon Container
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Soft underlying tint
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.65),
                    width: 1.2,
                  ),
                  boxShadow: [
                    // Icon-tinted glow
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    // Ambient shadow
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Top-left strong specular highlight (the "wet" reflection)
                    Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        margin: const EdgeInsets.only(left: 4, top: 3),
                        width: 16,
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.95),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Bottom-right inner gloss edge
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        margin: const EdgeInsets.only(right: 2, bottom: 2),
                        width: 22,
                        height: 12,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.5),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // The solid icon
                    Center(
                      child: Icon(icon,
                          size: 18, color: iconColor.withValues(alpha: 0.95)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kInk,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (trailing != null) trailing,
              if (hasArrow && trailing == null)
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: kSub.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: Colors.white.withValues(alpha: 0.15),
      margin: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}

class _DualDropToggle extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _DualDropToggle({required this.value, this.onChanged});

  @override
  State<_DualDropToggle> createState() => _DualDropToggleState();
}

class _DualDropToggleState extends State<_DualDropToggle> {
  late bool _val;

  @override
  void initState() {
    super.initState();
    _val = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _val = !_val);
        widget.onChanged?.call(_val);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 70,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          color: _val
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.15),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              alignment: _val ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: SizedBox(
                  width: 44,
                  height: 30,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDrop(),
                      _buildDrop(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrop() {
    return Container(
      width: 20,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withValues(alpha: 0.4),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.9),
            blurRadius: 2,
            offset: const Offset(-1, -1),
          ),
        ],
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              margin: const EdgeInsets.only(left: 3, top: 3),
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.white, blurRadius: 2)],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              margin: const EdgeInsets.only(right: 2, bottom: 2),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.9),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Glass Pill for Strengths and Areas to Improve
class _GlassPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color baseColor;

  const _GlassPill({
    required this.icon,
    required this.label,
    required this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main pill body
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: baseColor.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: baseColor.withValues(alpha: 0.9)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E242C), // Dark ink
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        // Top-left strong glossy highlight
        Positioned(
          top: 3,
          left: 12,
          child: Container(
            width: 12,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.95),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        // Bottom-right inner glow
        Positioned(
          bottom: 3,
          right: 3,
          child: Container(
            width: 30,
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.5),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
