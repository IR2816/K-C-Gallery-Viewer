import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Domain
import '../../domain/entities/discord_server.dart';
import '../../domain/entities/discord_channel.dart';

// Providers
import '../../providers/discord_provider.dart';
import '../providers/settings_provider.dart';

// Theme
import '../theme/app_theme.dart';
import '../widgets/app_state_widgets.dart';

// Screens
import 'discord_channel_posts_screen.dart';

/// Discord Channel List Screen
/// Shows channels for a specific Discord server with modern UI
class DiscordChannelListScreen extends StatefulWidget {
  final DiscordServer server;

  const DiscordChannelListScreen({super.key, required this.server});

  @override
  State<DiscordChannelListScreen> createState() =>
      _DiscordChannelListScreenState();
}

class _DiscordChannelListScreenState extends State<DiscordChannelListScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  Timer? _searchDebounce;
  String _searchQuery = '';
  String _pendingQuery = '';

  @override
  void initState() {
    super.initState();

    // Animation setup
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    // Load channels for this server
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiscordProvider>().loadChannels(widget.server.id);
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _pendingQuery = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = _pendingQuery.toLowerCase();
      });
    });
  }

  void _openChannel(DiscordChannel channel) {
    HapticFeedback.lightImpact();

    if (channel.canOpen) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              DiscordChannelPostsScreen(
                channelId: channel.id,
                channelName: channel.name,
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                  ),
              child: child,
            );
          },
        ),
      );
    } else {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This channel has no posts or cannot be opened',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF1E1F22) : AppTheme.getBackgroundColor(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Custom App Bar with Server Info
          _buildSliverAppBar(),

          // Search Bar
          SliverToBoxAdapter(child: _buildSearchBar()),

          // Channels List
          Consumer<DiscordProvider>(
            builder: (context, provider, child) {
              if (provider.isLoadingChannels) {
                return SliverFillRemaining(child: _buildLoadingState());
              }

              if (provider.channelsError != null) {
                return SliverFillRemaining(
                  child: _buildErrorState(provider.channelsError!, () {
                    provider.loadChannels(widget.server.id);
                  }),
                );
              }

              final settings = context.watch<SettingsProvider>();
              final channels = _searchQuery.isEmpty
                  ? provider.channels
                  : provider.channels
                      .where((channel) =>
                          channel.name.toLowerCase().contains(_searchQuery))
                      .toList();
              final visibleChannels = settings.hideNsfw
                  ? channels.where((c) => !c.isNsfw).toList()
                  : channels;

              if (visibleChannels.isEmpty) {
                return SliverFillRemaining(
                  child: _searchQuery.isEmpty
                      ? _buildEmptyState()
                      : _buildNoSearchResults(),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final channel = visibleChannels[index];
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, 0.3),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _fadeController,
                                curve: Interval(
                                  (index / channels.length) * 0.5,
                                  0.8 + (index / channels.length) * 0.2,
                                  curve: Curves.easeOut,
                                ),
                              ),
                            ),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildChannelCard(channel),
                        ),
                      ),
                    );
                  }, childCount: visibleChannels.length),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final bannerUrl = _buildDiscordBannerUrl(widget.server.id);
    final iconUrl = _buildDiscordIconUrl(widget.server.id);
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppTheme.getSurfaceColor(context),
      foregroundColor: AppTheme.getOnSurfaceColor(context),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: bannerUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                ),
                errorWidget: (context, url, error) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.7),
                        AppTheme.primaryColor.withValues(alpha: 0.4),
                        AppTheme.getSurfaceColor(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.lgPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Server Icon
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedNetworkImage(
                          imageUrl: iconUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Icon(
                            Icons.discord,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Server Name
                    Text(
                      widget.server.name,
                      style: AppTheme.getTitleStyle(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Server Info
                    Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Discord Server',
                          style: AppTheme.getBodyStyle(
                            context,
                          ).copyWith(color: Colors.white.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh, color: AppTheme.getOnSurfaceColor(context)),
          onPressed: () {
            context.read<DiscordProvider>().loadChannels(widget.server.id);
            HapticFeedback.lightImpact();
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search channels...',
          hintStyle: AppTheme.getBodyStyle(
            context,
          ).copyWith(color: AppTheme.secondaryTextColor),
          prefixIcon: Icon(Icons.search, color: AppTheme.secondaryTextColor),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: AppTheme.secondaryTextColor),
                  onPressed: () {
                    _onSearchChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        style: AppTheme.getBodyStyle(
          context,
        ).copyWith(color: AppTheme.getOnSurfaceColor(context)),
      ),
    );
  }

  Widget _buildChannelCard(DiscordChannel channel) {
    final isDisabled = !channel.canOpen;
    final baseColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2B2D31)
        : AppTheme.getSurfaceColor(context);
    final accentColor = const Color(0xFF5865F2);

    if (channel.isCategory) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(
              Icons.folder_open,
              size: 16,
              color: AppTheme.secondaryTextColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                channel.name.toUpperCase(),
                style: AppTheme.getCaptionStyle(context).copyWith(
                  color: AppTheme.secondaryTextColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: channel.canOpen ? () => _openChannel(channel) : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDisabled ? baseColor.withValues(alpha: 0.6) : baseColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    channel.displayEmoji.isNotEmpty ? channel.displayEmoji : '#',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '# ${channel.name}',
                            style: AppTheme.getBodyStyle(context).copyWith(
                              color: isDisabled
                                  ? AppTheme.getOnSurfaceColor(context)
                                      .withValues(alpha: 0.6)
                                  : AppTheme.getOnSurfaceColor(context),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!channel.canOpen)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Empty',
                              style: TextStyle(
                                color: Colors.orange[600],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (channel.isNsfw)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'NSFW',
                              style: AppTheme.getCaptionStyle(context).copyWith(
                                color: Colors.red[600],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (channel.postCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        channel.postCount > 999
                            ? '${(channel.postCount / 1000).toStringAsFixed(1)}k'
                            : '${channel.postCount}',
                        style: AppTheme.getCaptionStyle(context).copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.chevron_right,
                    color: isDisabled
                        ? AppTheme.secondaryTextColor
                        : accentColor,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const AppSkeletonList(
      itemCount: 6,
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
    );
  }

  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return AppErrorState(
      title: 'Error Loading Channels',
      message: error,
      onRetry: onRetry,
    );
  }

  Widget _buildEmptyState() {
    return const AppEmptyState(
      icon: Icons.chat_bubble_outline,
      title: 'No Channels Found',
      message: 'This server doesn\'t have any channels available.',
    );
  }

  Widget _buildNoSearchResults() {
    return AppEmptyState(
      icon: Icons.search_off,
      title: 'No Channels Found',
      message: 'No channels match "$_searchQuery"',
      actionLabel: 'Clear Search',
      onAction: () => _onSearchChanged(''),
    );
  }

  String _buildDiscordBannerUrl(String serverId) {
    return 'https://img.kemono.cr/banners/discord/$serverId';
  }

  String _buildDiscordIconUrl(String serverId) {
    return 'https://img.kemono.cr/icons/discord/$serverId';
  }
}
