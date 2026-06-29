import 'dart:io';
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
  final int? thumbnailWidth;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.useCloudinaryTransform = true,
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

    // Cloudinary dynamic transformation: auto quality, auto format
    // Removed q_auto:60 because numeric quality must be q_60 or just q_auto
    String transformation = 'q_auto,f_auto';
    
    if (thumbnailWidth != null) {
      transformation += ',w_$thumbnailWidth,c_scale';
    }
    
    // Insert transformation after /upload/
    if (url.contains('/upload/')) {
      final parts = url.split('/upload/');
      final String baseUrl = parts[0];
      String remaining = parts[1];
      
      // If the URL already has a transformation (e.g. /upload/w_100/v1/id), 
      // we need to handle it. For simplicity, we prepend ours.
      // Cloudinary allows multiple transformation segments separated by slashes.
      return '$baseUrl/upload/$transformation/$remaining';
    }

    return url;
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildErrorWidget();
    }

    if (!imageUrl.startsWith('http')) {
      // Handle local files (useful for previews)
      final file = File(imageUrl);
      if (file.existsSync()) {
        Widget result = Image.file(file, width: width, height: height, fit: fit);
        if (borderRadius != null) {
          result = ClipRRect(borderRadius: borderRadius!, child: result);
        }
        return result;
      }
    }
    
    final optimizedUrl = _getOptimizedUrl();

    return CachedNetworkImage(
      imageUrl: optimizedUrl,
      width: width,
      height: height,
      fit: fit,
      imageBuilder: (context, imageProvider) {
        Widget result = Image(image: imageProvider, fit: fit);
        if (borderRadius != null) {
          result = ClipRRect(borderRadius: borderRadius!, child: result);
        }
        return result;
      },
      placeholder: (context, url) => _buildShimmer(),
      errorWidget: (context, url, error) {
        debugPrint('🖼️ OptimizedImage: Failed to load image: $url');
        return _buildErrorWidget();
      },
      // Increase memCache for high density screens if width is provided
      memCacheWidth: (thumbnailWidth != null && thumbnailWidth!.isFinite) 
          ? (thumbnailWidth! * 2).toInt() 
          : ((width != null && width!.isFinite) ? (width! * 2).toInt() : null),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width ?? double.infinity,
        height: height ?? double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
      ),
      child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
    );
  }
}
