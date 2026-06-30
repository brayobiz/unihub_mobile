import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import '../../domain/models/note.dart';
import '../../shared/providers.dart';
import '../../../../services/download_service.dart';

class NoteReaderScreen extends ConsumerStatefulWidget {
  final NoteListing note;
  final String? filePath;
  final int initialPage;

  const NoteReaderScreen({
    super.key,
    required this.note,
    this.filePath,
    this.initialPage = 0,
  });

  @override
  ConsumerState<NoteReaderScreen> createState() => _NoteReaderScreenState();
}

class _NoteReaderScreenState extends ConsumerState<NoteReaderScreen> {
  // PDF Controls
  PdfControllerPinch? _pdfController;
  int _totalPages = 0;
  int _currentPage = 0;
  
  // WebView Controls for Doc/PPT
  WebViewController? _webViewController;
  bool _isPdf = true;
  bool _isWebLoading = true;
  bool _isDownloading = false;
  String? _localPath;
  Timer? _debounce;
  bool _showUI = true;
  bool _isError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _localPath = widget.filePath;
    _isPdf = _checkIfPdf();
    
    // Set system UI to dark theme for reader if PDF
    if (_isPdf) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    }

    if (_isPdf) {
      _currentPage = widget.initialPage;
      if (_localPath != null) {
        _initPdfController();
      } else {
        _downloadAndInitPdf();
      }
    } else {
      _initWebView();
    }
  }

  bool _checkIfPdf() {
    final url = widget.note.fileUrl.toLowerCase();
    final path = (_localPath ?? '').toLowerCase();
    
    // Most resources on UniHub are PDFs. If it's not explicitly something else, try PDF.
    if (url.contains('.docx') || url.contains('.doc') || 
        url.contains('.pptx') || url.contains('.ppt')) return false;
        
    if (url.contains('.pdf') || path.contains('.pdf')) return true;
    
    // Cloudinary raw content check
    if (url.contains('/raw/upload')) return true;
    
    // Default to PDF for study notes
    return true;
  }

  void _initPdfController() {
    debugPrint('🚩 Reader: Initializing PDF Controller');
    debugPrint('🚩 Reader: Local Path: $_localPath');
    
    try {
      if (_localPath == null) {
        debugPrint('🚩 Reader: localPath is NULL, triggering download');
        _downloadAndInitPdf();
        return;
      }

      final file = File(_localPath!);
      final exists = file.existsSync();
      final size = exists ? file.lengthSync() : 0;
      
      debugPrint('🚩 Reader: File Exists: $exists');
      debugPrint('🚩 Reader: File Size: $size bytes');

      if (!exists || size == 0) {
        debugPrint('🚩 Reader: File missing or empty, downloading...');
        _downloadAndInitPdf();
        return;
      }
      
      debugPrint('🚩 Reader: Attempting to open PDF with pdfx...');
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(_localPath!),
        initialPage: widget.initialPage + 1,
      );
      setState(() => _isError = false);
      debugPrint('🚩 Reader: PDF Controller initialized successfully');
    } catch (e, stack) {
      debugPrint('❌ Reader: PDF Init Error: $e');
      debugPrint('❌ Reader: StackTrace: $stack');
      setState(() {
        _isError = true;
        _errorMessage = 'UniHub cannot render this specific document internally. It might be too large or uses a complex format.';
      });
    }
  }

  Future<void> _downloadAndInitPdf() async {
    if (!mounted) return;
    debugPrint('🚩 Reader: Starting Download Pipeline');
    debugPrint('🚩 Reader: Remote URL: ${widget.note.fileUrl}');

    setState(() {
      _isDownloading = true;
      _isError = false;
    });

    try {
      final safeTitle = widget.note.title.replaceAll(RegExp(r'[^\w\s]+'), '_');
      
      // Better extension detection
      String ext = '.pdf';
      if (widget.note.fileUrl.contains('.docx')) ext = '.docx';
      else if (widget.note.fileUrl.contains('.doc')) ext = '.doc';
      else if (widget.note.fileUrl.contains('.pptx')) ext = '.pptx';
      else if (widget.note.fileUrl.contains('.ppt')) ext = '.ppt';

      final fileName = '$safeTitle$ext';
      final downloadService = ref.read(downloadServiceProvider);
      
      debugPrint('🚩 Reader: Generated Filename: $fileName');

      if (_isError) {
        final path = await downloadService.getSavePath(fileName);
        final file = File(path);
        if (file.existsSync()) {
          debugPrint('🚩 Reader: Deleting existing failed file');
          await file.delete();
        }
      }

      debugPrint('🚩 Reader: Calling downloadService.downloadFile');
      await downloadService.downloadFile(
        url: widget.note.fileUrl,
        fileName: fileName,
        noteId: widget.note.id,
      );
      
      _localPath = await downloadService.getSavePath(fileName);
      debugPrint('🚩 Reader: Download complete. New Local Path: $_localPath');

      if (mounted) {
        setState(() => _isDownloading = false);
        if (_isPdf) {
          _initPdfController();
        } else {
          _initWebView();
        }
      }
    } catch (e, stack) {
      debugPrint('❌ Reader: Download Pipeline Failed: $e');
      debugPrint('❌ Reader: StackTrace: $stack');
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isError = true;
          _errorMessage = e.toString().contains('401') 
              ? 'Access Denied: Please sign in again.' 
              : 'Download failed. Please check your connection.';
        });
      }
    }
  }

  void _initWebView() {
    // If not a PDF, we use an office viewer.
    // Try Microsoft first as it often works better with various auth setups
    final String encodedUrl = Uri.encodeComponent(widget.note.fileUrl);
    final String viewerUrl = 'https://view.officeapps.live.com/op/view.aspx?src=$encodedUrl';
    
    // Fallback URL if Microsoft fails (though we won't know easily in webview)
    // final String googleViewerUrl = 'https://docs.google.com/gview?embedded=true&url=$encodedUrl';

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => setState(() => _isWebLoading = true),
          onPageFinished: (url) => setState(() => _isWebLoading = false),
          onWebResourceError: (error) {
             debugPrint('🌐 WebView Error: ${error.description}');
             if (mounted && error.errorType != WebResourceErrorType.unknown) {
               setState(() {
                 _isError = true;
                 _errorMessage = 'Document viewer error. Please try again later.';
               });
             }
          },
        ),
      )
      ..loadRequest(Uri.parse(viewerUrl));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pdfController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page - 1;
    });

    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () {
      if (_totalPages > 0) {
        final progress = page / _totalPages;
        ref.read(studyControllerProvider).updateProgress(
          widget.note.id,
          page: _currentPage,
          total: _totalPages,
          progress: progress,
        );
      }
    });
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressAsync = ref.watch(noteProgressProvider(widget.note.id));
    final isBookmarked = progressAsync.valueOrNull?.isBookmarked ?? false;

    return Scaffold(
      backgroundColor: _isPdf ? const Color(0xFF1A1A1A) : theme.colorScheme.surface,
      body: Stack(
        children: [
          // Main Reader Content
          GestureDetector(
            onTap: _toggleUI,
            child: _isError 
              ? _buildErrorView(context)
              : _isDownloading 
                ? _buildDownloadView(context) 
                : (_isPdf ? _buildPdfView() : _buildWebView()),
          ),

          // Header (AppBar)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: _showUI ? 0 : -100,
            left: 0,
            right: 0,
            child: _buildHeader(context, isBookmarked),
          ),

          // Footer (Progress Controls)
          if (_isPdf && _totalPages > 0)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              bottom: _showUI ? 0 : -120,
              left: 0,
              right: 0,
              child: _buildFooter(context),
            ),

          // Permanent slim progress indicator at the bottom
          if (_isPdf && _totalPages > 0 && !_showUI)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: (_currentPage + 1) / _totalPages,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary.withOpacity(0.5)),
                minHeight: 3,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isBookmarked) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 8),
      decoration: BoxDecoration(
        color: _isPdf ? Colors.black.withOpacity(0.85) : theme.colorScheme.primary,
        boxShadow: [
          if (_showUI) BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.note.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 15, 
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_isPdf && _totalPages > 0)
                  Text(
                    'Page ${_currentPage + 1} of $_totalPages',
                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: isBookmarked ? Colors.amber : Colors.white,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(studyControllerProvider).toggleBookmark(widget.note.id);
            },
          ),
          if (_isPdf)
            IconButton(
              icon: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 20),
              onPressed: () {
                // Future: Thumbnail view
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thumbnail view coming soon'), duration: Duration(seconds: 1)),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                '${((_currentPage + 1) / _totalPages * 100).toInt()}%',
                style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPageNavButton(Icons.chevron_left, () {
                if (_currentPage > 0) _pdfController?.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
              }),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: theme.colorScheme.primary,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: _currentPage.toDouble(),
                    min: 0,
                    max: (_totalPages - 1).toDouble(),
                    onChanged: (val) {
                      _pdfController?.jumpToPage(val.toInt() + 1);
                    },
                  ),
                ),
              ),
              _buildPageNavButton(Icons.chevron_right, () {
                if (_currentPage < _totalPages - 1) _pdfController?.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageNavButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildPdfView() {
    if (_pdfController == null) return const SizedBox.shrink();
    return PdfViewPinch(
      controller: _pdfController!,
      onDocumentLoaded: (document) {
        setState(() {
          _totalPages = document.pagesCount;
        });
      },
      onPageChanged: _onPageChanged,
      onDocumentError: (error) {
        setState(() {
          _isError = true;
          _errorMessage = 'Error opening PDF: $error';
        });
      },
    );
  }

  Widget _buildDownloadView(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: _isPdf ? const Color(0xFF1A1A1A) : theme.colorScheme.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(seconds: 2),
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: child,
            ),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_stories, size: 64, color: theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Preparing Your Study Session',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 20, 
              fontWeight: FontWeight.bold,
              color: _isPdf ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Optimizing "${widget.note.title}" for high-quality reading...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isPdf ? Colors.white60 : theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: 140,
            child: LinearProgressIndicator(
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        WebViewWidget(controller: _webViewController!),
        if (_isWebLoading)
          _buildDownloadView(context), // Reuse download view for web loading
      ],
    );
  }

  Widget _buildErrorView(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      color: _isPdf ? const Color(0xFF1A1A1A) : theme.colorScheme.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 80, color: AppColors.error),
          const SizedBox(height: 24),
          Text(
            'Unable to Load Document',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 20, 
              fontWeight: FontWeight.bold,
              color: _isPdf ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 200,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                if (_isPdf) {
                  _downloadAndInitPdf();
                } else {
                  _initWebView();
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Go Back', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}
