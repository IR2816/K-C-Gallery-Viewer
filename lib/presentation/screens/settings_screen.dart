import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

// Providers
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/tag_filter_provider.dart';
import '../providers/data_usage_tracker.dart';

// Theme
import '../theme/app_theme.dart';
import '../services/custom_cache_manager.dart';

// Domain
import '../../domain/entities/api_source.dart';

// Screens
import 'data_usage_dashboard.dart';

/// 🎯 Settings Screen - Kontrol & Kenyamanan User
///
/// Prinsip:
/// - Ringkas & berguna
/// - Kategori jelas
/// - Tidak perlu scroll panjang
/// - Setiap toggle punya efek nyata
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<String>? _cacheSizeFuture;

  @override
  void initState() {
    super.initState();
    _cacheSizeFuture = _calculateCacheSize();
  }

  Future<String> _calculateCacheSize() async {
    final kemonoBytes = await customCacheManager.store.getCacheSize();
    final coomerBytes = await coomerCacheManager.store.getCacheSize();
    final totalBytes = kemonoBytes + coomerBytes;
    return _formatBytes(totalBytes);
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = bytes.toDouble();
    int unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.getSurfaceColor(context),
        foregroundColor: AppTheme.getOnSurfaceColor(context),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Appearance Section
          _buildSectionTitle('Appearance'),
          _buildAppearanceSection(),

          const SizedBox(height: 24),

          // Content & Filters Section (PALING PENTING)
          _buildSectionTitle('Content & Filters'),
          _buildContentFiltersSection(),

          const SizedBox(height: 24),

          // Feed Layout Section
          _buildSectionTitle('Feed Layout'),
          _buildFeedLayoutSection(),

          const SizedBox(height: 24),

          // Media & Playback Section
          _buildSectionTitle('Media & Playback'),
          _buildMediaPlaybackSection(),

          const SizedBox(height: 24),

          // Download Settings Section
          _buildSectionTitle('Download Settings'),
          _buildDownloadSettingsSection(),

          const SizedBox(height: 24),

          // Data & Storage Section
          _buildSectionTitle('Data & Storage'),
          _buildDataStorageSection(),

          const SizedBox(height: 24),

          // About Section
          _buildSectionTitle('About'),
          _buildAboutSection(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: AppTheme.titleStyle.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildAppearanceSection() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              // Theme Selection
              ListTile(
                leading: const Icon(Icons.palette_outlined, size: 20),
                title: const Text('Theme'),
                subtitle: Text(_getThemeDisplayName(themeProvider.themeMode)),
                trailing: DropdownButton<ThemeMode>(
                  value: themeProvider.themeMode,
                  onChanged: (ThemeMode? newTheme) {
                    if (newTheme != null) {
                      themeProvider.setThemeMode(newTheme);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System'),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Text Size
              ListTile(
                leading: const Icon(Icons.text_fields_outlined, size: 20),
                title: const Text('Text Size'),
                subtitle: Text(
                  _getTextSizeDisplayName(themeProvider.textScale),
                ),
                trailing: DropdownButton<double>(
                  value: themeProvider.textScale,
                  onChanged: (double? newTextScale) {
                    if (newTextScale != null) {
                      themeProvider.setTextScale(newTextScale);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 0.85, child: Text('Small')),
                    DropdownMenuItem(value: 1.0, child: Text('Normal')),
                    DropdownMenuItem(value: 1.15, child: Text('Large')),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContentFiltersSection() {
    return Consumer2<SettingsProvider, TagFilterProvider>(
      builder: (context, settingsProvider, tagFilterProvider, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              // Blocked Tags
              ListTile(
                leading: const Icon(Icons.block_outlined, size: 20),
                title: const Text('Blocked Tags'),
                subtitle: Text('${tagFilterProvider.blacklist.length} tags'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _showBlockedTagsScreen(),
              ),

              const Divider(height: 1),

              // Hide NSFW
              SwitchListTile(
                secondary: const Icon(
                  Icons.no_adult_content_outlined,
                  size: 20,
                ),
                title: const Text('Hide NSFW'),
                subtitle: const Text('Hide explicit content'),
                value: settingsProvider.hideNsfw,
                onChanged: (bool value) {
                  settingsProvider.setHideNsfw(value);
                },
              ),

              const Divider(height: 1),

              // Services Filter
              ListTile(
                leading: const Icon(Icons.filter_list_outlined, size: 20),
                title: const Text('Services'),
                subtitle: Text(
                  _getServiceDisplayName(settingsProvider.defaultApiSource),
                ),
                trailing: DropdownButton<ApiSource>(
                  value: settingsProvider.defaultApiSource,
                  onChanged: (ApiSource? newSource) {
                    if (newSource != null) {
                      settingsProvider.setDefaultApiSource(newSource);
                    }
                  },
                  items: ApiSource.values.map((source) {
                    return DropdownMenuItem(
                      value: source,
                      child: Text(source.name.toUpperCase()),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeedLayoutSection() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.view_quilt_outlined, size: 20),
                title: const Text('Latest Card Style'),
                subtitle: Text(
                  _getPostCardStyleDisplayName(
                    settingsProvider.latestPostCardStyle,
                  ),
                ),
                trailing: DropdownButton<String>(
                  value: settingsProvider.latestPostCardStyle,
                  onChanged: (String? newStyle) {
                    if (newStyle != null) {
                      settingsProvider.setLatestPostCardStyle(newStyle);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 'rich', child: Text('Rich')),
                    DropdownMenuItem(value: 'compact', child: Text('Compact')),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.grid_view_outlined, size: 20),
                title: const Text('Latest Columns'),
                subtitle: Text('${settingsProvider.latestPostsColumns} columns'),
                trailing: DropdownButton<int>(
                  value: settingsProvider.latestPostsColumns,
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      settingsProvider.setLatestPostsColumns(newValue);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1')),
                    DropdownMenuItem(value: 2, child: Text('2')),
                    DropdownMenuItem(value: 3, child: Text('3')),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaPlaybackSection() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              // Autoplay Video
              SwitchListTile(
                secondary: const Icon(Icons.play_disabled_outlined, size: 20),
                title: const Text('Autoplay Video'),
                subtitle: const Text('Auto-play videos in posts'),
                value: settingsProvider.autoplayVideo,
                onChanged: (bool value) {
                  settingsProvider.setAutoplayVideo(value);
                },
              ),

              const Divider(height: 1),

              // Use Thumbnails
              SwitchListTile(
                secondary: const Icon(Icons.image_outlined, size: 20),
                title: const Text('Use Thumbnails'),
                subtitle: const Text('Save data on media previews'),
                value: settingsProvider.loadThumbnails,
                onChanged: (bool value) {
                  settingsProvider.setLoadThumbnails(value);
                },
              ),

              const Divider(height: 1),

              // Image Fit Mode
              ListTile(
                leading: const Icon(Icons.fit_screen_outlined, size: 20),
                title: const Text('Image Fit Mode'),
                subtitle: Text(
                  _getImageFitDisplayName(settingsProvider.imageFitMode),
                ),
                trailing: DropdownButton<BoxFit>(
                  value: settingsProvider.imageFitMode,
                  onChanged: (BoxFit? newFit) {
                    if (newFit != null) {
                      settingsProvider.setImageFitMode(newFit);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: BoxFit.cover, child: Text('Cover')),
                    DropdownMenuItem(value: BoxFit.contain, child: Text('Fit')),
                    DropdownMenuItem(value: BoxFit.fill, child: Text('Fill')),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDownloadSettingsSection() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.download,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Download Settings',
                      style: AppTheme.titleStyle.copyWith(
                        color: AppTheme.getOnSurfaceColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Download Method
              ListTile(
                leading: Icon(Icons.browser_updated, color: Colors.blue),
                title: Text(
                  'Download Method',
                  style: AppTheme.bodyStyle.copyWith(
                    color: AppTheme.getOnSurfaceColor(context),
                  ),
                ),
                subtitle: Text(
                  'Secure browser (Custom Tabs)',
                  style: AppTheme.captionStyle.copyWith(
                    color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.6),
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Recommended',
                    style: AppTheme.captionStyle.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                onTap: () => _showDownloadMethodInfo(context),
              ),

              // Browser Info
              ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: AppTheme.secondaryTextColor,
                ),
                title: Text(
                  'Browser Compatibility',
                  style: AppTheme.bodyStyle.copyWith(
                    color: AppTheme.getOnSurfaceColor(context),
                  ),
                ),
                subtitle: Text(
                  'Chrome Custom Tabs / SFSafariViewController',
                  style: AppTheme.captionStyle.copyWith(
                    color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.6),
                  ),
                ),
                onTap: () => _showBrowserInfo(context),
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showDownloadMethodInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Method'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🎯 Smart Download Strategy',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              // Direct Download Links
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.download, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Direct Download Links',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'URLs with:\n• ?f=filename.mp4\n• download= parameter\n• /data/ path\n• .mp4?, .zip?, .rar?',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '→ External Browser (Recommended)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Regular URLs
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.web, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Regular URLs',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Streaming URLs, web pages, etc.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '→ In-App WebView (First Try)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Why this approach
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Why This Approach?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• External browsers handle direct downloads better\n'
                      '• In-app WebView has limited file download capabilities\n'
                      '• Coomer/Kemono servers prefer browser clients\n'
                      '• Automatic fallback ensures reliability',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showBrowserInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.browser_updated, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Browser Information'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🌐 Browser Compatibility',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              'Platform:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('• Android: Chrome Custom Tabs'),
            Text('• iOS: SFSafariViewController'),
            const SizedBox(height: 12),
            const Text(
              'Keuntungan:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Text('• Server melihat sebagai browser asli'),
            const Text('• Cookie dan TLS browser'),
            const Text('• Tidak ada tab permanen'),
            const Text('• Auto-close otomatis'),
            const Text('• UX tetap di dalam aplikasi'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: const Text(
                '📱 Solusi terbaik untuk download stabil',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDataStorageSection() {
    return Consumer2<SettingsProvider, DataUsageTracker>(
      builder: (context, settingsProvider, dataUsageTracker, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              // Data Usage Monitor
              ListTile(
                leading: Icon(
                  Icons.data_usage,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
                title: const Text('Data Usage Monitor'),
                subtitle: Text(
                  '${dataUsageTracker.getUsageInMB(dataUsageTracker.sessionUsage).toStringAsFixed(2)} MB this session',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DataUsageDashboard(),
                    ),
                  );
                },
              ),

              const Divider(height: 1),

              // Cache Size Info
              ListTile(
                leading: const Icon(Icons.storage_outlined, size: 20),
                title: const Text('Cache Size'),
                subtitle: FutureBuilder<String>(
                  future: _cacheSizeFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Text('Calculating...');
                    }
                    return Text(snapshot.data ?? 'Unknown');
                  },
                ),
                trailing: TextButton(
                  onPressed: () => _clearCache(),
                  child: const Text('Clear'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAboutSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Version
          ListTile(
            leading: const Icon(Icons.info_outline, size: 20),
            title: const Text('Version'),
            subtitle: const Text('1.0.3'),
          ),

          const Divider(height: 1),

          // Data Source
          ListTile(
            leading: const Icon(Icons.source_outlined, size: 20),
            title: const Text('Data Source'),
            subtitle: const Text('Kemono / Coomer'),
          ),

          const Divider(height: 1),

          // Credits: Official API
          ListTile(
            leading: const Icon(Icons.link, size: 20),
            title: const Text('Kemono/Coomer Official API'),
            subtitle: const Text('kemono.cr/documentation/api'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openLink(
              'https://kemono.cr/documentation/api',
            ),
          ),

          const Divider(height: 1),

          // Credits: Search by Name API
          ListTile(
            leading: const Icon(Icons.link, size: 20),
            title: const Text('Search by Name API'),
            subtitle: const Text('github.com/mbahArip/kemono-api'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openLink(
              'https://github.com/mbahArip/kemono-api',
            ),
          ),

          const Divider(height: 1),

          // Disclaimer
          ListTile(
            leading: const Icon(Icons.gavel_outlined, size: 20),
            title: const Text('Disclaimer'),
            subtitle: const Text('This app is a viewer, not a content owner'),
          ),
        ],
      ),
    );
  }

  // Helper Methods
  String _getThemeDisplayName(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  String _getTextSizeDisplayName(double textScale) {
    if (textScale <= 0.9) return 'Small';
    if (textScale >= 1.1) return 'Large';
    return 'Normal';
  }

  String _getServiceDisplayName(ApiSource source) {
    return source.name.toUpperCase();
  }

  String _getImageFitDisplayName(BoxFit fit) {
    switch (fit) {
      case BoxFit.cover:
        return 'Cover';
      case BoxFit.contain:
        return 'Fit';
      case BoxFit.fill:
        return 'Fill';
      default:
        return 'Cover';
    }
  }

  String _getPostCardStyleDisplayName(String style) {
    switch (style) {
      case 'compact':
        return 'Compact';
      case 'rich':
      default:
        return 'Rich';
    }
  }

  void _showBlockedTagsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BlockedTagsScreen()),
    );
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('Are you sure you want to clear all cached data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performClearCache();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open link')));
  }

  Future<void> _performClearCache() async {
    await customCacheManager.emptyCache();
    await coomerCacheManager.emptyCache();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    if (!mounted) return;
    setState(() {
      _cacheSizeFuture = _calculateCacheSize();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
  }
}

/// Blocked Tags Screen
class BlockedTagsScreen extends StatefulWidget {
  const BlockedTagsScreen({super.key});

  @override
  State<BlockedTagsScreen> createState() => _BlockedTagsScreenState();
}

class _BlockedTagsScreenState extends State<BlockedTagsScreen> {
  final TextEditingController _tagController = TextEditingController();
  List<String> _blockedTags = [];

  @override
  void initState() {
    super.initState();
    _loadBlockedTags();
  }

  void _loadBlockedTags() {
    final tagFilterProvider = Provider.of<TagFilterProvider>(
      context,
      listen: false,
    );
    setState(() {
      _blockedTags = List.from(tagFilterProvider.blacklist);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Blocked Tags'),
        backgroundColor: AppTheme.getSurfaceColor(context),
        foregroundColor: AppTheme.getOnSurfaceColor(context),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Add Tag Input
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      hintText: 'Enter tag to block...',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (value) => _addTag(value),
                  ),
                ),
                IconButton(
                  onPressed: () => _addTag(_tagController.text),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),

          // Blocked Tags List
          Expanded(
            child: _blockedTags.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.block_outlined,
                          size: 64,
                          color: AppTheme.getOnSurfaceColor(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No blocked tags',
                          style: AppTheme.titleStyle.copyWith(
                            color: AppTheme.getOnSurfaceColor(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add tags to filter content',
                          style: AppTheme.captionStyle.copyWith(
                            color: AppTheme.getOnSurfaceColor(context),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _blockedTags.length,
                    itemBuilder: (context, index) {
                      final tag = _blockedTags[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.getSurfaceColor(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        child: ListTile(
                          title: Text(tag),
                          trailing: IconButton(
                            onPressed: () => _removeTag(tag),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _addTag(String tag) {
    if (tag.trim().isEmpty) return;

    final normalizedTag = tag.trim().toLowerCase();
    if (_blockedTags.contains(normalizedTag)) return;

    final tagFilterProvider = Provider.of<TagFilterProvider>(
      context,
      listen: false,
    );
    tagFilterProvider.addToBlacklist(normalizedTag);

    setState(() {
      _blockedTags.add(normalizedTag);
      _tagController.clear();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Blocked: $normalizedTag')));
  }

  void _removeTag(String tag) {
    final tagFilterProvider = Provider.of<TagFilterProvider>(
      context,
      listen: false,
    );
    tagFilterProvider.removeFromBlacklist(tag);

    setState(() {
      _blockedTags.remove(tag);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Unblocked: $tag')));
  }
}
