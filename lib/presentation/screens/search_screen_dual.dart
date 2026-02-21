import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Domain
import '../../domain/entities/api_source.dart';
import '../../domain/entities/creator.dart';
import '../../domain/entities/discord_server.dart';

// Providers
import '../providers/creator_search_provider.dart';
import '../providers/creators_provider.dart';
import '../providers/settings_provider.dart';

// Services
import '../services/creator_index_manager.dart';

// Data
import '../../data/datasources/creator_index_datasource_impl.dart';
import '../../data/models/creator_search_result.dart';

// Theme
import '../theme/app_theme.dart';

// Screens
import 'creator_detail_screen.dart';
import 'discord_channel_list_screen.dart';

// Widgets
import '../widgets/popular_creators_section.dart';

// Utils
import '../../utils/logger.dart';

/// 🎯 DUAL SearchScreen - Name Search + ID Search
///
/// Features:
/// - ✅ Tab 1: Search by Name (Creator Index - fast)
/// - ✅ Tab 2: Search by ID (API search - original)
/// - ✅ Seamless switching between modes
/// - ✅ Modern UI with animations
/// - ✅ Error handling for both modes
class SearchScreenDual extends StatefulWidget {
  const SearchScreenDual({super.key});

  @override
  State<SearchScreenDual> createState() => _SearchScreenDualState();
}

