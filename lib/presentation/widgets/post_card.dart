import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Domain
import '../../domain/entities/post.dart';
import '../../domain/entities/api_source.dart';

// Providers
import '../providers/settings_provider.dart';

// Theme

// Widgets
import '../../widgets/optimized_media_loader.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onSave;
  final ApiSource apiSource;
  final VoidCallback? onCreatorTap;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onSave,
    required this.apiSource,
    this.onCreatorTap,
  });

  @override
  Widget build(BuildContext context) {
    final creatorSection = onCreatorTap != null
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: InkWell(
              onTap: onCreatorTap,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Creator avatar
                  Hero(
                    tag: 'creator-${post.user}',
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: _getCreatorAvatarUrl(),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.transparent,
                            child: Icon(
                              Icons.person,
                              size: 12,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.transparent,
                            child: Icon(
                              Icons.person,
                              size: 12,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Creator name
                  Flexible(
                    child: Text(
                      _getCreatorDisplayName(),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 10,
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          )
        : const SizedBox.shrink();

    final details = Padding(
      padding: EdgeInsets.all(8), // Reduced padding for compact grid
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onCreatorTap != null) ...[
            creatorSection,
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  post.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ), // Smaller font for grid
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onSave != null)
                Tooltip(
                  message: post.saved ? 'Remove from saved' : 'Save post',
                  child: IconButton(
                    icon: Icon(
                      post.saved ? Icons.bookmark : Icons.bookmark_border,
                      color: post.saved ? Colors.blue : null,
                      size: 20, // Smaller icon for grid
                    ),
                    onPressed: onSave,
                    padding:
                        EdgeInsets.zero, // Remove padding for compact layout
                    constraints: BoxConstraints(), // Remove constraints
                  ),
                ),
            ],
          ),
          SizedBox(height: 2), // Reduced spacing
          Text(
            '${post.service} • ${_formatDate(post.published)}',
            style: TextStyle(fontSize: 11, color: Colors.grey), // Smaller font
          ),
          if (post.tags.isNotEmpty) ...[
            SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: post.tags
                  .take(3)
                  .map(
                    (tag) => Chip(
                      label: Text(tag, style: TextStyle(fontSize: 10)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final detailsChild = constraints.hasBoundedHeight
            ? Expanded(child: details)
            : details;

        return Card(
          margin: EdgeInsets.zero, // Remove external margins for grid layout
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Consumer<SettingsProvider>(
                  builder: (context, settings, _) {
                    // Get best thumbnail based on content type
                    final thumbnailUrl = post.getBestThumbnailUrl(apiSource);

                    return AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Thumbnail image
                          thumbnailUrl != null
                              ? SizedBox(
                                  width: double.infinity,
                                  height: double.infinity,
                                  child: FallbackImage(
                                    imagePath: thumbnailUrl,
                                    fit: BoxFit.cover,
                                    isThumbnail: true,
                                    apiSource: apiSource.name,
                                    errorWidget: Container(
                                      width: double.infinity,
                                      height: double.infinity,
                                      color: Colors.grey[300],
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.error_outline,
                                              color: Colors.grey[600],
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Failed to load',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  color: Colors.black,
                                  child: Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey,
                                      size: 48,
                                    ),
                                  ),
                                ),

                          // Video indicator overlay
                          if (post.hasVideo && !post.hasImage)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.3),
                                      Colors.black.withValues(alpha: 0.1),
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Content type indicators with media count
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (post.hasVideo && !post.hasImage)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.videocam,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                        SizedBox(width: 2),
                                        Text(
                                          'VIDEO ${post.videoCount}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (post.hasImage && post.hasVideo)
                                  SizedBox(width: 4),
                                if (post.hasImage && post.hasVideo)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.photo_library,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                        SizedBox(width: 2),
                                        Text(
                                          '${post.imageCount}+${post.videoCount}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (post.hasImage && !post.hasVideo)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.image,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                        SizedBox(width: 2),
                                        Text(
                                          '${post.imageCount} IMG',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                detailsChild,
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()} tahun lalu';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} bulan lalu';
    if (diff.inDays > 0) return '${diff.inDays} hari lalu';
    if (diff.inHours > 0) return '${diff.inHours} jam lalu';
    return '${diff.inMinutes} menit lalu';
  }

  String _getCreatorAvatarUrl() {
    final domain = post.service == 'fansly'
        ? 'https://coomer.st'
        : 'https://kemono.cr';
    return '$domain/data/avatars/${post.service}/${post.user}/avatar.jpg';
  }

  String _getCreatorDisplayName() {
    // Try to get meaningful creator name
    if (post.user.isNotEmpty) {
      return post.user;
    }

    // Fallback to service name if user is empty
    if (post.service.isNotEmpty) {
      return '${post.service} Creator';
    }

    // Final fallback
    return 'Unknown Creator';
  }
}
