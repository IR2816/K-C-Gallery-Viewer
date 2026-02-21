import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

// Domain
import '../../domain/entities/discord_server.dart';

// Providers
import '../../providers/discord_search_provider.dart';

// Theme
import '../theme/app_theme.dart';
import '../widgets/app_state_widgets.dart';

// Screens
import 'discord_channel_list_screen.dart';

/// Screen untuk menampilkan list Discord servers
class DiscordServerScreen extends StatefulWidget {
  const DiscordServerScreen({super.key});

  @override
  State<DiscordServerScreen> createState() => _DiscordServerScreenState();
}

class _DiscordServerScreenState extends State<DiscordServerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _popularScrollController = ScrollController();
  Timer? _debounceTimer;
  bool _isSearching = false;
  List<DiscordServer> _filteredServers = [];
  List<DiscordServer> _visiblePopularServers = [];
  bool _isLoadingMorePopular = false;
  int _popularTotalCount = 0;
  String? _popularFirstId;

  static const int _popularPageSize = 20;

  @override
  void initState() {
    super.initState();

    // Load popular Discord servers from mbaharip API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiscordSearchProvider>().loadPopularServers();
    });

    // Setup search listener
    _searchController.addListener(_onSearchChanged);
    _popularScrollController.addListener(_onPopularScroll);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    _popularScrollController.removeListener(_onPopularScroll);
    _popularScrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final query = _searchController.text.toLowerCase().trim();
      final provider = context.read<DiscordSearchProvider>();

      await provider.searchServers(query);
      if (!mounted) return;

      setState(() {
        _isSearching = query.isNotEmpty;
        _filteredServers = provider.searchResults;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: AppTheme.getTitleStyle(
                  context,
                ).copyWith(color: AppTheme.getOnBackgroundColor(context)),
                decoration: InputDecoration(
                  hintText: 'Search servers...',
                  hintStyle: AppTheme.getTitleStyle(context).copyWith(
                    color: AppTheme.getOnBackgroundColor(
                      context,
                    ).withValues(alpha: 0.7),
                  ),
                  border: InputBorder.none,
                ),
                autofocus: true,
              )
            : Text(
                'Kemono Discord',
                style: AppTheme.getTitleStyle(
                  context,
                ).copyWith(color: AppTheme.getOnBackgroundColor(context)),
              ),
        backgroundColor: AppTheme.getSurfaceColor(context),
        foregroundColor: AppTheme.getOnSurfaceColor(context),
        actions: [
          // Search/Cancel button
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              if (_isSearching) {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _filteredServers = [];
                });
              } else {
                setState(() {
                  _isSearching = true;
                });
                _searchFocusNode.requestFocus();
              }
            },
            tooltip: _isSearching ? 'Cancel Search' : 'Search Servers',
          ),
        ],
      ),
      body: Consumer<DiscordSearchProvider>(
        builder: (context, provider, child) {
          if (!_isSearching) {
            _ensurePopularVisible(provider);
          }
          final servers =
              _isSearching ? _filteredServers : _visiblePopularServers;

          if (provider.isLoading) {
            return const AppSkeletonList();
          }

          if (provider.error != null) {
            return _buildErrorState(provider.error!, () {
              provider.searchServers(''); // Retry with empty search
            });
          }

          if (servers.isEmpty) {
            if (_isSearching) {
              return _buildNoSearchResultsState();
            } else {
              return _buildEmptyState();
            }
          }

          return Column(
            children: [
              // Search results info
              if (_isSearching)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: AppTheme.getSurfaceColor(context).withValues(alpha: 0.5),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        size: 16,
                        color: AppTheme.getOnSurfaceColor(
                          context,
                        ).withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${servers.length} servers found',
                        style: AppTheme.getCaptionStyle(context).copyWith(
                          color: AppTheme.getOnSurfaceColor(
                            context,
                          ).withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              // Server list
              Expanded(
                child: _buildServerList(
                  servers,
                  isSearching: _isSearching,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildServerList(
    List<DiscordServer> servers, {
    required bool isSearching,
  }) {
    return ListView.builder(
      controller: isSearching ? null : _popularScrollController,
      padding: const EdgeInsets.all(16),
      itemCount: servers.length + (!isSearching && _isLoadingMorePopular ? 1 : 0),
      itemBuilder: (context, index) {
        if (!isSearching &&
            _isLoadingMorePopular &&
            index == servers.length) {
          return _buildLoadingMoreIndicator();
        }
        final server = servers[index];
        return _buildServerCard(server);
      },
    );
  }

  Widget _buildServerCard(DiscordServer server) {
    final bannerUrl = _buildDiscordBannerUrl(server.id);
    final iconUrl = _buildDiscordIconUrl(server.id);
    final updatedText =
        'Updated ${_formatDate(server.updated.millisecondsSinceEpoch ~/ 1000)}';

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
                builder: (context) => DiscordChannelListScreen(server: server),
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
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.indigo.withValues(alpha: 0.15),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.indigo.withValues(alpha: 0.35),
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
                        color: Colors.indigo.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'DISCORD',
                        style: TextStyle(
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
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Center(
                                child: Text(
                                  server.name.isNotEmpty
                                      ? server.name[0].toUpperCase()
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
                                server.name,
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
                                updatedText,
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

  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return AppErrorState(
      title: 'Error loading servers',
      message: error,
      onRetry: onRetry,
    );
  }

  Widget _buildNoSearchResultsState() {
    return AppEmptyState(
      icon: Icons.search_off,
      title: 'No Servers Found',
      message: 'No servers found for "${_searchController.text}"',
      actionLabel: 'Try Advanced Search',
      onAction: () {
        Navigator.pushNamed(context, '/discord-search');
      },
    );
  }

  Widget _buildEmptyState() {
    return const AppEmptyState(
      icon: Icons.dns_outlined,
      title: 'No Discord servers found',
      message: 'Discord servers will appear here when available',
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }

  void _onPopularScroll() {
    if (_isSearching) return;
    if (!_popularScrollController.hasClients) return;
    final threshold = 200.0;
    if (_popularScrollController.position.pixels >=
        _popularScrollController.position.maxScrollExtent - threshold) {
      final provider = context.read<DiscordSearchProvider>();
      _loadMorePopular(provider.popularServers);
    }
  }

  void _ensurePopularVisible(DiscordSearchProvider provider) {
    final list = provider.popularServers;
    final firstId = list.isNotEmpty ? list.first.id : null;
    if (list.isEmpty) {
      if (_visiblePopularServers.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _visiblePopularServers = [];
            _popularTotalCount = 0;
            _popularFirstId = null;
            _isLoadingMorePopular = false;
          });
        });
      }
      return;
    }

    if (list.length != _popularTotalCount ||
        firstId != _popularFirstId ||
        _visiblePopularServers.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _popularTotalCount = list.length;
          _popularFirstId = firstId;
          _visiblePopularServers = list.take(_popularPageSize).toList();
          _isLoadingMorePopular = false;
        });
      });
    }
  }

  void _loadMorePopular(List<DiscordServer> allServers) {
    if (_isLoadingMorePopular) return;
    if (_visiblePopularServers.length >= allServers.length) return;

    setState(() {
      _isLoadingMorePopular = true;
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final next = allServers
          .skip(_visiblePopularServers.length)
          .take(_popularPageSize)
          .toList();
      if (next.isEmpty) {
        setState(() {
          _isLoadingMorePopular = false;
        });
        return;
      }
      setState(() {
        _visiblePopularServers.addAll(next);
        _isLoadingMorePopular = false;
      });
    });
  }

  Widget _buildLoadingMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.primaryColor.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  String _buildDiscordBannerUrl(String serverId) {
    return 'https://img.kemono.cr/banners/discord/$serverId';
  }

  String _buildDiscordIconUrl(String serverId) {
    return 'https://img.kemono.cr/icons/discord/$serverId';
  }
}
