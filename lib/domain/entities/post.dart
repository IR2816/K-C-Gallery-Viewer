import 'post_file.dart';
import 'api_source.dart';
import '../../utils/logger.dart';

class Post {
  final String id;
  final String user;
  final String service;
  final String title;
  final String content;
  final String? embedUrl;
  final String sharedFile;
  final DateTime added;
  final DateTime published;
  final DateTime edited;
  final List<PostFile> attachments;
  final List<PostFile> file;
  final List<String> tags;
  final bool saved;

  Post({
    required this.id,
    required this.user,
    required this.service,
    required this.title,
    required this.content,
    this.embedUrl,
    required this.sharedFile,
    required this.added,
    required this.published,
    required this.edited,
    required this.attachments,
    required this.file,
    required this.tags,
    this.saved = false,
  });

  String? get thumbnailUrl {
    // DEPRECATED: Use getThumbnailUrl(apiSource) instead
    // This method is kept for compatibility but should not be used
    AppLogger.warning(
      'thumbnailUrl getter is deprecated, use getThumbnailUrl(apiSource) instead',
      tag: 'Post',
    );
    return getThumbnailUrl(ApiSource.kemono); // Fallback to kemono
  }

  String? getThumbnailUrl(
    ApiSource apiSource, {
    String? kemonoDomain,
    String? coomerDomain,
  }) {
    final domain = apiSource == ApiSource.kemono
        ? (kemonoDomain ?? 'kemono.cr') // Default to kemono.cr for thumbnails
        : (coomerDomain ?? 'coomer.st'); // Default to coomer.st for thumbnails
    final baseUrl = 'https://img.$domain/thumbnail/data';

    if (attachments.isNotEmpty) {
      final firstAttachment = attachments.first;
      final originalPath = firstAttachment.path;
      if (originalPath.startsWith('http')) return originalPath;
      if (originalPath.startsWith('//')) return 'https:$originalPath';

      // Normalize: API returns "/data/..." but thumbnails live at "/thumbnail/data/..."
      final clean = originalPath.startsWith('/')
          ? originalPath.substring(1)
          : originalPath;
      final stripped = clean.startsWith('data/') ? clean.substring(5) : clean;
      final fullUrl = '$baseUrl/$stripped';
      AppLogger.mediaUrl(
        'Thumbnail',
        firstAttachment.path,
        fullUrl,
        apiSource: apiSource.name,
        domain: domain,
      );
      return fullUrl;
    }
    if (file.isNotEmpty) {
      final firstFile = file.first;
      final originalPath = firstFile.path;
      if (originalPath.startsWith('http')) return originalPath;
      if (originalPath.startsWith('//')) return 'https:$originalPath';

      // Normalize: API returns "/data/..." but thumbnails live at "/thumbnail/data/..."
      final clean = originalPath.startsWith('/')
          ? originalPath.substring(1)
          : originalPath;
      final stripped = clean.startsWith('data/') ? clean.substring(5) : clean;
      final fullUrl = '$baseUrl/$stripped';
      AppLogger.mediaUrl(
        'Thumbnail',
        firstFile.path,
        fullUrl,
        apiSource: apiSource.name,
        domain: domain,
      );
      return fullUrl;
    }
    return null;
  }

  // Check if post has video files
  bool get hasVideo {
    final allFiles = [...attachments, ...file];
    return allFiles.any(
      (f) =>
          f.type?.contains('video') == true ||
          f.name.toLowerCase().endsWith('.mp4') ||
          f.name.toLowerCase().endsWith('.mov') ||
          f.name.toLowerCase().endsWith('.avi') ||
          f.name.toLowerCase().endsWith('.webm'),
    );
  }

  // Check if post has image files
  bool get hasImage {
    final allFiles = [...attachments, ...file];
    return allFiles.any(
      (f) =>
          f.type?.contains('image') == true ||
          f.name.toLowerCase().endsWith('.jpg') ||
          f.name.toLowerCase().endsWith('.jpeg') ||
          f.name.toLowerCase().endsWith('.png') ||
          f.name.toLowerCase().endsWith('.gif') ||
          f.name.toLowerCase().endsWith('.webp'),
    );
  }

