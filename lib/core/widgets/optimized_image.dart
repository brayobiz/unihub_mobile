import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool useCloudinaryTransform;
  final int? quality;
  final int? thumbnailWidth;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.useCloudinaryTransform = true,
    this.quality = 60,
    this.thumbnailWidth,
  });

  String _getOptimizedUrl() {
    var url = imageUrl;
    
    // Force HTTPS
    if (url.startsWith('http://')) {
      url = url.replaceFirst('http://', 'https://');
    }

    if (!useCloudinaryTransform || !url.contains('cloudinary.com')) {
      return url;
    }

    // Cloudinary dynamic transformation: auto quality, auto format, and width constraint
    final String transformation = 'q_auto:$quality,f_auto${thumbnailWidth != null ? ',w_$thumbnailWidth' : ''}';
    
    // Insert transformation after /upload/
    if (url.contains('/upload/')) {
      return url.replaceFirst('/upload/', '/upload/$transformation/');
    }

    return url;
  }

  @override
  Widget build(BuildContext context) {
    final optimizedUrl = _getOptimizedUrl();

    Widget image = CachedNetworkImage(
      imageUrl: optimizedUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => _buildShimmer(),
      errorWidget: (context, url, error) {
        debugPrint('🖼️ OptimizedImage: Failed to load image: $url');
        return _buildErrorWidget();
      },
      memCacheWidth: thumbnailWidth ?? (width != null ? (width! * 2).toInt() : null),
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width ?? double.infinity,
        height: height ?? double.infinity,
        color: Colors.white,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
    );
  }
}