class _SearchScreenDualState extends State<SearchScreenDual>
    with TickerProviderStateMixin {
  // Controllers
  final TextEditingController _nameSearchController = TextEditingController();
  final TextEditingController _idSearchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _idFocusNode = FocusNode();

  // Animation Controllers
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Provider Instance
  late CreatorSearchProvider _creatorSearchProvider;

  // State
  ApiSource _selectedApiSource = ApiSource.kemono;
  String _selectedService = 'patreon'; // Default service
  bool _showPopular = true;
  Timer? _nameSearchDebounce;
  Timer? _idSearchDebounce;

  // Service lists
  static const List<Map<String, dynamic>> _kemonoServices = [
    {
      'id': 'patreon',
      'name': 'Patreon',
      'icon': Icons.favorite,
      'color': Colors.orange,
    },
    {
      'id': 'pixiv_fanbox',
      'name': 'Pixiv Fanbox',
      'icon': Icons.palette,
      'color': Colors.blue,
    },
    {
      'id': 'discord',
      'name': 'Discord',
      'icon': Icons.discord,
      'color': Colors.indigo,
    },
    {
      'id': 'fantia',
      'name': 'Fantia',
      'icon': Icons.star,
      'color': Colors.purple,
    },
    {
      'id': 'afdian',
      'name': 'Afdian',
      'icon': Icons.payment,
      'color': Colors.green,
    },
    {
      'id': 'boosty',
      'name': 'Boosty',
      'icon': Icons.rocket_launch,
      'color': Colors.red,
    },
    {
      'id': 'gumroad',
      'name': 'Gumroad',
      'icon': Icons.shopping_cart,
      'color': Colors.brown,
    },
    {
      'id': 'subscribestar',
      'name': 'SubscribeStar',
      'icon': Icons.star_border,
      'color': Colors.teal,
    },
    {
      'id': 'dlsite',
      'name': 'DLsite',
      'icon': Icons.shop,
      'color': Colors.pink,
    },
  ];

  static const List<Map<String, dynamic>> _coomerServices = [
    {
      'id': 'onlyfans',
      'name': 'OnlyFans',
      'icon': Icons.lock,
      'color': Colors.black,
    },
    {
      'id': 'fansly',
      'name': 'Fansly',
      'icon': Icons.person,
      'color': Colors.blue,
    },
    {
      'id': 'candfans',
      'name': 'CandFans',
      'icon': Icons.cake,
      'color': Colors.pink,
    },
  ];

  @override
  void initState() {
    super.initState();

    // Initialize provider instance
    _creatorSearchProvider = CreatorSearchProvider(
      CreatorIndexManager(CreatorIndexDatasourceImpl()),
    );

    _tabController = TabController(length: 2, vsync: this);
    _tabController.index = 1; // Default to "Search by ID" (index 1)
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Initialize provider and prepare index
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSearch();
    });

    // Search listeners
    _nameSearchController.addListener(_onNameSearchChanged);
    _idSearchController.addListener(_onIdSearchChanged);

    // Tab listener
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticFeedback.lightImpact();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    _nameSearchController.dispose();
    _idSearchController.dispose();
    _nameSearchDebounce?.cancel();
    _idSearchDebounce?.cancel();
    _scrollController.dispose();
    _nameFocusNode.dispose();
    _idFocusNode.dispose();
    super.dispose();
  }

  void _initializeSearch() {
    final settingsProvider = context.read<SettingsProvider>();
    _selectedApiSource = settingsProvider.defaultApiSource;

    // Reset service to default for the API source
    _selectedService = _selectedApiSource == ApiSource.coomer
        ? 'onlyfans'
        : 'patreon';

    // Prepare index for current API source
    _creatorSearchProvider.prepareIndex(_selectedApiSource);

    // Start animation
    _fadeController.forward();
  }

  void _onNameSearchChanged() {
    final query = _nameSearchController.text.trim();
    _nameSearchDebounce?.cancel();
    _nameSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      final currentQuery = _nameSearchController.text.trim();
      if (currentQuery != query) return;
      _handleNameQuery(currentQuery);
    });
  }

  void _onIdSearchChanged() {
    final query = _idSearchController.text.trim();
    _idSearchDebounce?.cancel();

    if (query.isEmpty) {
      final creatorsProvider = context.read<CreatorsProvider>();
      creatorsProvider.clearCreators();
      return;
    }

    _idSearchDebounce = Timer(const Duration(milliseconds: 400), () {
      final currentQuery = _idSearchController.text.trim();
      if (currentQuery != query) return;
      if (currentQuery.length < 3) return;

      _searchCreatorsById(currentQuery);
      context.read<SettingsProvider>().addToSearchHistory(currentQuery);
    });
  }

  void _handleNameQuery(String query) {
    if (query.isEmpty) {
      if (!_showPopular) {
        setState(() {
          _showPopular = true;
        });
      }
      _creatorSearchProvider.clearSearch();
      return;
    }

    if (_showPopular) {
      setState(() {
        _showPopular = false;
      });
    }

    _creatorSearchProvider.searchCreatorsByName(query, _selectedApiSource);
  }

  Future<void> _searchCreatorsById(String query) async {
    final creatorsProvider = context.read<CreatorsProvider>();

    try {
      await creatorsProvider.searchCreators(
        query,
        service: _selectedService, // Use selected service
        apiSource: _selectedApiSource,
      );
    } catch (e) {
      AppLogger.error('ID search failed', tag: 'SearchScreenDual', error: e);
    }
  }

  /// 🚀 NEW: Navigate to Discord Search Screen
  void _navigateToDiscordSearch() {
    HapticFeedback.lightImpact();

    // Navigate to Discord search screen
    Navigator.pushNamed(context, '/discord-search');

    // Reset service back to default after navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _selectedService = _selectedApiSource == ApiSource.coomer
              ? 'onlyfans'
              : 'patreon';
        });
      }
    });
  }

  Future<void> _switchApiSource(ApiSource apiSource) async {
    if (_selectedApiSource == apiSource) return;

    setState(() {
      _selectedApiSource = apiSource;
      _nameSearchController.clear();
      _idSearchController.clear();
      _showPopular = true;
      // Reset service to default for the new API source
      _selectedService = apiSource == ApiSource.coomer ? 'onlyfans' : 'patreon';
    });

    HapticFeedback.lightImpact();

    // Prepare index for new API source
    await _creatorSearchProvider.switchApiSource(apiSource);

    if (!mounted) {
      return;
    }

    // Update settings
    context.read<SettingsProvider>().setDefaultApiSource(apiSource);
  }

  void _navigateToCreatorDetail(Creator creator, {ApiSource? apiSource}) {
    HapticFeedback.lightImpact();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreatorDetailScreen(
          creator: creator,
          apiSource: apiSource ?? _selectedApiSource,
        ),
      ),
    );
  }

  Future<void> _openDiscordCreatorFromSearch(
    CreatorSearchResult searchResult,
  ) async {
    HapticFeedback.lightImpact();

    final server = DiscordServer(
      id: searchResult.id,
      name: searchResult.name,
      indexed: DateTime.now(),
      updated: DateTime.now(),
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiscordChannelListScreen(server: server),
      ),
    );
  }

  /// Get current service list based on API source
  List<Map<String, dynamic>> _getCurrentServices() {
    return _selectedApiSource == ApiSource.coomer
        ? _coomerServices
        : _kemonoServices;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _creatorSearchProvider,
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 0,
              title: Text(
                'Creator Search',
                style: AppTheme.titleStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 20,
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primaryColor,
                labelColor: Theme.of(context).colorScheme.onSurface,
                unselectedLabelColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
                tabs: const [
                  Tab(icon: Icon(Icons.person_search), text: 'Search by Name'),
                  Tab(icon: Icon(Icons.tag), text: 'Search by ID'),
                ],
              ),
            ),
            body: Column(
              children: [
                _buildApiSourceSelector(context),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildNameSearchTab(context),
                      _buildIdSearchTab(context),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildApiSourceSelector(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppTheme.mdPadding),
      child: Row(
        children: [
          Text(
            'API Source:',
            style: AppTheme.captionStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: AppTheme.smSpacing),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.smRadius),
              ),
              child: Row(
                children: [
                  _buildApiSourceButton(ApiSource.kemono),
                  _buildApiSourceButton(ApiSource.coomer),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiSourceButton(ApiSource apiSource) {
    final isSelected = _selectedApiSource == apiSource;
    final isPreparing = context.select<CreatorSearchProvider, bool>(
      (provider) =>
          provider.preparing && provider.currentApiSource == apiSource,
    );

    return Expanded(
      child: GestureDetector(
        onTap: isPreparing ? null : () => _switchApiSource(apiSource),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.smRadius),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isPreparing)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isSelected ? Colors.white : AppTheme.primaryColor,
                    ),
                  ),
                )
              else
                Icon(
                  apiSource == ApiSource.kemono ? Icons.star : Icons.favorite,
                  size: 16,
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                ),
              const SizedBox(width: 6),
              Text(
                apiSource.name.toUpperCase(),
                style: AppTheme.captionStyle.copyWith(
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameSearchTab(BuildContext context) {
    return Consumer<CreatorSearchProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            // Search Bar
            Container(
              margin: const EdgeInsets.all(AppTheme.mdPadding),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.mdRadius),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: TextField(
                controller: _nameSearchController,
                focusNode: _nameFocusNode,
                style: AppTheme.bodyStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Search creator by name...',
                  hintStyle: AppTheme.bodyStyle.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  suffixIcon: _nameSearchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _nameSearchController.clear();
                            _onNameSearchChanged();
                          },
                          icon: Icon(
                            Icons.clear,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(AppTheme.mdPadding),
                ),
              ),
            ),

            // Content
            Expanded(child: _buildNameSearchContent(context, provider)),
          ],
        );
      },
    );
  }

  Widget _buildIdSearchTab(BuildContext context) {
    return Consumer<CreatorsProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            // API Source Selector for ID Search
            Container(
              margin: const EdgeInsets.all(AppTheme.mdPadding),
              child: Row(
                children: [
                  Text(
                    'Service:',
                    style: AppTheme.captionStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: AppTheme.smSpacing),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.smPadding,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.smRadius),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedService,
                          isExpanded: true,
                          style: AppTheme.bodyStyle.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          items: _getCurrentServices().map((service) {
                            return DropdownMenuItem<String>(
                              value: service['id'],
                              child: Row(
                                children: [
                                  Icon(
                                    service['icon'],
                                    color: service['color'],
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(service['name']),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedService = value;

                                // 🚀 NEW: Auto-detect Discord service
                                if (value == 'discord') {
                                  _navigateToDiscordSearch();
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Search Bar
            Container(
              margin: const EdgeInsets.all(AppTheme.mdPadding),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.mdRadius),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _idSearchController,
                    focusNode: _idFocusNode,
                    style: AppTheme.bodyStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search creator by ID (min 3 chars)...',
                      hintStyle: AppTheme.bodyStyle.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      prefixIcon: Icon(
                        Icons.tag,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      suffixIcon: _idSearchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _idSearchController.clear();
                                _onIdSearchChanged();
                              },
                              icon: Icon(
                                Icons.clear,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(AppTheme.mdPadding),
                    ),
                  ),
                  // Search History
                  Consumer<SettingsProvider>(
                    builder: (context, settingsProvider, _) {
                      final history = settingsProvider.searchHistory;
                      if (history.isEmpty) return const SizedBox.shrink();

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.mdPadding,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Recent Searches',
                                  style: AppTheme.captionStyle.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      settingsProvider.clearSearchHistory(),
                                  child: Text(
                                    'Clear',
                                    style: AppTheme.captionStyle.copyWith(
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: history.take(5).map((query) {
                                return InputChip(
                                  label: Text(
                                    query,
                                    style: AppTheme.captionStyle.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  ),
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.surface,
                                  onPressed: () {
                                    _idSearchController.text = query;
                                    _onIdSearchChanged();
                                    _idFocusNode.unfocus();
                                  },
                                  deleteIcon: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                  onDeleted: () => settingsProvider
                                      .removeFromSearchHistory(query),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Content
            Expanded(child: _buildIdSearchContent(context, provider)),
          ],
        );
      },
    );
  }

  Widget _buildNameSearchContent(
    BuildContext context,
    CreatorSearchProvider provider,
  ) {

    // Show loading state
    if (provider.loading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    // Show error state
    if (provider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.xlPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
              const SizedBox(height: AppTheme.mdSpacing),
              Text(
                'Search Error',
                style: AppTheme.titleStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTheme.smSpacing),
              Text(
                provider.error!,
                style: AppTheme.bodyStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.lgSpacing),
              ElevatedButton.icon(
                onPressed: () => _onNameSearchChanged(),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show popular creators if no search query
    if (_showPopular) {
      return _buildPopularCreators(provider);
    }

    // Show search results from mbaharip API
    if (provider.nameSearchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.xlPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: AppTheme.secondaryTextColor,
              ),
              const SizedBox(height: AppTheme.mdSpacing),
              Text(
                'No creators found',
                style: AppTheme.titleStyle.copyWith(
                  color: AppTheme.primaryTextColor,
                ),
              ),
              const SizedBox(height: AppTheme.smSpacing),
              Text(
                'Try different keywords or check spelling',
                style: AppTheme.bodyStyle.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return _buildNameSearchResults(context, provider);
  }

  Widget _buildIdSearchContent(
    BuildContext context,
    CreatorsProvider provider,
  ) {
    if (provider.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (provider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.xlPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
              const SizedBox(height: AppTheme.mdSpacing),
              Text(
                'Search Error',
                style: AppTheme.titleStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTheme.smSpacing),
              Text(
                provider.error!,
                style: AppTheme.bodyStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.mdSpacing),
              ElevatedButton.icon(
                onPressed: () => _searchCreatorsById(_idSearchController.text),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.creators.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.xlPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(height: AppTheme.mdSpacing),
              Text(
                'No creators found',
                style: AppTheme.titleStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTheme.smSpacing),
              Text(
                'Try different creator ID or check spelling',
                style: AppTheme.bodyStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.mdPadding),
      itemCount: provider.creators.length,
      itemBuilder: (context, index) {
        final creator = provider.creators[index];
        return _buildCreatorTile(context, creator, index);
      },
    );
  }

  Widget _buildCreatorTile(BuildContext context, Creator creator, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.smSpacing),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.mdRadius),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppTheme.mdPadding),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: _getServiceColor(creator.service),
          child: Text(
            creator.name.isNotEmpty ? creator.name[0].toUpperCase() : '?',
            style: AppTheme.captionStyle.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          creator.name,
          style: AppTheme.titleStyle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              creator.service.toUpperCase(),
              style: AppTheme.captionStyle.copyWith(
                color: _getServiceColor(creator.service),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'ID: ${creator.id}',
              style: AppTheme.captionStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onTap: () => _navigateToCreatorDetail(creator),
      ),
    );
  }

  Widget _buildPopularCreators(CreatorSearchProvider provider) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Use our new PopularCreatorsSection widget
          const PopularCreatorsSection(),
        ],
      ),
    );
  }

  Widget _buildNameSearchResults(
    BuildContext context,
    CreatorSearchProvider provider,
  ) {

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          if (provider.currentQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(AppTheme.mdPadding),
              child: Row(
                children: [
                  Text(
                    'Results for "${provider.currentQuery}"',
                    style: AppTheme.titleStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${provider.nameSearchResults.length} found',
                    style: AppTheme.captionStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: provider.nameSearchResults.isEmpty
                ? _buildEmptySearch(context)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.mdPadding,
                    ),
                    itemCount: provider.nameSearchResults.length,
                    itemBuilder: (context, index) {
                      final searchResult = provider.nameSearchResults[index];
                      final creator = provider.searchResultToCreator(
                        searchResult,
                      );
                      return _buildCreatorSearchResultTile(
                        context,
                        searchResult,
                        creator,
                        index,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatorSearchResultTile(
    BuildContext context,
    CreatorSearchResult searchResult,
    Creator? creator,
    int index,
  ) {
    final service = searchResult.service.toLowerCase();
    final bannerUrl = _buildCreatorBannerUrl(service, searchResult.id);
    final iconUrl =
        searchResult.avatar != null && searchResult.avatar!.isNotEmpty
        ? searchResult.avatar!
        : _buildCreatorIconUrl(service, searchResult.id);
    final serviceColor = _getServiceColor(searchResult.service);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.mdSpacing),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (service == 'discord') {
              _openDiscordCreatorFromSearch(searchResult);
              return;
            }
            if (creator != null) {
              HapticFeedback.lightImpact();
              Navigator.of(context).pushNamed('/creator', arguments: creator);
            }
          },
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
                        searchResult.service.toUpperCase(),
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
                              errorWidget: (context, url, error) => const Icon(
                                Icons.person,
                                color: Colors.white70,
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
                                searchResult.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                searchResult.fans != null
                                    ? '${searchResult.fans} favorites'
                                    : 'ID: ${searchResult.id}',
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
        return Colors.purple;
      case 'discord':
        return Colors.blueGrey;
      case 'fantia':
        return Colors.pink;
      case 'afdian':
        return Colors.teal;
      case 'boosty':
        return Colors.red;
      case 'gumroad':
        return Colors.green;
      case 'subscribestar':
        return Colors.amber;
      case 'dlsite':
        return Colors.indigo;
      case 'onlyfans':
        return Colors.deepPurple;
      case 'fansly':
        return Colors.pink;
      case 'candfans':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  ApiSource _apiSourceForService(String service) {
    const coomerServices = {'onlyfans', 'fansly', 'candfans'};
    return coomerServices.contains(service.toLowerCase())
        ? ApiSource.coomer
        : ApiSource.kemono;
  }

  String _buildCreatorBannerUrl(String service, String creatorId) {
    final apiSource = _apiSourceForService(service);
    final base = apiSource == ApiSource.coomer
        ? 'https://img.coomer.st'
        : 'https://img.kemono.cr';
    return '$base/banners/$service/$creatorId';
  }

  String _buildCreatorIconUrl(String service, String creatorId) {
    final apiSource = _apiSourceForService(service);
    final base = apiSource == ApiSource.coomer
        ? 'https://img.coomer.st'
        : 'https://img.kemono.cr';
    return '$base/icons/$service/$creatorId';
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

  Widget _buildEmptySearch(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.xlPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(height: AppTheme.mdSpacing),
            Text(
              'No creators found',
              style: AppTheme.titleStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppTheme.smSpacing),
            Text(
              'Try different keywords or check spelling',
              style: AppTheme.bodyStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
