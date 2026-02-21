import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'data_usage_tracker.dart';

/// Custom HTTP Client with Data Usage Tracking
class TrackedHttpClient extends http.BaseClient {
  final http.Client _inner;
  final DataUsageTracker _tracker;

  TrackedHttpClient(this._inner, this._tracker);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _inner.send(request);

      // Track response size
      final contentLength = response.contentLength ?? 0;
      final category = _categorizeRequest(request.url.toString());

      _tracker.trackUsage(contentLength, category: category);

      debugPrint(
        '📊 HTTP: ${request.method} ${request.url} → ${response.statusCode} ($contentLength bytes, ${stopwatch.elapsedMilliseconds}ms)',
      );

      return response;
    } catch (e) {
      debugPrint('❌ HTTP Error: ${request.method} ${request.url} → $e');
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Categorize HTTP requests for usage tracking
  UsageCategory _categorizeRequest(String url) {
    // API calls
    if (url.contains('/api/') || url.contains('/v1/')) {
      return UsageCategory.apiCalls;
    }

    // Image files
    if (_isImageFile(url)) {
      return UsageCategory.images;
    }

    // Video files
    if (_isVideoFile(url)) {
      return UsageCategory.videos;
    }

    // Thumbnail files (usually smaller or contain 'thumb')
    if (url.contains('thumb') || url.contains('preview')) {
      return UsageCategory.thumbnails;
    }

    // Attachments
    if (url.contains('file') || url.contains('attachment')) {
      return UsageCategory.attachments;
    }

    return UsageCategory.other;
  }

  bool _isImageFile(String url) {
    final imageExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.bmp',
      '.svg',
    ];
    return imageExtensions.any((ext) => url.toLowerCase().endsWith(ext));
  }

  bool _isVideoFile(String url) {
    final videoExtensions = [
      '.mp4',
      '.avi',
      '.mov',
      '.wmv',
      '.flv',
      '.webm',
      '.mkv',
      '.m4v',
    ];
    return videoExtensions.any((ext) => url.toLowerCase().endsWith(ext));
  }
}

/// HTTP Client Factory for creating tracked clients
class TrackedHttpClientFactory {
  static DataUsageTracker? _tracker;
  static TrackedHttpClient? _cachedClient;

  /// Initialize with a tracker instance
  static void initialize(DataUsageTracker tracker) {
    _tracker = tracker;
    _cachedClient = null; // Reset cached client
  }

  /// Get or create tracked HTTP client
  static http.Client getTrackedClient() {
    if (_tracker == null) {
      debugPrint(
        '⚠️ DataUsageTracker not initialized. Using regular HTTP client.',
      );
      return http.Client();
    }

    _cachedClient ??= TrackedHttpClient(http.Client(), _tracker!);
    return _cachedClient!;
  }

  /// Create a new tracked client instance
  static TrackedHttpClient createTrackedClient(DataUsageTracker tracker) {
    return TrackedHttpClient(http.Client(), tracker);
  }
}

/// Extension methods for easy usage
extension TrackedHttpExtensions on http.Client {
  /// Get a tracked version of this client
  TrackedHttpClient asTracked(DataUsageTracker tracker) {
    return TrackedHttpClient(this, tracker);
  }
}

/// Utility class for manual tracking
class ManualUsageTracker {
  final DataUsageTracker _tracker;

  ManualUsageTracker(this._tracker);

  /// Track image loading manually
  void trackImageLoad(String url, int bytes) {
    _tracker.trackImageUsage(bytes);
    debugPrint('🖼️ Image: $url ($bytes bytes)');
  }

  /// Track video streaming manually
  void trackVideoStream(String url, int bytes) {
    _tracker.trackVideoUsage(bytes);
    debugPrint('🎥 Video: $url ($bytes bytes)');
  }

  /// Track thumbnail loading manually
  void trackThumbnailLoad(String url, int bytes) {
    _tracker.trackThumbnailUsage(bytes);
    debugPrint('👁️ Thumbnail: $url ($bytes bytes)');
  }

  /// Track API response manually
  void trackApiResponse(String endpoint, int bytes) {
    _tracker.trackApiUsage(bytes);
    debugPrint('📡 API: $endpoint ($bytes bytes)');
  }

  /// Track generic data usage
  void trackGenericUsage(
    String description,
    int bytes, {
    UsageCategory? category,
  }) {
    _tracker.trackUsage(bytes, category: category ?? UsageCategory.other);
    debugPrint('📊 Generic: $description ($bytes bytes)');
  }
}
