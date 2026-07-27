import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:open_filex/open_filex.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/core/utils/app_logger.dart';
import '../../domain/models/note.dart';
import '../../shared/providers.dart';
import '../../../../services/download_service.dart';
import 'package:unihub_mobile/features/ads/ads_module.dart';

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
        url.contains('.pptx') || url.contains('.ppt')) {
      return false;
    }
        
    if (url.contains('.pdf') || path.contains('.pdf')) return true;
    
    // Cloudinary raw content check
    if (url.contains('/raw/upload')) return true;
    
    // Default to PDF for study notes
    return true;
  }

  void _initPdfController() {
    AppLogger.info('🚩 Reader: Initializing PDF Controller', 'NoteReader');
    
    try {
      if (_localPath == null) {
        AppLogger.info('🚩 Reader: localPath is NULL, triggering download', 'NoteReader');
        _downloadAndInitPdf();
        return;
      }

      final file = File(_localPath!);
      final exists = file.existsSync();
      final size = exists ? file.lengthSync() : 0;
      
      AppLogger.info('🚩 Reader: File Exists: $exists, Size: $size bytes', 'NoteReader');

      if (!exists || size == 0) {
        AppLogger.info('🚩 Reader: File missing or empty, downloading...', 'NoteReader');
        _downloadAndInitPdf();
        return;
      }
      
      AppLogger.info('🚩 Reader: Attempting to open PDF with pdfx...', 'NoteReader');
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(_localPath!),
        initialPage: widget.initialPage + 1,
      );
      setState(() => _isError = false);
      AppLogger.info('🚩 Reader: PDF Controller initialized successfully', 'NoteReader');
    } catch (e, stack) {
      AppLogger.error('❌ Reader: PDF Init Error', e, stack, 'NoteReader');
      setState(() {
        _isError = true;
        _errorMessage = 'Ulify cannot render this specific document internally. It might be too large or uses a complex format.';
      });
    }
  }

  Future<void> _downloadAndInitPdf() async {
    if (!mounted) return;
    AppLogger.info('🚩 Reader: Starting Download Pipeline', 'NoteReader');

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
      
      // Persistence Guard: Check if we already have it before network request
      final isExisting = await downloadService.isFileDownloaded(fileName);
      if (isExisting) {
        _localPath = await downloadService.getSavePath(fileName);
        AppLogger.info('🚩 Reader: Found existing local file at $_localPath', 'NoteReader');
        if (mounted) {
          setState(() => _isDownloading = false);
          _isPdf ? _initPdfController() : _initWebView();
        }
        return;
      }

      AppLogger.info('🚩 Reader: Calling downloadService.downloadFile', 'NoteReader');
      await downloadService.downloadFile(
        url: widget.note.fileUrl,
        fileName: fileName,
        noteId: widget.note.id,
      );
      
      _localPath = await downloadService.getSavePath(fileName);
      AppLogger.info('🚩 Reader: Download complete', 'NoteReader');

      if (mounted) {
        setState(() => _isDownloading = false);
        if (_isPdf) {
          _initPdfController();
        } else {
          _initWebView();
        }
      }
    } catch (e, stack) {
      AppLogger.error('❌ Reader: Download Pipeline Failed', e, stack, 'NoteReader');
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
             AppLogger.error('🌐 WebView Error: ${error.description}', error, null, 'NoteReader');
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
    _currentPage = page - 1;

    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      if (_totalPages > 0 && mounted) {
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

  Future<void> _openExternally() async {
    if (_localPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for the file to finish preparing.')),
      );
      return;
    }
    try {
      await OpenFilex.open(_localPath!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find an app to open this file. Please install Word or a PDF reader.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _isPdf ? const Color(0xFF1A1A1A) : theme.colorScheme.surface,
      bottomNavigationBar: Container(
        color: _isPdf ? Colors.black : theme.colorScheme.surface,
        child: const SafeArea(
          top: false,
          child: BannerAdWidget(),
        ),
      ),
      body: Stack(
        children: [
          // Main Reader Content - Wrapped in a RepaintBoundary for performance
          RepaintBoundary(
            child: GestureDetector(
              onTap: _toggleUI,
              child: _isError 
                ? _buildErrorView(context)
                : _isDownloading 
                  ? _buildDownloadView(context) 
                  : (_isPdf ? _buildPdfView() : _buildWebView()),
            ),
          ),

          // Header (AppBar)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: _showUI ? 0 : -110,
            left: 0,
            right: 0,
            child: _buildHeader(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: _isPdf ? Colors.black.withValues(alpha: 0.85) : theme.colorScheme.primary,
        boxShadow: [
          if (_showUI) BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 4),
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
                      if (_isPdf)
                        ValueListenableBuilder<int>(
                          valueListenable: _pdfController!.pageListenable,
                          builder: (context, page, child) {
                            return Text(
                              'Page $page of $_totalPages',
                              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                _BookmarkButton(noteId: widget.note.id),
                if (!_isPdf)
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 20),
                    tooltip: 'Open with native app',
                    onPressed: _openExternally,
                  ),
              ],
            ),
          ),
          // Reading progress bar at the bottom edge of the app bar
          if (_isPdf)
            ValueListenableBuilder<int>(
              valueListenable: _pdfController!.pageListenable,
              builder: (context, page, child) {
                if (_totalPages == 0) return const SizedBox.shrink();
                return LinearProgressIndicator(
                  value: page / _totalPages,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                  minHeight: 2,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPdfView() {
    if (_pdfController == null) return const SizedBox.shrink();
    return PdfViewPinch(
      controller: _pdfController!,
      scrollDirection: Axis.vertical,
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => const Center(child: CircularProgressIndicator()),
        pageLoaderBuilder: (_) => const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, error) => Center(child: Text(error.toString())),
      ),
      onDocumentLoaded: (document) {
        if (mounted) {
          setState(() {
            _totalPages = document.pagesCount;
          });
        }
      },
      onPageChanged: _onPageChanged,
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
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
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
              label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
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

class _BookmarkButton extends ConsumerWidget {
  final String noteId;
  const _BookmarkButton({required this.noteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(noteProgressProvider(noteId));
    final isBookmarked = progressAsync.valueOrNull?.isBookmarked ?? false;

    return IconButton(
      icon: Icon(
        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
        color: isBookmarked ? Colors.amber : Colors.white,
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        ref.read(studyControllerProvider).toggleBookmark(noteId);
      },
    );
  }
}
