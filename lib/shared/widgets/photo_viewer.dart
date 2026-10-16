import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 사진을 전체 화면으로 연다. 두 손가락으로 확대하고 끌어서 볼 수 있다.
Future<void> showPhotoViewer(BuildContext context, {required String url, String? cacheKey, String? title}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => _PhotoViewerPage(url: url, cacheKey: cacheKey, title: title),
    ),
  );
}

class _PhotoViewerPage extends StatelessWidget {
  const _PhotoViewerPage({required this.url, this.cacheKey, this.title});

  final String url;
  final String? cacheKey;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        // 앱 테마가 제목 색을 정해 두므로 검은 배경에서는 직접 흰색을 준다.
        titleTextStyle:
            Theme.of(context).appBarTheme.titleTextStyle?.copyWith(color: Colors.white) ??
            const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        title: title == null ? null : Text(title!),
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: url,
            cacheKey: cacheKey,
            fit: BoxFit.contain,
            placeholder: (context, _) => const CircularProgressIndicator(color: Colors.white),
            errorWidget: (context, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
          ),
        ),
      ),
    );
  }
}