  // Get first image file for thumbnail
  PostFile? get firstImage {
    final allFiles = [...attachments, ...file];
    try {
      return allFiles.firstWhere(
        (f) =>
            f.type?.contains('image') == true ||
            f.name.toLowerCase().endsWith('.jpg') ||
            f.name.toLowerCase().endsWith('.jpeg') ||
            f.name.toLowerCase().endsWith('.png') ||
            f.name.toLowerCase().endsWith('.gif') ||
            f.name.toLowerCase().endsWith('.webp'),
      );
    } catch (e) {
      return null;
    }
  }

  // Get first video file
  PostFile? get firstVideo {
    final allFiles = [...attachments, ...file];
    try {
      return allFiles.firstWhere(
        (f) =>
            f.type?.contains('video') == true ||
            f.name.toLowerCase().endsWith('.mp4') ||
            f.name.toLowerCase().endsWith('.mov') ||
            f.name.toLowerCase().endsWith('.avi') ||
            f.name.toLowerCase().endsWith('.webm'),
      );
    } catch (e) {
      return null;
    }
  }

  // Get appropriate thumbnail URL based on content type
  String? getBestThumbnailUrl(
    ApiSource apiSource, {
    String? kemonoDomain,
    String? coomerDomain,
  }) {
    // If has image, use first image as thumbnail
    if (hasImage && firstImage != null) {
      final domain = apiSource == ApiSource.kemono
          ? (kemonoDomain ?? 'kemono.cr')
          : (coomerDomain ?? 'coomer.st');
      final baseUrl = 'https://img.$domain/thumbnail/data';

      final originalPath = firstImage!.path;
      if (originalPath.startsWith('http')) return originalPath;
      if (originalPath.startsWith('//')) return 'https:$originalPath';

      final clean = originalPath.startsWith('/')
          ? originalPath.substring(1)
          : originalPath;
      final stripped = clean.startsWith('data/') ? clean.substring(5) : clean;
      final fullUrl = '$baseUrl/$stripped';

      AppLogger.mediaUrl(
        'Image Thumbnail',
        firstImage!.path,
        fullUrl,
        apiSource: apiSource.name,
        domain: domain,
      );
      return fullUrl;
    }

    // If only has video, use existing thumbnail method
    if (hasVideo) {
      return getThumbnailUrl(
        apiSource,
        kemonoDomain: kemonoDomain,
        coomerDomain: coomerDomain,
      );
    }

    return null;
  }

  // Get total media count
  int get mediaCount => attachments.length + file.length;

  // Get media count by type
  int get imageCount {
    final allFiles = [...attachments, ...file];
    return allFiles
        .where(
          (f) =>
              f.type?.contains('image') == true ||
              f.name.toLowerCase().endsWith('.jpg') ||
              f.name.toLowerCase().endsWith('.jpeg') ||
              f.name.toLowerCase().endsWith('.png') ||
              f.name.toLowerCase().endsWith('.gif') ||
              f.name.toLowerCase().endsWith('.webp'),
        )
        .length;
  }

  int get videoCount {
    final allFiles = [...attachments, ...file];
    return allFiles
        .where(
          (f) =>
              f.type?.contains('video') == true ||
              f.name.toLowerCase().endsWith('.mp4') ||
              f.name.toLowerCase().endsWith('.mov') ||
              f.name.toLowerCase().endsWith('.avi') ||
              f.name.toLowerCase().endsWith('.webm'),
        )
        .length;
  }

  Post copyWith({bool? saved}) {
    return Post(
      id: id,
      user: user,
      service: service,
      title: title,
      content: content,
      embedUrl: embedUrl,
      sharedFile: sharedFile,
      added: added,
      published: published,
      edited: edited,
      attachments: attachments,
      file: file,
      tags: tags,
      saved: saved ?? this.saved,
    );
  }
}
