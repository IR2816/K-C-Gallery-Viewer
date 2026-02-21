import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/popular_creators_provider.dart';
import '../providers/settings_provider.dart';
import '../../domain/entities/api_source.dart';
import '../../domain/entities/creator.dart';
import '../theme/app_theme.dart';
import '../screens/creator_detail_screen.dart';

/// Popular Creators Section with Service Selection
class PopularCreatorsSection extends StatefulWidget {
  const PopularCreatorsSection({super.key});

  @override
  State<PopularCreatorsSection> createState() => _PopularCreatorsSectionState();
}

class _PopularCreatorsSectionState extends State<PopularCreatorsSection> {
  @override
  void initState() {
    super.initState();
    // Load popular creators on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PopularCreatorsProvider>().loadPopularCreators();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PopularCreatorsProvider>(
      builder: (context, popularProvider, _) {
        return Consumer<SettingsProvider>(
          builder: (context, settingsProvider, _) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Service Selection
                  _buildHeader(popularProvider, settingsProvider),
                  const SizedBox(height: 12),

                  // Popular Creators Content
                  _buildContent(popularProvider),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Get display name with fallback for better UX
  String _getDisplayName(Creator creator) {
    // With the new API, we should get proper names now
    // But still have fallback for safety
    if (creator.name.isNotEmpty &&
        creator.name != 'Unknown' &&
        creator.name.length > 1) {
      // If name is too long, truncate it
      if (creator.name.length > 25) {
        return '${creator.name.substring(0, 22)}...';
      }

      return creator.name;
    }

    // Ultimate fallback
    String servicePrefix = creator.service.isNotEmpty
        ? creator.service.substring(0, 3).toUpperCase()
        : 'CRE';

    String idPart = creator.id.length >= 8
        ? creator.id.substring(0, 8).toUpperCase()
        : creator.id.toUpperCase();

    return '$servicePrefix-$idPart';
  }

  Widget _buildHeader(
    PopularCreatorsProvider popularProvider,
    SettingsProvider settingsProvider,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          // Title with Icon and Count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.trending_up,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Popular Creators',
                      style: AppTheme.subtitleStyle.copyWith(
                        color: AppTheme.getOnBackgroundColor(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                if (popularProvider.totalItems > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${popularProvider.totalItems.toString()} total creators',
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.getOnSurfaceColor(
                        context,
                      ).withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Service Selection Toggle
          _buildServiceToggle(popularProvider),

          const SizedBox(width: 12),

          // Refresh Button
          Container(
            decoration: BoxDecoration(
              color: AppTheme.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
              ),
            ),
            child: IconButton(
              onPressed: popularProvider.refresh,
              icon: Icon(
                Icons.refresh,
                color: AppTheme.getOnSurfaceColor(context),
                size: 18,
              ),
              tooltip: 'Refresh Popular Creators',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceToggle(PopularCreatorsProvider popularProvider) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Kemono Button
          _buildServiceButton(
            title: 'Kemono',
            isSelected: popularProvider.currentService == ApiSource.kemono,
            onTap: () => popularProvider.switchService(ApiSource.kemono),
          ),

          // Coomer Button
          _buildServiceButton(
            title: 'Coomer',
            isSelected: popularProvider.currentService == ApiSource.coomer,
            onTap: () => popularProvider.switchService(ApiSource.coomer),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? AppTheme.primaryColor
                : AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.7),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(PopularCreatorsProvider popularProvider) {
    if (popularProvider.isLoading) {
      return _buildLoadingState();
    }

    if (popularProvider.error != null) {
      return _buildErrorState(popularProvider);
    }

    if (popularProvider.popularCreators.isEmpty) {
      return _buildEmptyState();
    }

    return _buildPopularCreatorsGrid(popularProvider);
  }

  Widget _buildLoadingState() {
    return Container(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height * 0.45, // Match list height
      ),
      padding: const EdgeInsets.only(
        bottom: 80,
      ), // Padding to avoid bottom navigation
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading popular creators...',
              style: AppTheme.bodyStyle.copyWith(
                color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(PopularCreatorsProvider popularProvider) {
    return Container(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height * 0.45, // Match list height
      ),
      padding: const EdgeInsets.only(
        bottom: 80,
      ), // Padding to avoid bottom navigation
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.withValues(alpha: 0.7),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Failed to load popular creators',
              style: AppTheme.bodyStyle.copyWith(
                color: Colors.red.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: popularProvider.refresh,
              child: Text(
                'Tap to retry',
                style: AppTheme.bodyStyle.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height * 0.45, // Match list height
      ),
      padding: const EdgeInsets.only(
        bottom: 80,
      ), // Padding to avoid bottom navigation
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.5),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'No popular creators found',
              style: AppTheme.bodyStyle.copyWith(
                color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularCreatorsGrid(PopularCreatorsProvider popularProvider) {
    return Container(
      // Use dynamic height to avoid bottom navigation overlap
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height *
            0.45, // Increased to 45% for list
      ),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo is ScrollEndNotification) {
            final metrics = scrollInfo.metrics;
            if (metrics.pixels >= metrics.maxScrollExtent - 200) {
              // Load more when 200px from bottom
              _loadMoreCreators(popularProvider);
            }
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.only(
            left: 4,
            right: 4,
            bottom: 80, // Extra padding to avoid bottom navigation
          ),
          itemCount:
              popularProvider.popularCreators.length +
              (popularProvider.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            // Show loading indicator at the bottom
            if (index == popularProvider.popularCreators.length &&
                popularProvider.isLoadingMore) {
              return _buildLoadingMoreIndicator();
            }

            final creator = popularProvider.popularCreators[index];
            return _buildCreatorListItem(creator, popularProvider, index);
          },
        ),
      ),
    );
  }

  /// Load more creators when scrolling near bottom
  void _loadMoreCreators(PopularCreatorsProvider popularProvider) {
    if (popularProvider.hasMorePages && !popularProvider.isLoadingMore) {
      popularProvider.loadMorePopularCreators();
    }
  }

  /// Build loading more indicator
  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading more creators...',
              style: AppTheme.bodyStyle.copyWith(
                color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatorListItem(
    Creator creator,
    PopularCreatorsProvider popularProvider,
    int index,
  ) {
    final bannerUrl = _buildCreatorBannerUrl(
      creator,
      popularProvider.currentService,
    );
    final iconUrl = _buildCreatorIconUrl(
      creator,
      popularProvider.currentService,
    );
    final serviceColor = _getServiceColor(creator.service);
    final idPreview = creator.id.length > 8
        ? creator.id.substring(0, 8).toUpperCase()
        : creator.id.toUpperCase();
    final secondaryText = creator.fans != null
        ? '${_formatFansCount(creator.fans!)} favorites'
        : '${popularProvider.currentService == ApiSource.kemono ? 'Kemono' : 'Coomer'} - ID: $idPreview';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 
              Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.1,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreatorDetailScreen(
                  creator: creator,
                  apiSource: popularProvider.currentService,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 110,
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
                    top: 10,
                    left: 12,
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
                        creator.service.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
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
                                  creator.name.isNotEmpty
                                      ? creator.name[0].toUpperCase()
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
                                _getDisplayName(creator),
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
                                secondaryText,
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

  /// Format fans count for better display
  String _formatFansCount(int fans) {
    if (fans >= 1000000) {
      return '${(fans / 1000000).toStringAsFixed(1)}M';
    } else if (fans >= 1000) {
      return '${(fans / 1000).toStringAsFixed(1)}K';
    }
    return fans.toString();
  }

  String _buildCreatorBannerUrl(Creator creator, ApiSource source) {
    final base =
        source == ApiSource.coomer ? 'https://img.coomer.st' : 'https://img.kemono.cr';
    return '$base/banners/${creator.service}/${creator.id}';
  }

  String _buildCreatorIconUrl(Creator creator, ApiSource source) {
    if (creator.avatar.isNotEmpty) return creator.avatar;
    final base =
        source == ApiSource.coomer ? 'https://img.coomer.st' : 'https://img.kemono.cr';
    return '$base/icons/${creator.service}/${creator.id}';
  }

  Map<String, String>? _getCoomerHeaders(String url) {
    final isCoomerDomain =
        url.contains('coomer.st') || url.contains('img.coomer.st');
    if (!isCoomerDomain) return null;
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

}
