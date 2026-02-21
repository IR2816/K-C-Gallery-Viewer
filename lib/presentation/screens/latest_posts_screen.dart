import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/api_source.dart';
import '../../domain/entities/creator.dart';
import '../providers/posts_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tag_filter_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_state_widgets.dart';
import '../utils/media_preview_resolver.dart';
import 'post_detail_screen.dart';
import 'creator_detail_screen.dart';
import 'download_manager_screen.dart';

/// Latest Posts Screen - Quick Update Feed
class LatestPostsScreen extends StatefulWidget {
  const LatestPostsScreen({super.key});

  @override
  State<LatestPostsScreen> createState() => _LatestPostsScreenState();
}

class _LatestPostsScreenState extends State<LatestPostsScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isLoadingMore = false;
  List<Post> _posts = [];
  String? _error;
  bool _hasMore = true;
  String _selectedService = 'kemono';
  List<String> _blockedTags = [];
  final Map<String, List<Map<String, dynamic>>> _postMediaCache = {};
  final Map<String, String> _postMediaCacheKeys = {};
  SettingsProvider? _settingsProvider;
  TagFilterProvider? _tagFilterProvider;
  int _currentPage = 1;
  static const int _pageSize = 24;

  // Memory management constants
  static const int _maxPostsInMemory = 300;
  static const int _memoryCleanupThreshold = 360; // Start cleanup at 360 posts

  @override
  bool get wantKeepAlive => _posts.length < 100; // Limit keep alive to prevent memory bloat

  /// Memory management: Clean up old posts when list gets too large
  void _manageMemoryUsage() {
    if (_posts.length > _memoryCleanupThreshold) {
      final excessCount = _posts.length - _maxPostsInMemory;
      _posts.removeRange(0, excessCount);
      _syncPostMediaCache();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadInitialPosts();
    _loadFilterState();
    _settingsProvider = context.read<SettingsProvider>();
    _tagFilterProvider = context.read<TagFilterProvider>();
    _settingsProvider?.addListener(_onSettingsChanged);
    _tagFilterProvider?.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settingsProvider?.removeListener(_onSettingsChanged);
    _tagFilterProvider?.removeListener(_onSettingsChanged);
    _scrollController.dispose();

    // Clean up image cache to free memory
    PaintingBinding.instance.imageCache.clear();

    // Clear posts list to free memory
    _posts.clear();
    _postMediaCache.clear();
    _postMediaCacheKeys.clear();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    final postsProvider = context.read<PostsProvider>();
    final newService = _settingsProvider?.defaultApiSource.name ?? 'kemono';
    final shouldReload = newService != _selectedService;
    setState(() {
      _selectedService = newService;
      _blockedTags = _tagFilterProvider?.blacklist.toList() ?? [];
      _posts = _getFilteredPosts(postsProvider.posts);
      _currentPage = 1;
    });
    if (shouldReload) {
      _loadInitialPosts();
    }
  }

  Future<void> _loadFilterState() async {
    final tagFilter = context.read<TagFilterProvider>();
    final settings = context.read<SettingsProvider>();

    setState(() {
      _selectedService = settings.defaultApiSource.name;
      _blockedTags = tagFilter.blacklist.toList();
    });
  }

  Future<void> _loadInitialPosts() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _hasMore = true;
      _isLoadingMore = false;
      _currentPage = 1;
    });

    try {
      final postsProvider = context.read<PostsProvider>();
      await postsProvider.loadLatestPosts(
        refresh: true,
        apiSource: _currentApiSource,
      );

      if (mounted) {
        setState(() {
          _posts = _getFilteredPosts(postsProvider.posts);
          _manageMemoryUsage(); // Clean up memory after initial load
          _isLoading = false;
          _hasMore = postsProvider.hasMore;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final postsProvider = context.read<PostsProvider>();
      await postsProvider.loadMorePosts();

      if (mounted) {
        final newPosts = _getFilteredPosts(postsProvider.posts);
        final existingIds = _posts.map((p) => p.id).toSet();
        final uniqueNewPosts = newPosts
            .where((p) => !existingIds.contains(p.id))
            .toList();
        final hasMoreFromProvider = postsProvider.hasMore;

        setState(() {
          if (uniqueNewPosts.isNotEmpty) {
            _posts.addAll(uniqueNewPosts);
          }
          _manageMemoryUsage(); // Clean up memory after adding new posts
          _isLoadingMore = false;
          _hasMore = hasMoreFromProvider;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _error = e.toString();
        });
      }
    }
  }

  List<Post> _getFilteredPosts(List<Post> posts) {
    final hideNsfw = context.read<SettingsProvider>().hideNsfw;
    final shouldFilterTags = _blockedTags.isNotEmpty;
    if (!hideNsfw && !shouldFilterTags) return posts;

    final filteredPosts = posts.where((post) {
      if (hideNsfw && _isNsfwPost(post)) return false;
      if (!shouldFilterTags) return true;
      return !_blockedTags.any(
        (blockedTag) => post.tags.any(
          (postTag) => postTag.toLowerCase().contains(blockedTag.toLowerCase()),
        ),
      );
    }).toList();

    return filteredPosts;
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

  bool _hasBlockedTags(Post post) {
    final tagFilterProvider = context.read<TagFilterProvider>();
    final blockedTags = tagFilterProvider.blacklist;

    if (blockedTags.isEmpty) return false;

    for (final blockedTag in blockedTags) {
      if (post.title.toLowerCase().contains(blockedTag.toLowerCase())) {
        return true;
      }
    }

    for (final blockedTag in blockedTags) {
      if (post.content.toLowerCase().contains(blockedTag.toLowerCase())) {
        return true;
      }
    }

    if (post.tags.isNotEmpty) {
      for (final postTag in post.tags) {
        for (final blockedTag in blockedTags) {
          if (postTag.toLowerCase().contains(blockedTag.toLowerCase())) {
            return true;
          }
        }
      }
    }

    return false;
  }

  ApiSource get _currentApiSource => ApiSource.values.firstWhere(
        (a) => a.name == _selectedService,
      );

  void _syncPostMediaCache() {
    final ids = _posts.map((p) => p.id).toSet();
    _postMediaCache.removeWhere((key, _) => !ids.contains(key));
    _postMediaCacheKeys.removeWhere((key, _) => !ids.contains(key));
  }

  List<Map<String, dynamic>> _getPostMediaItems(Post post) {
    final key = '${post.id}|${post.file.length}|${post.attachments.length}';
    if (_postMediaCacheKeys[post.id] == key) {
      return _postMediaCache[post.id] ?? const [];
    }

    final mediaItems = <Map<String, dynamic>>[];
    final apiSource =
        post.service == 'onlyfans' ||
                post.service == 'fansly' ||
                post.service == 'candfans'
            ? 'coomer'
            : 'kemono';

    for (final file in post.file) {
      final fullUrl = _buildFullUrl(file.path, post.service);
      final thumbnailUrl = _getThumbnailUrl(fullUrl, apiSource);
      mediaItems.add({
        'type': 'image',
        'url': fullUrl,
        'name': file.name,
        'thumbnail_url': thumbnailUrl,
      });
    }

    for (final attachment in post.attachments) {
      final fullUrl = _buildFullUrl(attachment.path, post.service);
      final thumbnailUrl = _getThumbnailUrl(fullUrl, apiSource);
      final isVideo =
          attachment.name.toLowerCase().endsWith('.mp4') == true ||
          attachment.name.toLowerCase().endsWith('.webm') == true ||
          attachment.name.toLowerCase().endsWith('.mov') == true;

      mediaItems.add({
        'type': isVideo ? 'video' : 'image',
        'url': fullUrl,
        'name': attachment.name,
        'thumbnail_url': thumbnailUrl,
      });
    }

    // Deduplicate by URL to avoid double counts (some posts repeat same file)
    final seenUrls = <String>{};
    final deduped = <Map<String, dynamic>>[];
    for (final item in mediaItems) {
      final url = item['url'] as String? ?? '';
      if (url.isEmpty) continue;
      if (seenUrls.add(url)) {
        deduped.add(item);
      }
    }

    mediaItems.sort(
      (a, b) => (a['name'] as String).compareTo(b['name'] as String),
    );

    deduped.sort(
      (a, b) => (a['name'] as String).compareTo(b['name'] as String),
    );

    _postMediaCache[post.id] = deduped;
    _postMediaCacheKeys[post.id] = key;
    return deduped;
  }

  void _navigateToPostDetail(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(
          post: post,
          apiSource: _currentApiSource,
        ),
      ),
    );
  }

  void _navigateToCreatorDetail(Creator creator) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatorDetailScreen(
          creator: creator,
          apiSource: _currentApiSource,
        ),
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFilterBottomSheet(),
    );
  }

  String _cleanHtmlContent(String content) {
    try {
      final cleanText = content
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return cleanText;
    } catch (e) {
      return content;
    }
  }

  String _getServiceDisplayName(String service) {
    switch (service.toLowerCase()) {
      case 'patreon':
        return 'Patreon';
      case 'fanbox':
        return 'Fanbox';
      case 'fantia':
        return 'Fantia';
      case 'onlyfans':
        return 'OnlyFans';
      case 'fansly':
        return 'Fansly';
      case 'candfans':
        return 'CandFans';
      default:
        return service.toUpperCase();
    }
  }

  Color _getServiceColor(String service) {
    switch (service.toLowerCase()) {
      case 'patreon':
        return Colors.orange;
      case 'fanbox':
        return Colors.blue;
      case 'fantia':
        return Colors.purple;
      case 'onlyfans':
        return Colors.pink;
      case 'fansly':
        return Colors.teal;
      case 'candfans':
        return Colors.red;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day} ${_getMonthName(date.month)}';
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

  String _normalizeTitle(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  int _getTitleMaxLines({
    required int textLength,
    required int columnCount,
    required bool isCompact,
  }) {
    int lines;
    if (isCompact) {
      lines = columnCount == 1 ? 3 : 2;
    } else {
      lines = columnCount == 1 ? 4 : (columnCount == 2 ? 3 : 2);
    }

    if (columnCount == 1 && textLength > 140) {
      lines += 1;
    }

    return lines.clamp(1, 5);
  }

  double _getTitleFontSize({
    required int textLength,
    required int columnCount,
    required bool isCompact,
  }) {
    double size = isCompact ? 13 : 14;
    if (columnCount >= 3) {
      size -= 1;
    }
    if (textLength > 140) {
      size -= 1;
    }
    if (textLength > 200) {
      size -= 1;
    }
    return size.clamp(11, 16);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: _buildTopAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadInitialPosts,
        child: Column(
          children: [
            _buildFilterInfoBar(),
            Expanded(child: _buildPostList()),
            if (_posts.isNotEmpty) _buildPaginationBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildTopAppBar() {
    return AppBar(
      title: const Text(
        'Latest',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
      ),
      backgroundColor: AppTheme.getSurfaceColor(context),
      foregroundColor: AppTheme.getOnSurfaceColor(context),
      elevation: 0,
      actions: [
        IconButton(
          onPressed: _loadInitialPosts,
          icon: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryColor,
                  ),
                )
              : const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
        IconButton(
          onPressed: _showFilterBottomSheet,
          icon: const Icon(Icons.filter_list),
          tooltip: 'Filter',
        ),
      ],
    );
  }

  Widget _buildFilterInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.getSurfaceColor(context),
      child: Row(
        children: [
          Text(
            _getServiceDisplayName(_selectedService),
            style: AppTheme.captionStyle.copyWith(
              color: _getServiceColor(_selectedService),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_blockedTags.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              '•',
              style: AppTheme.captionStyle.copyWith(
                color: AppTheme.getOnSurfaceColor(context),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_blockedTags.length} tags blocked',
              style: AppTheme.captionStyle.copyWith(
                color: AppTheme.getOnSurfaceColor(context),
              ),
            ),
          ],
          const Spacer(),
          GestureDetector(
            onTap: _showDownloadManager,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download, color: Colors.green, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Downloads',
                    style: AppTheme.captionStyle.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showFilterBottomSheet,
            child: Text(
              'Filter',
              style: AppTheme.captionStyle.copyWith(
                color: AppTheme.primaryColor,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDownloadManager() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DownloadManagerScreen()),
    );
  }

  List<Post> _getPagePosts() {
    final startIndex = (_currentPage - 1) * _pageSize;
    if (startIndex >= _posts.length) {
      return const <Post>[];
    }
    final endIndex = (startIndex + _pageSize).clamp(0, _posts.length);
    return _posts.sublist(startIndex, endIndex);
  }

  Future<void> _goToPage(int page) async {
    if (page < 1) return;
    if (page == _currentPage) return;
    setState(() {
      _currentPage = page;
    });

    await _ensurePageLoaded(page);

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _ensurePageLoaded(int page) async {
    final needed = page * _pageSize;
    while (_posts.length < needed && _hasMore) {
      if (_isLoading || _isLoadingMore) return;
      await _loadMorePosts();
    }

    if (!_hasMore && _posts.length < needed && mounted) {
      final lastPage = (_posts.length / _pageSize).ceil().clamp(1, 9999);
      setState(() {
        _currentPage = lastPage;
      });
    }
  }

  Widget _buildPostList() {
    if (_isLoading && _posts.isEmpty) {
      return const AppSkeletonGrid();
    }

    if (_error != null) {
      return AppErrorState(
        title: 'Error loading posts',
        message: _error!,
        onRetry: _loadInitialPosts,
      );
    }

    if (_posts.isEmpty && !_isLoading) {
      return _buildEmptyState();
    }

    final settings = context.watch<SettingsProvider>();
    final int columnCount = settings.latestPostsColumns.clamp(1, 3);
    final bool isCompact = settings.latestPostCardStyle == 'compact';
    final double aspectRatio;
    if (columnCount == 1) {
      aspectRatio = isCompact ? 2.4 : 1.6;
    } else if (columnCount == 2) {
      aspectRatio = isCompact ? 1.1 : 0.75;
    } else {
      aspectRatio = isCompact ? 0.85 : 0.65;
    }

    final mediaQuery = MediaQuery.of(context);
    final availableWidth = mediaQuery.size.width - 32; // Grid padding
    final imageWidth =
        (availableWidth - ((columnCount - 1) * 12)) / columnCount;
    final memCacheWidth = (imageWidth * mediaQuery.devicePixelRatio).round();
    final cacheExtent = mediaQuery.size.height * 2;
    final pagePosts = _getPagePosts();

    if (pagePosts.isEmpty && _isLoadingMore) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.primaryColor,
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: aspectRatio,
      ),
      cacheExtent: cacheExtent,
      addAutomaticKeepAlives: false,
      itemCount: pagePosts.length,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: _buildPostCard(
            pagePosts[index],
            settings: settings,
            memCacheWidth: memCacheWidth,
            columnCount: columnCount,
          ),
        );
      },
    );
  }

  Widget _buildPostCard(
    Post post, {
    required SettingsProvider settings,
    required int memCacheWidth,
    required int columnCount,
  }) {
    final style = settings.latestPostCardStyle;
    if (style == 'compact') {
      return _buildPostCardCompact(
        post,
        settings: settings,
        memCacheWidth: memCacheWidth,
        columnCount: columnCount,
      );
    }
    return _buildPostCardRich(
      post,
      settings: settings,
      memCacheWidth: memCacheWidth,
      columnCount: columnCount,
    );
  }

  Widget _buildPostCardCompact(
    Post post, {
    required SettingsProvider settings,
    required int memCacheWidth,
    required int columnCount,
  }) {
    final hasBlockedTags = _hasBlockedTags(post);
    final mediaItems = _getPostMediaItems(post);
    final hasVideo = mediaItems.any((item) => item['type'] == 'video');
    final thumbnailMedia = mediaItems.isNotEmpty ? mediaItems.first : null;
    final mediaCount = mediaItems.length;
    final serviceColor = _getServiceColor(post.service);
    final previewText = post.title.isNotEmpty
        ? post.title
        : _cleanHtmlContent(post.content);
    final normalizedTitle = _normalizeTitle(
      previewText.isNotEmpty ? previewText : 'Untitled post',
    );
    final displayText =
        normalizedTitle.isNotEmpty ? normalizedTitle : 'Untitled post';
    final titleMaxLines = _getTitleMaxLines(
      textLength: displayText.length,
      columnCount: columnCount,
      isCompact: true,
    );
    final titleFontSize = _getTitleFontSize(
      textLength: displayText.length,
      columnCount: columnCount,
      isCompact: true,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _navigateToPostDetail(post),
          onLongPress: () => _showPostOptions(post),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: thumbnailMedia != null
                          ? _buildMediaPreview(
                              thumbnailMedia,
                              mediaCount,
                              hasVideo,
                              hasBlockedTags,
                              settings: settings,
                              memCacheWidth: memCacheWidth,
                            )
                          : MediaPreviewResolver.buildNoMediaPlaceholder(),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: _buildServiceBadge(post.service, serviceColor),
                    ),
                    if (mediaCount > 0)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: _buildMediaCountBadge(
                          mediaCount,
                          hasVideo,
                          hasBlockedTags,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildCreatorAvatar(post.user, serviceColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            post.user,
                            style: AppTheme.bodyStyle.copyWith(
                              color: hasBlockedTags
                                  ? Colors.red.withValues(alpha: 0.8)
                                  : AppTheme.getOnSurfaceColor(context),
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDate(post.published),
                          style: AppTheme.captionStyle.copyWith(
                            color: AppTheme.getOnSurfaceColor(context)
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        displayText,
                        style: AppTheme.bodyStyle.copyWith(
                          color: AppTheme.getOnSurfaceColor(context),
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          fontSize: titleFontSize,
                        ),
                        maxLines: titleMaxLines,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSocialActions(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostCardRich(
    Post post, {
    required SettingsProvider settings,
    required int memCacheWidth,
    required int columnCount,
  }) {
    final hasBlockedTags = _hasBlockedTags(post);
    final mediaItems = _getPostMediaItems(post);
    final hasVideo = mediaItems.any((item) => item['type'] == 'video');
    final thumbnailMedia = mediaItems.isNotEmpty ? mediaItems.first : null;
    final mediaCount = mediaItems.length;
    final serviceColor = _getServiceColor(post.service);
    final previewText = post.title.isNotEmpty
        ? post.title
        : _cleanHtmlContent(post.content);
    final normalizedTitle = _normalizeTitle(
      previewText.isNotEmpty ? previewText : 'Untitled post',
    );
    final displayText =
        normalizedTitle.isNotEmpty ? normalizedTitle : 'Untitled post';
    final titleMaxLines = _getTitleMaxLines(
      textLength: displayText.length,
      columnCount: columnCount,
      isCompact: false,
    );
    final titleFontSize = _getTitleFontSize(
      textLength: displayText.length,
      columnCount: columnCount,
      isCompact: false,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color:
                AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => _navigateToPostDetail(post),
          onLongPress: () => _showPostOptions(post),
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: thumbnailMedia != null
                            ? _buildMediaPreview(
                                thumbnailMedia,
                                mediaCount,
                                hasVideo,
                                hasBlockedTags,
                                settings: settings,
                                memCacheWidth: memCacheWidth,
                              )
                            : MediaPreviewResolver.buildNoMediaPlaceholder(),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: _buildServiceBadge(
                          post.service,
                          serviceColor,
                        ),
                      ),
                      if (mediaCount > 0)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: _buildMediaCountBadge(
                            mediaCount,
                            hasVideo,
                            hasBlockedTags,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildCreatorAvatar(post.user, serviceColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              post.user,
                              style: AppTheme.bodyStyle.copyWith(
                                fontWeight: FontWeight.w700,
                                color: hasBlockedTags
                                    ? Colors.red.withValues(alpha: 0.8)
                                    : AppTheme.getOnSurfaceColor(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatDate(post.published),
                            style: AppTheme.captionStyle.copyWith(
                              color: AppTheme.getOnSurfaceColor(context)
                                  .withValues(alpha: 0.6),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: Text(
                          displayText,
                          style: AppTheme.bodyStyle.copyWith(
                            color: AppTheme.getOnSurfaceColor(context),
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            fontSize: titleFontSize,
                          ),
                          maxLines: titleMaxLines,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Spacer(),
                      _buildSocialActions(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatorAvatar(String name, Color color) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 14,
      backgroundColor: color.withValues(alpha: 0.18),
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildServiceBadge(String service, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color:
                AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        service.toUpperCase(),
        style: TextStyle(
          color: AppTheme.getOnSurfaceColor(context),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildMediaCountBadge(
    int mediaCount,
    bool hasVideo,
    bool isBlocked,
  ) {
    final badgeColor = isBlocked
        ? Colors.red.withValues(alpha: 0.9)
        : AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.65);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasVideo ? Icons.videocam : Icons.image,
            size: 12,
            color: AppTheme.getSurfaceColor(context),
          ),
          const SizedBox(width: 4),
          Text(
            mediaCount.toString(),
            style: TextStyle(
              color: AppTheme.getSurfaceColor(context),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBar() {
    final totalLoadedPages = (_posts.length / _pageSize).ceil().clamp(1, 9999);
    final canGoPrev = _currentPage > 1;
    final canGoNext = _hasMore || _currentPage < totalLoadedPages;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        boxShadow: [
          BoxShadow(
            color:
                AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildPageButton(
            icon: Icons.chevron_left,
            label: 'Prev',
            enabled: canGoPrev,
            onTap: () => _goToPage(_currentPage - 1),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.getBackgroundColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.getOnSurfaceColor(context)
                      .withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Page $_currentPage',
                    style: AppTheme.bodyStyle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _hasMore
                        ? '$totalLoadedPages+ loaded'
                        : '$totalLoadedPages total',
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.getOnSurfaceColor(context)
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  if (_isLoadingMore) ...[
                    const SizedBox(height: 6),
                    const SizedBox(
                      height: 12,
                      width: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildPageButton(
            icon: Icons.chevron_right,
            label: _hasMore ? 'Next' : 'End',
            enabled: canGoNext,
            onTap: () => _goToPage(_currentPage + 1),
          ),
        ],
      ),
    );
  }

  Widget _buildPageButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final color = enabled
        ? AppTheme.primaryColor
        : AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.3);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: enabled
              ? AppTheme.primaryColor.withValues(alpha: 0.12)
              : AppTheme.getBackgroundColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? AppTheme.primaryColor : color,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTheme.captionStyle.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialActions() {
    final iconColor = AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.6);
    return Row(
      children: [
        Icon(Icons.favorite_border, size: 16, color: iconColor),
        const SizedBox(width: 10),
        Icon(Icons.mode_comment_outlined, size: 16, color: iconColor),
        const SizedBox(width: 10),
        Icon(Icons.bookmark_border, size: 16, color: iconColor),
        const Spacer(),
        Icon(Icons.more_horiz, size: 16, color: iconColor),
      ],
    );
  }

  Widget _buildMediaPreview(
    Map<String, dynamic> media,
    int totalCount,
    bool hasVideo,
    bool hasBlockedTags, {
    required SettingsProvider settings,
    required int memCacheWidth,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Media thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(0),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.getSurfaceColor(context),
            ),
            child: _buildOptimizedMediaThumbnail(
              media,
              hasVideo,
              settings: settings,
              memCacheWidth: memCacheWidth,
            ),
          ),
        ),

        // Video overlay
        if (hasVideo)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.getOnSurfaceColor(context)
                        .withValues(alpha: 0.24),
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
                child: Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    color: AppTheme.getSurfaceColor(context),
                    size: 32,
                  ),
                ),
              ),
            ),

        // Blocked content overlay
        if (hasBlockedTags)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                 gradient: LinearGradient(
                   colors: [
                     Colors.red.withValues(alpha: 0.8),
                     Colors.red.withValues(alpha: 0.4),
                   ],
                   begin: Alignment.center,
                   end: Alignment.topCenter,
                 ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block,
                        color: AppTheme.getSurfaceColor(context), size: 24),
                    const SizedBox(height: 4),
                    Text(
                      'Blocked',
                      style: TextStyle(
                        color: AppTheme.getSurfaceColor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            color: AppTheme.getOnSurfaceColor(context)
                                .withValues(alpha: 0.5),
                            offset: const Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Media count badge
        if (totalCount > 1)
          Positioned(
            top: 8,
            right: 8,
             child: Container(
               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
               decoration: BoxDecoration(
                 color: hasBlockedTags
                     ? Colors.red.withValues(alpha: 0.9)
                     : AppTheme.getOnSurfaceColor(context)
                         .withValues(alpha: 0.7),
                 borderRadius: BorderRadius.circular(10),
               ),
               child: Text(
                 '+${totalCount - 1}',
                 style: TextStyle(
                   color: AppTheme.getSurfaceColor(context),
                   fontSize: 10,
                   fontWeight: FontWeight.w600,
                 ),
               ),
             ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final isFiltered = _blockedTags.isNotEmpty || _selectedService != 'kemono';

    if (isFiltered) {
      return AppEmptyState(
        icon: Icons.filter_list_off,
        title: 'All posts hidden by filters',
        message: 'Try adjusting your filters',
        actionLabel: 'Manage Filters',
        onAction: _showFilterBottomSheet,
      );
    }

    return const AppEmptyState(
      icon: Icons.article_outlined,
      title: 'No posts yet',
      message: 'Pull down to refresh',
    );
  }

  Widget _buildFilterBottomSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Filter Posts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Service filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Service',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ['kemono', 'coomer'].map((service) {
                    final isSelected = _selectedService == service;
                    return FilterChip(
                      label: Text(service.toUpperCase()),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          // 🚀 NEW: Animasi transisi domain
                          _showDomainTransitionAnimation(
                            _selectedService,
                            service,
                          );

                          setState(() {
                            _selectedService = service;
                          });
                          _loadInitialPosts();
                          Navigator.pop(context);
                        }
                      },
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      selectedColor: AppTheme.primaryColor.withValues(
                        alpha: 0.2,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.getOnBackgroundColor(context),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Tag filter info
          if (_blockedTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Blocked Tags',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_blockedTags.length} tags are blocked',
                    style: TextStyle(
                      color: AppTheme.getOnSurfaceColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Show actual blocked tags
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _blockedTags.length,
                      itemBuilder: (context, index) {
                        final tag = _blockedTags[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.block,
                                size: 16,
                                color: Colors.red[400],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    color: AppTheme.getOnSurfaceColor(context),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _blockedTags.remove(tag);
                                  });
                                  final tagFilter = context
                                      .read<TagFilterProvider>();
                                  tagFilter.removeFromBlacklist(tag);
                                },
                                icon: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showPostOptions(Post post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.getSurfaceColor(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.bookmark_border),
                    title: const Text('Bookmark Post'),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bookmark feature coming soon!'),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('View Creator'),
                    onTap: () {
                      Navigator.pop(context);
                      final creator = Creator(
                        id: post.user,
                        service: post.service,
                        name: post.user,
                        indexed: 0,
                        updated: 0,
                        favorited: false,
                      );
                      _navigateToCreatorDetail(creator);
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

  Widget _buildOptimizedMediaThumbnail(
    Map<String, dynamic> media,
    bool hasVideo, {
    required SettingsProvider settings,
    required int memCacheWidth,
  }) {
    final isVideo = media['type'] == 'video';

    if (isVideo) {
      // Video placeholder
      return MediaPreviewResolver.buildVideoPlaceholder();
    } else {
      // ✅ MANUAL THUMBNAIL BUILDING - Original link + client-side downscale
      final thumbnailUrl = media['thumbnail_url'] as String? ?? '';
      final fullUrl = media['url'] as String;

      return _buildOptimizedThumbnail(
        thumbnailUrl,
        fullUrl,
        imageFit: settings.imageFitMode,
        memCacheWidth: memCacheWidth,
      );
    }
  }

  /// Build optimized thumbnail with client-side downscale (SAME AS POST DETAIL)
  Widget _buildOptimizedThumbnail(
    String thumbnailUrl,
    String fullUrl, {
    required BoxFit imageFit,
    required int memCacheWidth,
  }) {
    // Use thumbnail URL for preview. Fall back to full only when no thumbnail exists.
    final displayUrl = thumbnailUrl.isNotEmpty ? thumbnailUrl : fullUrl;

    // 🚀 FIX: Add HTTP headers for Coomer CDN anti-hotlink protection
    final isCoomerDomain =
        displayUrl.contains('coomer.st') || displayUrl.contains('n2.coomer.st');
    final httpHeaders = isCoomerDomain
        ? const {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Accept': 'image/avif,image/webp,image/*,*/*;q=0.8',
            'Referer': 'https://coomer.st/',
            'Origin': 'https://coomer.st',
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
          }
        : null;

    return CachedNetworkImage(
      imageUrl: displayUrl,
      httpHeaders: httpHeaders,
      fit: imageFit,
      memCacheWidth: memCacheWidth, // Optimize for grid layout
      maxWidthDiskCache: 1024, // Limit disk cache size
      placeholder: (context, url) => Container(
        color: AppTheme.getSurfaceColor(context),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.54),
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        // Downscale fallback to full image if thumbnail fails
        if (thumbnailUrl.isNotEmpty && url == thumbnailUrl) {
          final isCoomerFallback =
              fullUrl.contains('coomer.st') || fullUrl.contains('n2.coomer.st');
          final fallbackHeaders = isCoomerFallback
              ? const {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                  'Accept': 'image/avif,image/webp,image/*,*/*;q=0.8',
                  'Referer': 'https://coomer.st/',
                  'Origin': 'https://coomer.st',
                  'Accept-Language': 'en-US,en;q=0.9',
                  'Accept-Encoding': 'gzip, deflate, br',
                  'Connection': 'keep-alive',
                  'Upgrade-Insecure-Requests': '1',
                }
              : null;

          return CachedNetworkImage(
            imageUrl: fullUrl,
            httpHeaders: fallbackHeaders,
            fit: imageFit,
            memCacheWidth: memCacheWidth, // Downscale full image for feed
            maxWidthDiskCache: 1024,
            placeholder: (context, url) => Container(
              color: AppTheme.getSurfaceColor(context),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.54),
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: AppTheme.getSurfaceColor(context),
              child: Center(
                child: Icon(
                  Icons.broken_image,
                  color: AppTheme.getOnSurfaceColor(context)
                      .withValues(alpha: 0.54),
                ),
              ),
            ),
          );
        }

        return Container(
          color: AppTheme.getSurfaceColor(context),
          child: Center(
            child: Icon(
              Icons.broken_image,
              color:
                  AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.54),
            ),
          ),
        );
      },
    );
  }

  /// Build full URL from path (SAME AS POST DETAIL)
  String _buildFullUrl(String path, String service) {
    if (path.startsWith('http')) {
      return path; // Already full URL
    }

    // Determine domain based on service
    String domain;
    if (service == 'onlyfans' || service == 'fansly' || service == 'candfans') {
      // Use CDN rotation for Coomer reliability
      domain = 'https://n2.coomer.st'; // Primary CDN
    } else {
      domain = 'https://kemono.cr'; // Kemono services
    }

    return '$domain/data$path';
  }

  /// Get thumbnail URL for Kemono/Coomer (SAME AS POST DETAIL)
  String _getThumbnailUrl(String originalUrl, String apiSource) {
    try {
      final uri = Uri.parse(originalUrl);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty && segments.first == 'data') {
        final restPath = segments.skip(1).join('/');
        final thumbnailPath = 'thumbnail/data/$restPath';

        if (apiSource == 'coomer' || uri.host.contains('coomer')) {
          return 'https://img.coomer.st/$thumbnailPath';
        }

        return 'https://img.kemono.cr/$thumbnailPath';
      }

      // Fallback to original URL
      return originalUrl;
    } catch (e) {
      return originalUrl;
    }
  }

  /// 🚀 NEW: Show domain transition animation
  void _showDomainTransitionAnimation(String fromDomain, String toDomain) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _DomainTransitionOverlay(
        fromDomain: fromDomain,
        toDomain: toDomain,
        onAnimationComplete: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

/// 🚀 NEW: Domain transition animation overlay
class _DomainTransitionOverlay extends StatefulWidget {
  final String fromDomain;
  final String toDomain;
  final VoidCallback onAnimationComplete;

  const _DomainTransitionOverlay({
    required this.fromDomain,
    required this.toDomain,
    required this.onAnimationComplete,
  });

  @override
  State<_DomainTransitionOverlay> createState() =>
      _DomainTransitionOverlayState();
}

class _DomainTransitionOverlayState extends State<_DomainTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _rotationAnimation =
        Tween<double>(
          begin: 0.0,
          end: 2 * 3.14159, // Full rotation
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
          ),
        );

    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        widget.onAnimationComplete();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: RotationTransition(
                  turns: _rotationAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // From domain (fading out)
                        Positioned.fill(
                          child: FadeTransition(
                            opacity: Tween<double>(begin: 1.0, end: 0.0)
                                .animate(
                                  CurvedAnimation(
                                    parent: _controller,
                                    curve: const Interval(
                                      0.0,
                                      0.4,
                                      curve: Curves.easeOut,
                                    ),
                                  ),
                                ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _getDomainIcon(widget.fromDomain),
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.fromDomain.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // To domain (fading in)
                        Positioned.fill(
                          child: FadeTransition(
                            opacity: Tween<double>(begin: 0.0, end: 1.0)
                                .animate(
                                  CurvedAnimation(
                                    parent: _controller,
                                    curve: const Interval(
                                      0.6,
                                      1.0,
                                      curve: Curves.easeIn,
                                    ),
                                  ),
                                ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _getDomainIcon(widget.toDomain),
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.toDomain.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Transition arrow
                        Positioned.fill(
                          child: FadeTransition(
                            opacity: Tween<double>(begin: 0.0, end: 1.0)
                                .animate(
                                  CurvedAnimation(
                                    parent: _controller,
                                    curve: const Interval(
                                      0.3,
                                      0.7,
                                      curve: Curves.easeInOut,
                                    ),
                                  ),
                                ),
                            child: Center(
                              child: Icon(
                                Icons.arrow_forward,
                                color: Colors.white.withValues(alpha: 0.8),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _getDomainIcon(String domain) {
    switch (domain.toLowerCase()) {
      case 'kemono':
        return Icons.pets;
      case 'coomer':
        return Icons.face;
      default:
        return Icons.public;
    }
  }
}
