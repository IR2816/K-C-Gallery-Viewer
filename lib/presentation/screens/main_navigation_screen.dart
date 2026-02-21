import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Screens
import 'latest_posts_screen.dart';
import 'search_screen_dual.dart';
import 'saved_screen.dart';
import 'settings_screen.dart';
import 'discord_server_screen.dart';

// Theme
import '../theme/app_theme.dart';

/// 🎯 CONSOLIDATED MainNavigationScreen - Clean Navigation Hub
///
/// Features:
/// - ✅ Enhanced bottom navigation with animations
/// - ✅ Persistent state management
/// - ✅ Smooth transitions
/// - ✅ AppTheme consistency
/// - ✅ Haptic feedback
/// - ✅ Route delegation to consolidated screens
/// - ✅ Clean navigation structure
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with TickerProviderStateMixin {
  // Navigation State
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  // Animation Controllers
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _animations;

  // Navigation Items
  final List<NavigationItem> _navItems = [
    NavigationItem(
      icon: Icons.article,
      activeIcon: Icons.article,
      label: 'Home',
      color: Colors.blue,
    ),
    NavigationItem(
      icon: Icons.search,
      activeIcon: Icons.search,
      label: 'Search',
      color: Colors.green,
    ),
    NavigationItem(
      icon: Icons.dns,
      activeIcon: Icons.dns,
      label: 'Discord',
      color: Colors.purple,
    ),
    NavigationItem(
      icon: Icons.bookmark,
      activeIcon: Icons.bookmark,
      label: 'Saved',
      color: Colors.orange,
    ),
    NavigationItem(
      icon: Icons.settings,
      activeIcon: Icons.settings,
      label: 'Settings',
      color: Colors.grey,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _disposeAnimations();
    _pageController.dispose();
    super.dispose();
  }

  // 🎯 INITIALIZATION
  void _initializeAnimations() {
    _animationControllers = List.generate(
      _navItems.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      ),
    );

    _animations = _animationControllers.map((controller) {
      return Tween<double>(
        begin: 1.0,
        end: 1.2,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }).toList();

    // Start with first item animated
    _animationControllers[0].forward();
  }

  void _disposeAnimations() {
    for (final controller in _animationControllers) {
      controller.dispose();
    }
  }

  // 🎯 BUILD METHOD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
          _updateAnimations(index);
        },
        children: [
          // Home Screen - Latest Posts
          const LatestPostsScreen(),

          // Search Screen (DUAL: Name + ID Search)
          const SearchScreenDual(),

          // Discord Screen - Kemono Discord Servers
          const DiscordServerScreen(),

          // Saved Screen
          SavedScreen(),

          // Settings Screen
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // 🎯 WIDGET BUILDERS

  /// Enhanced Bottom Navigation Bar
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.smPadding,
            vertical: AppTheme.xsPadding,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _navItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == _currentIndex;

              return GestureDetector(
                onTap: () => _onBottomNavTap(index),
                child: AnimatedBuilder(
                  animation: _animations[index],
                  builder: (context, child) {
                    return Transform.scale(
                      scale: isSelected ? _animations[index].value : 1.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.mdPadding,
                          vertical: AppTheme.smPadding,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? item.color.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            AppTheme.mdRadius,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon
                            Icon(
                              isSelected ? item.activeIcon : item.icon,
                              color: isSelected
                                  ? item.color
                                  : AppTheme.getOnSurfaceColor(context),
                              size: 24,
                            ),
                            const SizedBox(height: 4),

                            // Label
                            Text(
                              item.label,
                              style: AppTheme.captionStyle.copyWith(
                                color: isSelected
                                    ? item.color
                                    : AppTheme.getOnSurfaceColor(context),
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // 🎯 ACTION METHODS

  /// Handle bottom navigation tap
  void _onBottomNavTap(int index) {
    if (index == _currentIndex) return;

    HapticFeedback.lightImpact();

    // Animate previous item
    _animationControllers[_currentIndex].reverse();

    // Update selected index
    setState(() {
      _currentIndex = index;
    });

    // Animate new item
    _animationControllers[_currentIndex].forward();

    // Navigate to page
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Update animations based on current index
  void _updateAnimations(int newIndex) {
    // Reset all animations
    for (int i = 0; i < _animationControllers.length; i++) {
      if (i == newIndex) {
        _animationControllers[i].forward();
      } else {
        _animationControllers[i].reverse();
      }
    }
  }
}

/// Navigation Item Model
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
