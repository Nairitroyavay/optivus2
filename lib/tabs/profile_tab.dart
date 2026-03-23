import 'package:flutter/material.dart';
import '../core/liquid_ui.dart';
import 'routine_settings_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. App Bar
                      _buildAppBar(context),
                      const SizedBox(height: 32),
                      
                      // 2. Avatar
                      _buildAvatarSection(),
                      const SizedBox(height: 16),
                      
                      // 3. Name & Handle
                      const Text(
                        'Nairit',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: kInk,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@nairit_optivus',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: kSub.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // 4. Identity Statement
                      _buildIdentityStatement(),
                      const SizedBox(height: 24),
                      
                      // 5. Strengths
                      _buildSectionHeader('STRENGTHS'),
                      const SizedBox(height: 12),
                      _buildStrengths(),
                      const SizedBox(height: 24),
                      
                      // 6. Areas to Improve
                      _buildSectionHeader('AREAS TO IMPROVE'),
                      const SizedBox(height: 12),
                      _buildAreasToImprove(),
                      const SizedBox(height: 24),
                      // 7. Account
                      _buildSectionHeader('ACCOUNT'),
                      const SizedBox(height: 12),
                      _buildAccountSettings(),
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
                      _buildLogOutSetting(),
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

  Widget _buildAvatarSection() {
    return Center(
      child: SizedBox(
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 3),
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
                'assets/images/placeholder_avatar.png', // Fallback gracefully if not found
                width: 110,
                height: 110,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 110,
                  height: 110,
                  color: const Color(0xFFEBA587), // Matches image background roughly
                  child: const Center(
                    child: Icon(Icons.person, size: 60, color: Colors.white70),
                  ),
                ),
              ),
            ),
            // Edit button on bottom right
            Positioned(
              bottom: 4,
              right: 8,
              child: LiquidIconBtn(
                icon: Icons.edit_rounded,
                size: 36,
                color: const Color(0xFF5589BD), // Exactly matching the blue pencil in the image
                isCircle: true,
                onTap: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityStatement() {
    return LiquidCard(
      frosted: true,
      padding: const EdgeInsets.all(20),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fingerprint_rounded, size: 18, color: const Color(0xFF5577A8)),
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
          const Text(
            '"Optimizing life through clarity and purpose. Driven by data, fueled by ambition."',
            style: TextStyle(
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

  Widget _buildStrengths() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _GlassPill(
          icon: Icons.bolt_rounded,
          label: 'Strategic',
          baseColor: const Color(0xFF4DB685),
        ),
        _GlassPill(
          icon: Icons.track_changes_rounded,
          label: 'Focused',
          baseColor: const Color(0xFF4DB685),
        ),
        _GlassPill(
          icon: Icons.lightbulb_outline_rounded,
          label: 'Creative',
          baseColor: const Color(0xFF4DB685),
        ),
      ],
    );
  }

  Widget _buildAreasToImprove() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _GlassPill(
          icon: Icons.hourglass_empty_rounded,
          label: 'Impatient',
          baseColor: const Color(0xFFD66A3D),
        ),
        _GlassPill(
          icon: Icons.accessibility_new_rounded,
          label: 'Perfectionist',
          baseColor: const Color(0xFFD66A3D),
        ),
      ],
    );
  }

  Widget _buildAccountSettings() {
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
            hasArrow: true,
          ),
          _buildDivider(),
          _buildPrefTile(
            icon: Icons.star_border_rounded,
            iconColor: const Color(0xFFC48E33),
            title: 'Subscription',
            hasArrow: true,
          ),
          _buildDivider(),
          _buildPrefTile(
            icon: Icons.notifications_outlined,
            iconColor: const Color(0xFF4DB685),
            title: 'Notification',
            hasArrow: true,
          ),
          _buildDivider(),
          _buildPrefTile(
            icon: Icons.cloud_download_outlined,
            iconColor: const Color(0xFF5E4B9C),
            title: 'Export data to data control',
            hasArrow: true,
          ),
          _buildDivider(),
          _buildPrefTile(
            icon: Icons.lock_outline_rounded,
            iconColor: const Color(0xFFD66A3D),
            title: 'Security',
            hasArrow: true,
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
            title: 'Routine Setting',
            hasArrow: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RoutineSettingsScreen()),
              );
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
            hasArrow: true,
          ),
          _buildDivider(),
          _buildPrefTile(
            icon: Icons.help_outline_rounded,
            iconColor: const Color(0xFF4B8EE3),
            title: 'Help center',
            hasArrow: true,
          ),
          _buildDivider(),
          _buildPrefTile(
            icon: Icons.description_outlined,
            iconColor: const Color(0xFF4DB685),
            title: 'Terms of use',
            hasArrow: true,
          ),
          _buildDivider(),
          _buildPrefTile(
            icon: Icons.privacy_tip_outlined,
            iconColor: const Color(0xFF5E4B9C),
            title: 'Privacy policy',
            hasArrow: true,
          ),
          _buildDivider(),
          _buildPrefTile(
            icon: Icons.info_outline_rounded,
            iconColor: const Color(0xFFC48E33),
            title: 'Version',
            trailing: Text(
              'Optivus v2.4.0',
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

  Widget _buildLogOutSetting() {
    return LiquidCard(
      frosted: true,
      padding: EdgeInsets.zero,
      radius: 20,
      child: _buildPrefTile(
        icon: Icons.logout_rounded,
        iconColor: kCoral,
        title: 'Log out',
        hasArrow: false,
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
    return InkWell(
      onTap: onTap ?? () {},
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
                    child: Icon(icon, size: 18, color: iconColor.withValues(alpha: 0.95)),
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
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: kSub.withValues(alpha: 0.6)),
          ],
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
          color: _val ? Colors.white.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.15),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1),
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
