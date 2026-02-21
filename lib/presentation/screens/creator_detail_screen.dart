import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

// Domain
import '../../domain/entities/creator.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/api_source.dart';
import '../../domain/entities/discord_server.dart';
import '../../domain/repositories/kemono_repository.dart';

// Providers
import '../providers/posts_provider.dart';
import '../providers/creators_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tag_filter_provider.dart';

// Theme
import '../theme/app_theme.dart';

// Screens
import 'post_detail_screen.dart';
import 'fullscreen_media_viewer.dart';
import 'video_player_screen.dart';
import 'discord_channel_list_screen.dart';

/// Creator Detail Screen - Clean & Simple
///
/// Design Principles:
/// - Single source of truth (PostsProvider)
/// - Compact utility header (not hero header)
/// - Simple grid layout for media
/// - No linkify in preview (PostDetail job)
/// - Consistent with PostDetail patterns
class CreatorDetailScreen extends StatefulWidget {
  final Creator creator;
  final ApiSource apiSource;

  const CreatorDetailScreen({
    super.key,
    required this.creator,
    required this.apiSource,
  });

  @override
  State<CreatorDetailScreen> createState() => _CreatorDetailScreenState();
}

class _CreatorDetailScreenState extends State<CreatorDetailScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  // Core Controllers
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  final ScrollController _postsScrollController = ScrollController();
  final ScrollController _mediaScrollController = ScrollController();

  // Minimal State (Single Source of Truth: PostsProvider)
  double _postsScrollOffset = 0.0;
  double _mediaScrollOffset = 0.0;

  // Media cache (performance optimization)
  List<Map<String, dynamic>> _cachedMediaItems = [];
  String? _mediaCacheKey;
  final Map<String, Future<Size>> _imageSizeCache = {};
  Future<List<_LinkedAccount>>? _linkedAccountsFuture;

  // State preservation
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadCreatorPosts();
    _linkedAccountsFuture = _fetchLinkedAccounts();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _scrollController.dispose();
    _postsScrollController.dispose();
    _mediaScrollController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    // Save current scroll position
    if (_tabController.indexIsChanging) return;

    if (_tabController.previousIndex == 0) {
      _postsScrollOffset = _postsScrollController.offset;
    } else if (_tabController.previousIndex == 1) {
      _mediaScrollOffset = _mediaScrollController.offset;
    }

    // Restore scroll position after tab change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tabController.index == 0 && _postsScrollOffset > 0) {
        _postsScrollController.animateTo(
          _postsScrollOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else if (_tabController.index == 1 && _mediaScrollOffset > 0) {
        _mediaScrollController.animateTo(
          _mediaScrollOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // SIMPLIFIED - Single responsibility: just trigger provider
  Future<void> _loadCreatorPosts() async {
    try {

      final postsProvider = Provider.of<PostsProvider>(context, listen: false);
      postsProvider.clearPosts();
      _cachedMediaItems = [];
      _mediaCacheKey = null;

      await postsProvider.loadCreatorPosts(
        widget.creator.service,
        widget.creator.id,
        refresh: true,
      );
    } catch (e) {
      // Error handling done by provider, no local state needed
    }
  }

  Future<List<_LinkedAccount>> _fetchLinkedAccounts() async {
    try {
      final repository = context.read<KemonoRepository>();
      final rawLinks = await repository.getCreatorLinks(
        widget.creator.service,
        widget.creator.id,
        apiSource: widget.apiSource,
      );
      return rawLinks
          .whereType<Map>()
          .map((e) => _LinkedAccount.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // PERFORMANCE OPTIMIZATION - Cache media items once per posts snapshot
  void _ensureMediaCache(List<Post> visiblePosts) {
    final key = visiblePosts.isEmpty
        ? 'empty'
        : '${visiblePosts.length}|${visiblePosts.last.id}';
    if (_mediaCacheKey == key) return;
    _cachedMediaItems = [];

    for (final post in visiblePosts) {
      // Add attachments
      for (final attachment in post.attachments) {
        if (_isImageFile(attachment.name)) {
          _cachedMediaItems.add({
            'type': 'image',
            'url': _buildFullUrl(attachment.path),
            'thumbnail': _buildThumbnailUrl(attachment.path),
            'name': attachment.name,
            'postId': post.id,
          });
        } else if (_isVideoFile(attachment.name)) {
          _cachedMediaItems.add({
            'type': 'video',
            'url': _buildFullUrl(attachment.path),
            'name': attachment.name,
            'postId': post.id,
            'thumbnail': _buildFullUrl(
              attachment.path.replaceFirst(RegExp(r'\.[^.]+$'), '.jpg'),
            ), // Try to get thumbnail
          });
        }
      }

      // Add files
      for (final file in post.file) {
        if (_isImageFile(file.name)) {
          _cachedMediaItems.add({
            'type': 'image',
            'url': _buildFullUrl(file.path),
            'thumbnail': _buildThumbnailUrl(file.path),
            'name': file.name,
            'postId': post.id,
          });
        } else if (_isVideoFile(file.name)) {
          _cachedMediaItems.add({
            'type': 'video',
            'url': _buildFullUrl(file.path),
            'name': file.name,
            'postId': post.id,
            'thumbnail': _buildFullUrl(
              file.path.replaceFirst(RegExp(r'\.[^.]+$'), '.jpg'),
            ), // Try to get thumbnail
          });
        }
      }
    }

    _mediaCacheKey = key;
  }

  bool _isImageFile(String filename) {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    return imageExtensions.any((ext) => filename.toLowerCase().endsWith(ext));
  }

  bool _isVideoFile(String filename) {
    final videoExtensions = [
      '.mp4',
      '.avi',
      '.mov',
      '.wmv',
      '.flv',
      '.webm',
      '.mkv',
    ];
    return videoExtensions.any((ext) => filename.toLowerCase().endsWith(ext));
  }

  ApiSource _apiSourceForService(String service) {
    const coomerServices = {'onlyfans', 'fansly', 'candfans'};
    return coomerServices.contains(service.toLowerCase())
        ? ApiSource.coomer
        : ApiSource.kemono;
  }

  String _buildLinkedBannerUrl(String service, String creatorId) {
    final apiSource = _apiSourceForService(service);
    final base = apiSource == ApiSource.coomer
        ? 'https://img.coomer.st'
        : 'https://img.kemono.cr';
    return '$base/banners/$service/$creatorId';
  }

  String _buildLinkedIconUrl(String service, String creatorId) {
    final apiSource = _apiSourceForService(service);
    final base = apiSource == ApiSource.coomer
        ? 'https://img.coomer.st'
        : 'https://img.kemono.cr';
    return '$base/icons/$service/$creatorId';
  }

  bool _isNsfwPost(Post post) {
    if (post.tags.isEmpty) return false;
    final tags = post.tags.map((t) => t.toLowerCase()).toList();
    return tags.any(
      (tag) =>
          tag.contains('nsfw') ||
          tag.contains('r18') ||
          tag.contains('adult') ||
          tag.contains('explicit') ||
          tag.contains('18+'),
    );
  }

  List<Post> _filterPosts(
    List<Post> posts, {
    required bool hideNsfw,
    required Set<String> blockedTags,
  }) {
    if (!hideNsfw && blockedTags.isEmpty) return posts;

    return posts.where((post) {
      if (hideNsfw && _isNsfwPost(post)) return false;
      if (blockedTags.isEmpty) return true;
      return !blockedTags.any(
        (blockedTag) => post.tags.any(
          (postTag) => postTag.toLowerCase().contains(blockedTag),
        ),
      );
    }).toList();
  }

  Future<Size> _getImageSize(String imageUrl) {
    return _imageSizeCache.putIfAbsent(imageUrl, () {
      final completer = Completer<Size>();
      final image = Image(
        image: CachedNetworkImageProvider(
          imageUrl,
          headers: _getCoomerHeaders(imageUrl),
        ),
      );

      image.image
          .resolve(const ImageConfiguration())
          .addListener(
            ImageStreamListener(
              (info, _) {
                if (!completer.isCompleted) {
                  completer.complete(
                    Size(
                      info.image.width.toDouble(),
                      info.image.height.toDouble(),
                    ),
                  );
                }
              },
              onError: (error, stackTrace) {
                if (!completer.isCompleted) {
                  completer.complete(const Size(1.0, 1.0));
                }
              },
            ),
          );

      return completer.future;
    });
  }

  // FIXED - Use ApiSource instead of service string
  String _buildFullUrl(String path) {
    if (path.startsWith('http')) {
      return path;
    }

    final domain = widget.apiSource == ApiSource.coomer
        ? 'https://n2.coomer.st'
        : 'https://kemono.cr';

    return '$domain/data$path';
  }

  String _buildThumbnailUrl(String path) {
    final clean = path.startsWith('/') ? path : '/$path';
    final base = widget.apiSource == ApiSource.coomer
        ? 'https://img.coomer.st'
        : 'https://img.kemono.cr';
    return '$base/thumbnail/data$clean';
  }

  /// ðŸš€ NEW: Build creator banner URL
  String _buildCreatorBannerUrl({
    required ApiSource apiSource,
    required String service,
    required String creatorId,
  }) {
    final base = apiSource == ApiSource.coomer
        ? 'https://img.coomer.st'
        : 'https://img.kemono.cr';

    return '$base/banners/$service/$creatorId';
  }

  /// ðŸš€ NEW: Build creator icon URL
  String _buildCreatorIconUrl({
    required ApiSource apiSource,
    required String service,
    required String creatorId,
  }) {
    final base = apiSource == ApiSource.coomer
        ? 'https://img.coomer.st'
        : 'https://img.kemono.cr';

    return '$base/icons/$service/$creatorId';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: Consumer<PostsProvider>(
        builder: (context, postsProvider, _) {
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              // âœ… FIXED: SliverAppBar dengan banner di flexible space
              _buildCompactSliverAppBar(),

              // Simple Tabs
              _buildTabs(),

              // Tab Content - Single Source of Truth
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPostsTab(postsProvider),
                    _buildMediaTab(postsProvider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompactSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      floating: false,
      backgroundColor: AppTheme.getSurfaceColor(context),
      foregroundColor: AppTheme.getOnSurfaceColor(context),
      elevation: 0,
      expandedHeight: 200, // Banner (120) + AppBar space (80)
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: AppTheme.getOnSurfaceColor(context),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      // âŒ REMOVE: Title di AppBar (double dengan FlexibleSpaceBar)
      actions: [
        // Bookmark Button (only main action in AppBar)
        Consumer<CreatorsProvider>(
          builder: (context, creatorsProvider, child) {
            // Check if creator is in favorites list
            final isFavorited = creatorsProvider.favoriteCreators.contains(
              widget.creator.id,
            );
            return IconButton(
              icon: Icon(
                isFavorited ? Icons.bookmark : Icons.bookmark_border,
                color: isFavorited
                    ? AppTheme.primaryColor
                    : AppTheme.getOnSurfaceColor(context),
              ),
              onPressed: () => _toggleBookmark(creatorsProvider),
              tooltip: isFavorited ? 'Remove from Saved' : 'Add to Saved',
            );
          },
        ),

        // Open in Browser (utility action)
        IconButton(
          icon: Icon(
            Icons.open_in_browser,
            color: AppTheme.getOnSurfaceColor(context),
          ),
          onPressed: _openCreatorInBrowser,
          tooltip: 'Open in Browser',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(
          left: 76,
          bottom: 16,
        ), // Space untuk avatar
        title: Text(
          widget.creator.name,
          style: AppTheme.getTitleStyle(context).copyWith(
            color: AppTheme.getOnSurfaceColor(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        background: Stack(
          children: [
            // ðŸš€ NEW: Creator Banner sebagai background
            _buildCreatorBanner(),

            // Gradient overlay untuk text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),

            // ðŸš€ NEW: Creator Avatar di flexible space
            Positioned(left: 16, bottom: 8, child: _buildCreatorAvatar()),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.article_outlined), text: 'Posts'),
            Tab(icon: Icon(Icons.photo_library_outlined), text: 'Media'),
          ],
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.secondaryTextColor,
          indicatorColor: AppTheme.primaryColor,
        ),
      ),
    );
  }

  /// ðŸš€ UPDATED: Build creator banner widget (untuk FlexibleSpaceBar)
  Widget _buildCreatorBanner() {
    final bannerUrl = _buildCreatorBannerUrl(
      apiSource: widget.apiSource,
      service: widget.creator.service,
      creatorId: widget.creator.id,
    );

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: CachedNetworkImage(
        imageUrl: bannerUrl,
        fit: BoxFit.cover,
        // ðŸš€ FIX: Add HTTP headers for Coomer CDN anti-hotlink protection
        httpHeaders: _getCoomerHeaders(bannerUrl),
        errorWidget: (context, url, error) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.1),
                  AppTheme.primaryColor.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.image,
                size: 48,
                color: AppTheme.secondaryTextColor,
              ),
            ),
          );
        },
        placeholder: (context, url) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.1),
                  AppTheme.primaryColor.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryColor,
              ),
            ),
          );
        },
      ),
    );
  }

  /// ðŸš€ NEW: Build creator avatar widget
  Widget _buildCreatorAvatar() {
    final iconUrl = _buildCreatorIconUrl(
      apiSource: widget.apiSource,
      service: widget.creator.service,
      creatorId: widget.creator.id,
    );

    return CircleAvatar(
      radius: 24, // Sedikit lebih besar untuk flexible space
      backgroundColor: AppTheme.getSurfaceColor(context),
      backgroundImage: CachedNetworkImageProvider(
        iconUrl,
        // ðŸš€ FIX: Add HTTP headers for Coomer CDN anti-hotlink protection
        headers: _getCoomerHeaders(iconUrl),
      ),
      onBackgroundImageError: (error, stackTrace) {
        // Error handled by fallback child
      },
      child: Icon(Icons.person, color: AppTheme.secondaryTextColor, size: 24),
    );
  }

  /// ðŸš€ NEW: Get HTTP headers for Coomer CDN anti-hotlink protection
  Map<String, String>? _getCoomerHeaders(String imageUrl) {
    final isCoomerDomain =
        imageUrl.contains('coomer.st') || imageUrl.contains('img.coomer.st');

    if (isCoomerDomain) {
      return const {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'image/avif,image/webp,image/*,*/*;q=0.8',
        'Referer': 'https://coomer.st/',
        'Origin': 'https://coomer.st',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
      };
    }

    return null; // No headers needed for non-Coomer domains
  }

  // SIMPLIFIED - Single Source of Truth from PostsProvider
  Widget _buildPostsTab(PostsProvider postsProvider) {
    final settings = context.watch<SettingsProvider>();
    final blockedTags = context.watch<TagFilterProvider>().blacklist;
    final visiblePosts = _filterPosts(
      postsProvider.posts,
      hideNsfw: settings.hideNsfw,
      blockedTags: blockedTags,
    );
    if (postsProvider.isLoading && postsProvider.posts.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (postsProvider.error != null && postsProvider.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.getErrorColor(context),
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading posts',
              style: AppTheme.getTitleStyle(
                context,
              ).copyWith(color: AppTheme.getErrorColor(context)),
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text(
                postsProvider.error!,
                style: AppTheme.getCaptionStyle(
                  context,
                ).copyWith(color: AppTheme.getErrorColor(context)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadCreatorPosts(),
              child: const Text('Retry'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Go Back',
                style: TextStyle(color: AppTheme.secondaryTextColor),
              ),
            ),
          ],
        ),
      );
    }

    if (visiblePosts.isEmpty && !postsProvider.isLoading) {
      final hasActiveFilters = settings.hideNsfw || blockedTags.isNotEmpty;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: AppTheme.getOnSurfaceColor(context),
            ),
            const SizedBox(height: 16),
            Text(
              hasActiveFilters ? 'No posts match your filters' : 'No posts yet',
              style: AppTheme.getTitleStyle(
                context,
              ).copyWith(color: AppTheme.secondaryTextColor),
            ),
            const SizedBox(height: 8),
            Text(
              hasActiveFilters
                  ? 'Try changing filters in Settings'
                  : 'This creator hasn\'t posted anything yet',
              style: AppTheme.getCaptionStyle(
                context,
              ).copyWith(color: AppTheme.secondaryTextColor),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: RefreshIndicator(
        onRefresh: () => _loadCreatorPosts(),
        child: CustomScrollView(
          controller: _postsScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (_linkedAccountsFuture != null)
              SliverToBoxAdapter(child: _buildLinkedAccountsSection()),

            // Simple header info (no fake pagination)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _buildPostsHeaderText(
                          visiblePosts.length,
                          postsProvider.posts.length,
                          postsProvider.hasMore,
                        ),
                        style: AppTheme.getCaptionStyle(
                          context,
                        ).copyWith(color: AppTheme.getOnSurfaceColor(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == visiblePosts.length &&
                        postsProvider.isLoading) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      );
                    }

                    final post = visiblePosts[index];
                    return _buildPostCard(post);
                  },
                  childCount:
                      visiblePosts.length + (postsProvider.isLoading ? 1 : 0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Media Tab - Masonry layout to respect image aspect ratio
  Widget _buildMediaTab(PostsProvider postsProvider) {
    final settings = context.watch<SettingsProvider>();
    final blockedTags = context.watch<TagFilterProvider>().blacklist;
    final visiblePosts = _filterPosts(
      postsProvider.posts,
      hideNsfw: settings.hideNsfw,
      blockedTags: blockedTags,
    );

    _ensureMediaCache(visiblePosts);
    if (postsProvider.isLoading && postsProvider.posts.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.primaryColor,
        ),
      );
    }

    if (postsProvider.error != null && postsProvider.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.getErrorColor(context),
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading media',
              style: AppTheme.getTitleStyle(
                context,
              ).copyWith(color: AppTheme.getErrorColor(context)),
            ),
            const SizedBox(height: 8),
            Text(
              postsProvider.error!,
              style: AppTheme.getCaptionStyle(
                context,
              ).copyWith(color: AppTheme.getErrorColor(context)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadCreatorPosts(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_cachedMediaItems.isEmpty && !postsProvider.isLoading) {
      final hasActiveFilters = settings.hideNsfw || blockedTags.isNotEmpty;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: AppTheme.getOnSurfaceColor(context),
            ),
            const SizedBox(height: 16),
            Text(
              hasActiveFilters
                  ? 'No media matches your filters'
                  : 'No media yet',
              style: AppTheme.getTitleStyle(
                context,
              ).copyWith(color: AppTheme.secondaryTextColor),
            ),
            const SizedBox(height: 8),
            Text(
              hasActiveFilters
                  ? 'Try changing filters in Settings'
                  : 'This creator hasn\'t posted any media yet',
              style: AppTheme.getCaptionStyle(
                context,
              ).copyWith(color: AppTheme.secondaryTextColor),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadCreatorPosts(),
      child: MasonryGridView.count(
        controller: _mediaScrollController,
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        itemCount: _cachedMediaItems.length,
        itemBuilder: (context, index) {
          final mediaItem = _cachedMediaItems[index];
          return _buildMediaGridItem(mediaItem);
        },
      ),
    );
  }

  Widget _buildLinkedAccountsSection() {
    return FutureBuilder<List<_LinkedAccount>>(
      future: _linkedAccountsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final links = snapshot.data ?? const [];
        if (links.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.link,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Linked Accounts',
                    style: AppTheme.getTitleStyle(context).copyWith(
                      color: AppTheme.getOnSurfaceColor(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Column(
                children: links
                    .map((link) => _buildLinkedAccountCard(link))
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLinkedAccountCard(_LinkedAccount link) {
    final serviceColor = _getServiceColor(link.service);
    final bannerUrl = _buildLinkedBannerUrl(link.service, link.id);
    final iconUrl = _buildLinkedIconUrl(link.service, link.id);
    final subtitle = link.publicId != null && link.publicId!.isNotEmpty
        ? '@${link.publicId}'
        : link.name;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (link.service.toLowerCase() == 'discord') {
              final serverName = link.name.isNotEmpty
                  ? link.name
                  : (link.publicId ?? link.id);
              final server = DiscordServer(
                id: link.id,
                name: serverName,
                indexed: DateTime.now(),
                updated: DateTime.now(),
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DiscordChannelListScreen(server: server),
                ),
              );
              return;
            }
            final creator = Creator(
              id: link.id,
              service: link.service,
              name: link.name.isNotEmpty ? link.name : (link.publicId ?? link.id),
              indexed: 0,
              updated: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreatorDetailScreen(
                  creator: creator,
                  apiSource: _apiSourceForService(link.service),
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 96,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: bannerUrl,
                      httpHeaders: _getCoomerHeaders(bannerUrl),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: serviceColor.withValues(alpha: 0.15),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              serviceColor.withValues(alpha: 0.3),
                              Colors.black.withValues(alpha: 0.6),
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
                  Positioned(
                    top: 8,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: serviceColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        link.service.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: iconUrl,
                              httpHeaders: _getCoomerHeaders(iconUrl),
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Center(
                                child: Text(
                                  link.name.isNotEmpty
                                      ? link.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                link.name.isNotEmpty ? link.name : link.id,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getServiceColor(String service) {
    switch (service.toLowerCase()) {
      case 'patreon':
        return Colors.orange;
      case 'fanbox':
      case 'pixiv_fanbox':
        return Colors.blue;
      case 'fantia':
        return Colors.purple;
      case 'onlyfans':
        return Colors.pink;
      case 'fansly':
        return Colors.teal;
      case 'candfans':
        return Colors.red;
      case 'gumroad':
        return Colors.green;
      case 'afdian':
        return Colors.teal;
      case 'boosty':
        return Colors.red;
      case 'subscribestar':
        return Colors.amber;
      case 'dlsite':
        return Colors.indigo;
      case 'discord':
        return Colors.blueGrey;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _buildPostsHeaderText(
    int visibleCount,
    int totalCount,
    bool hasMore,
  ) {
    final status = hasMore ? ' â€¢ Loading more...' : ' â€¢ All loaded';
    if (visibleCount == totalCount) {
      return '$visibleCount posts$status';
    }
    final hiddenCount = totalCount - visibleCount;
    return '$visibleCount posts â€¢ $hiddenCount hidden$status';
  }

  // SIMPLIFIED Media Grid Item - No shadow, consistent ratio
  Widget _buildMediaGridItem(Map<String, dynamic> mediaItem) {
    return GestureDetector(
      onTap: () {
        // Find the index of this media item in the cached list
        final index = _cachedMediaItems.indexWhere(
          (item) => item['url'] == mediaItem['url'],
        );

        if (index != -1) {
          final isVideo = mediaItem['type'] == 'video';
          if (isVideo) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerScreen(
                  videoUrl: mediaItem['url'],
                  videoName: mediaItem['name'] ?? 'Video',
                  apiSource: widget.apiSource.name,
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FullscreenMediaViewer(
                  mediaItems: _cachedMediaItems,
                  initialIndex: index,
                  apiSource: widget.apiSource,
                ),
              ),
            );
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Stack(
          children: [
            // Media content
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildMediaContent(mediaItem),
            ),

            // Type indicator overlay
            if (mediaItem['type'] == 'video')
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),

            // Hover/tap hint
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.transparent,
                ),
                child: const Center(
                  child: Icon(
                    Icons.fullscreen,
                    color: Colors.white54,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build media content (image or video thumbnail)
  Widget _buildMediaContent(Map<String, dynamic> mediaItem) {
    final settings = context.watch<SettingsProvider>();
    final imageFit = settings.imageFitMode;
    if (mediaItem['type'] == 'video') {
      // For videos, show thumbnail if available, otherwise show placeholder
      if (mediaItem['thumbnail'] != null) {
        return AspectRatio(
          aspectRatio: 16.0 / 9.0,
          child: CachedNetworkImage(
            imageUrl: mediaItem['thumbnail'],
            fit: BoxFit.cover,
            errorWidget: (context, error, stackTrace) {
              return _buildVideoPlaceholder();
            },
            placeholder: (context, url) {
              return _buildLoadingPlaceholder();
            },
          ),
        );
      } else {
        return AspectRatio(
          aspectRatio: 16.0 / 9.0,
          child: _buildVideoPlaceholder(),
        );
      }
    } else {
      final rawUrl = mediaItem['url'] as String;
      final thumbnailUrl = mediaItem['thumbnail'] as String?;
      final displayUrl =
          settings.loadThumbnails &&
                  thumbnailUrl != null &&
                  thumbnailUrl.isNotEmpty
              ? thumbnailUrl
              : rawUrl;
      return FutureBuilder<Size>(
        future: _getImageSize(displayUrl),
        builder: (context, snapshot) {
          final aspectRatio = snapshot.hasData
              ? snapshot.data!.width / snapshot.data!.height
              : 1.0;
          final safeRatio = aspectRatio.isFinite && aspectRatio > 0
              ? aspectRatio
              : 1.0;

          return AspectRatio(
            aspectRatio: safeRatio,
            child: CachedNetworkImage(
              imageUrl: displayUrl,
              fit: imageFit,
              errorWidget: (context, error, stackTrace) {
                if (displayUrl != rawUrl) {
                  return CachedNetworkImage(
                    imageUrl: rawUrl,
                    fit: imageFit,
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white54,
                          size: 32,
                        ),
                      ),
                    ),
                  );
                }
                return Container(
                  color: Colors.grey[800],
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 32,
                    ),
                  ),
                );
              },
              placeholder: (context, url) {
                return _buildLoadingPlaceholder();
              },
            ),
          );
        },
      );
    }
  }

  // Build video placeholder
  Widget _buildVideoPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_outline, color: Colors.white54, size: 32),
            SizedBox(height: 4),
            Text(
              'Video',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // Build loading placeholder
  Widget _buildLoadingPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      ),
    );
  }

  bool _handleScrollNotification(ScrollNotification scrollInfo) {
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);

    if (scrollInfo is ScrollEndNotification &&
        postsProvider.hasMore &&
        !postsProvider.isLoading &&
        scrollInfo.metrics.extentAfter < 500) {
      // Trigger load more in provider
      postsProvider.loadCreatorPosts(
        widget.creator.service,
        widget.creator.id,
        refresh: false,
      );
      return true;
    }
    return false;
  }

  Widget _buildPostCard(Post post) {
    final hasMedia = post.attachments.isNotEmpty || post.file.isNotEmpty;
    final mediaCount = post.attachments.length + post.file.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.getSurfaceColor(context),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        onTap: () => _navigateToPostDetail(post),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                post.title.isNotEmpty ? post.title : 'Untitled Post',
                style: AppTheme.titleStyle.copyWith(
                  color: AppTheme.getOnBackgroundColor(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // Date and media info
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: AppTheme.getOnSurfaceColor(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(post.published),
                    style: TextStyle(
                      color: AppTheme.getOnSurfaceColor(context),
                      fontSize: 12,
                    ),
                  ),
                  if (hasMedia) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.photo,
                      size: 16,
                      color: AppTheme.getOnSurfaceColor(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$mediaCount media',
                      style: TextStyle(
                        color: AppTheme.getOnSurfaceColor(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),

              // Content preview (NO LINKIFY - PostDetail job)
              if (post.content.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _cleanHtmlContent(post.content),
                  style: AppTheme.bodyStyle.copyWith(
                    color: AppTheme.getOnSurfaceColor(context),
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // HELPER METHODS
  void _toggleBookmark(CreatorsProvider creatorsProvider) async {
    try {
      // Check current state before toggling
      final isCurrentlyFavorited = creatorsProvider.favoriteCreators.contains(
        widget.creator.id,
      );

      // Create creator object for toggle
      final creator = widget.creator.copyWith(favorited: !isCurrentlyFavorited);

      await creatorsProvider.toggleFavorite(creator);
      if (!mounted) return;

      // Check new state after toggling
      final isNowFavorited = creatorsProvider.favoriteCreators.contains(
        widget.creator.id,
      );

      final message = isNowFavorited ? 'Added to Saved' : 'Removed from Saved';
      final backgroundColor = isNowFavorited ? Colors.green : Colors.orange;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isNowFavorited ? Icons.bookmark : Icons.bookmark_border,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(message),
            ],
          ),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Failed to save creator: $e'),
            ],
          ),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openCreatorInBrowser() async {
    final url = _buildCreatorUrl();
    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  String _buildCreatorUrl() {
    final domain = widget.apiSource == ApiSource.coomer
        ? 'https://n2.coomer.st'
        : 'https://kemono.cr';

    return '$domain/${widget.creator.service}/user/${widget.creator.id}';
  }

  void _navigateToPostDetail(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PostDetailScreen(post: post, apiSource: widget.apiSource),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day} ${_getMonthName(date.month)} ${date.year}';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  /// Clean HTML tags from content (NO LINKIFY)
  String _cleanHtmlContent(String content) {
    try {
      // Parse HTML properly
      final document = html_parser.parse(content);
      String cleanText = document.body?.text ?? content;

      // Clean up extra whitespace and newlines
      cleanText = cleanText.replaceAll(RegExp(r'\s+'), ' ').trim();

      // Remove common HTML entities
      cleanText = cleanText
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&amp;', '&')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'");

      return cleanText;
    } catch (e) {
      // Fallback: simple regex cleaning
      String cleanText = content.replaceAll(RegExp(r'<[^>]*>'), '');
      cleanText = cleanText.replaceAll(RegExp(r'\s+'), ' ').trim();
      return cleanText;
    }
  }
}

// Helper class for persistent header
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _TabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppTheme.getSurfaceColor(context), child: _tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return false;
  }
}

class _LinkedAccount {
  final String id;
  final String name;
  final String service;
  final String? publicId;
  final int? relationId;

  const _LinkedAccount({
    required this.id,
    required this.name,
    required this.service,
    this.publicId,
    this.relationId,
  });

  factory _LinkedAccount.fromJson(Map<String, dynamic> json) {
    return _LinkedAccount(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      service: json['service']?.toString() ?? '',
      publicId: json['public_id']?.toString(),
      relationId: json['relation_id'] as int?,
    );
  }
}
