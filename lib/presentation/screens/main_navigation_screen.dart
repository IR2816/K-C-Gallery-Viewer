import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

// Screens
import 'latest_posts_screen.dart';
import 'search_screen_dual.dart';
import 'saved_screen.dart';
import 'settings_screen.dart';
import 'discord_server_screen.dart';

// Theme
import '../theme/app_theme.dart';

/// MainNavigationScreen — Social Media Style Bottom Nav
///
/// Features:
/// - Floating glass pill navigation bar
/// - Gradient selected indicator
/// - Smooth scale + fade animations
/// - Haptic feedback
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  late List<AnimationController> _animControllers;
  late List<Animation<double>> _scaleAnims;

  final List<_NavItem> _navItems = [
    _NavItem(icon: Icons.home_rounded, label: 'Home', color: AppTheme.primaryColor),
    _NavItem(icon: Icons.search_rounded, label: 'Search', color: Color(0xFF00C6AE)),
    _NavItem(icon: Icons.forum_rounded, label: 'Discord', color: Color(0xFF5865F2)),
    _NavItem(icon: Icons.bookmark_rounded, label: 'Saved', color: Color(0xFFFFB300)),
    _NavItem(icon: Icons.settings_rounded, label: 'Settings', color: AppTheme.darkSecondaryTextColor),
  ];

  @override
  void initState() {
    super.initState();
    _animControllers = List.generate(_navItems.length, (i) {
      return AnimationController(duration: const Duration(milliseconds: 220), vsync: this);
    });
    _scaleAnims = _animControllers.map((c) {
      return Tween<double>(begin: 1.0, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOut),
      );
    }).toList();
    _animControllers[0].forward();
  }

  @override
  void dispose() {
    for (final c in _animControllers) c.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.lightImpact();
    _animControllers[_currentIndex].reverse();
    setState(() => _currentIndex = index);
    _animControllers[index].forward();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      extendBody: true,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) {
          if (i != _currentIndex) {
            _animControllers[_currentIndex].reverse();
            setState(() => _currentIndex = i);
            _animControllers[i].forward();
          }
        },
        children: [
          const LatestPostsScreen(),
          const SearchScreenDual(),
          const DiscordServerScreen(),
          SavedScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _buildNavBar(isDark),
    );
  }

  Widget _buildNavBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.xlRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkSurfaceColor.withValues(alpha: 0.90)
                  : Colors.white.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(AppTheme.xlRadius),
              border: Border.all(
                color: isDark
                    ? AppTheme.darkBorderColor.withValues(alpha: 0.6)
                    : AppTheme.lightBorderColor,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 30,
                  spreadRadius: -5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _navItems.asMap().entries.map((e) {
                final i = e.key;
                final item = e.value;
                final selected = i == _currentIndex;
                return _buildNavItem(item, i, selected, isDark);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, int index, bool selected, bool isDark) {
    return GestureDetector(
      onTap: () => _onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [
                    item.color.withValues(alpha: 0.25),
                    item.color.withValues(alpha: 0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(AppTheme.lgRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                item.icon,
                key: ValueKey(selected),
                color: selected
                    ? item.color
                    : (isDark ? AppTheme.darkSecondaryTextColor : AppTheme.lightSecondaryTextColor),
                size: selected ? 26 : 24,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: item.color,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final Color color;
  const _NavItem({required this.icon, required this.label, required this.color});
}

/// Navigation Item Model (kept for compat)
class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;
  const NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
  });
}
