import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/api_source.dart';
import 'video_player_screen.dart';
import '../../utils/logger.dart';
import '../widgets/app_video_player.dart';

class FullscreenMediaViewer extends StatefulWidget {
  final List<Map<String, dynamic>> mediaItems;
  final int initialIndex;
  final ApiSource apiSource;

  const FullscreenMediaViewer({
    super.key,
    required this.mediaItems,
    required this.initialIndex,
    required this.apiSource,
  });

  @override
  State<FullscreenMediaViewer> createState() => _FullscreenMediaViewerState();
}

class _FullscreenMediaViewerState extends State<FullscreenMediaViewer>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _showUI = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Fade animation for UI
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Auto-hide UI after 3 seconds
    _autoHideUI();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _autoHideUI() {
    if (_showUI) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _showUI) {
          _toggleUI();
        }
      });
    }
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
    if (_showUI) {
      _fadeController.reverse();
      _autoHideUI();
    } else {
      _fadeController.forward();
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _close() {
    Navigator.pop(context);
  }

  Future<void> _shareMedia(Map<String, dynamic> mediaItem) async {
    final url = (mediaItem['url'] ?? '').toString();
    if (url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Media link copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Media Area
          _buildMediaArea(),

          // Subtle scrim for readability (social-style UI)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.45),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // UI Overlay
          _buildUIOverlay(),
        ],
      ),
    );
  }

  Widget _buildMediaArea() {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: widget.mediaItems.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final mediaItem = widget.mediaItems[index];
        final isVideo = mediaItem['type'] == 'video';

        if (isVideo) {
          // Videos - play inline and fill the screen
          return _buildVideoPlayer(mediaItem);
        } else {
          // 🔥 STRATEGI IDEAL: Fullscreen Viewer - Original quality tanpa downscale
          final imageUrl = mediaItem['url'];
          AppLogger.debug('🔍 DEBUG: FullscreenMediaViewer loading image: $imageUrl');

          // 🚀 FIX: Add HTTP headers for Coomer CDN anti-hotlink protection
          final isCoomerDomain =
              imageUrl.contains('coomer.st') ||
              imageUrl.contains('n2.coomer.st');
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

          return PhotoView(
            imageProvider: CachedNetworkImageProvider(
              imageUrl,
              headers: httpHeaders,
            ),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 4.0,
            heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
            loadingBuilder: (context, event) => Center(
              child: SizedBox(
                width: 40.0,
                height: 40.0,
                child: CircularProgressIndicator(
                  value: event == null
                      ? 0
                      : event.cumulativeBytesLoaded /
                            (event.expectedTotalBytes ?? 1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            errorBuilder: (context, error, stackTrace) {
              AppLogger.debug('🔍 DEBUG: FullscreenMediaViewer image load error: $error');
              AppLogger.debug('🔍 DEBUG: Failed URL was: $imageUrl');

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'URL: $imageUrl',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          );
        }
      },
    );
  }

  /// Build video placeholder untuk gallery
  Widget _buildVideoPlayer(Map<String, dynamic> mediaItem) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = MediaQuery.sizeOf(context);
        final width = constraints.hasBoundedWidth && constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : mediaSize.width;
        final height =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : mediaSize.height;

        return Container(
          color: Colors.black,
          child: AppVideoPlayer(
            url: mediaItem['url'],
            apiSource: widget.apiSource.name,
            width: width,
            height: height,
            autoplay: true,
            showControls: true,
            showLoading: true,
            showError: true,
          ),
        );
      },
    );
  }

  /// Get clean file name
  String _getFileName(String fullFileName) {
    final parts = fullFileName.split('/');
    return parts.isNotEmpty ? parts.last : fullFileName;
  }

  /// Open video player dari gallery
  void _openVideoPlayer(Map<String, dynamic> mediaItem) {
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
  }

  Widget _buildUIOverlay() {
    final currentMedia = widget.mediaItems[_currentIndex];
    final isVideo = currentMedia['type'] == 'video';
    final isCoomerVideo = isVideo && widget.apiSource == ApiSource.coomer;

    return GestureDetector(
      onTap: _toggleUI,
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Stack(
              children: [
                // Top UI
                if (_showUI && !isCoomerVideo) _buildTopUI(),

                // Bottom UI
                if (_showUI && !isCoomerVideo) _buildBottomUI(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopUI() {
    final currentMedia = widget.mediaItems[_currentIndex];
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: _buildTopBarRow(currentMedia),
        ),
      ),
    );
  }

  Widget _buildBottomUI() {
    final currentMedia = widget.mediaItems[_currentIndex];
    final isVideo = currentMedia['type'] == 'video';

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isVideo && widget.mediaItems.length > 1)
                _buildNavButton(
                  icon: Icons.arrow_back,
                  label: 'Prev',
                  enabled: _currentIndex > 0,
                  onTap: _currentIndex > 0
                      ? () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                          )
                      : null,
                ),
              if (!isVideo && widget.mediaItems.length > 1)
                const SizedBox(width: 12),
              if (!isVideo && widget.mediaItems.length > 1)
                _buildNavButton(
                  icon: Icons.arrow_forward,
                  label: 'Next',
                  enabled: _currentIndex < widget.mediaItems.length - 1,
                  onTap: _currentIndex < widget.mediaItems.length - 1
                      ? () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                          )
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBarRow(Map<String, dynamic> mediaItem) {
    final isVideo = mediaItem['type'] == 'video';
    final title = mediaItem['name'] != null
        ? _getFileName(mediaItem['name'])
        : (isVideo ? 'Video' : 'Image');
    final typeLabel = isVideo ? 'Video' : 'Image';
    final typeIcon = isVideo ? Icons.play_circle_fill : Icons.photo;
    final counterText = '${_currentIndex + 1} / ${widget.mediaItems.length}';

    return Row(
      children: [
        _buildIconChip(icon: Icons.close, onTap: _close),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Icon(typeIcon, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$typeLabel | $counterText',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildIconChip(
          icon: Icons.share,
          onTap: () => _shareMedia(mediaItem),
        ),
      ],
    );
  }

  Widget _buildIconChip({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    final iconColor =
        enabled ? Colors.white : Colors.white.withValues(alpha: 0.35);
    final textColor =
        enabled ? Colors.white : Colors.white.withValues(alpha: 0.35);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
