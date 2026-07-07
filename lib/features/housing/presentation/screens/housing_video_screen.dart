import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:unihub_mobile/core/utils/app_logger.dart';

class HousingVideoScreen extends StatefulWidget {
  final String videoUrl;
  const HousingVideoScreen({super.key, required this.videoUrl});

  @override
  State<HousingVideoScreen> createState() => _HousingVideoScreenState();
}

class _HousingVideoScreenState extends State<HousingVideoScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Allow rotation for video
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            AppLogger.error('Video Visit WebView Error: ${error.description}', error, null, 'HOUSING_VIDEO');
          },
        ),
      );

    // If it's a Cloudinary video or direct link, we wrap it in an HTML5 player for better in-app experience
    if (widget.videoUrl.contains('cloudinary.com') || 
        widget.videoUrl.toLowerCase().contains('.mp4') || 
        widget.videoUrl.toLowerCase().contains('.mov')) {
      
      final String html = '''
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <style>
            body { 
              margin: 0; 
              padding: 0;
              background-color: black; 
              display: flex; 
              align-items: center; 
              justify-content: center; 
              height: 100vh;
              overflow: hidden;
            }
            video { 
              width: 100%; 
              height: 100vh; 
              object-fit: contain;
            }
          </style>
        </head>
        <body>
          <video 
            id="videoPlayer"
            controls 
            autoplay 
            playsinline 
            webkit-playsinline
          >
            <source src="${widget.videoUrl}" type="video/mp4">
            Your browser does not support the video tag.
          </video>
        </body>
        </html>
      ''';
      
      _controller.loadHtmlString(html);
    } else {
      _controller.loadRequest(Uri.parse(widget.videoUrl));
    }
  }

  @override
  void dispose() {
    // Restore orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Virtual Visit', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: WebViewWidget(controller: _controller),
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }
}
