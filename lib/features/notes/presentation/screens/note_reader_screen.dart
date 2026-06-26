import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:path/path.dart' as p;
import '../../domain/models/note.dart';
import '../../shared/providers.dart';

class NoteReaderScreen extends ConsumerStatefulWidget {
  final NoteListing note;
  final String filePath;
  final int initialPage;

  const NoteReaderScreen({
    super.key,
    required this.note,
    required this.filePath,
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
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final extension = p.extension(widget.filePath).toLowerCase();
    _isPdf = extension == '.pdf';

    if (_isPdf) {
      _currentPage = widget.initialPage;
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(widget.filePath),
        initialPage: widget.initialPage + 1,
      );
    } else {
      // For Docx/PPT, we use Google Docs Viewer via WebView
      // Note: This requires an active internet connection even if the file is downloaded,
      // as the viewer is a remote service.
      final String viewerUrl = 'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(widget.note.fileUrl)}';
      
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) => setState(() => _isWebLoading = true),
            onPageFinished: (url) => setState(() => _isWebLoading = false),
            onWebResourceError: (error) {
               debugPrint('🌐 WebView Error: ${error.description}');
            },
          ),
        )
        ..loadRequest(Uri.parse(viewerUrl));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pdfController?.dispose();
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

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(noteProgressProvider(widget.note.id));
    final isBookmarked = progressAsync.valueOrNull?.isBookmarked ?? false;

    return Scaffold(
      backgroundColor: _isPdf ? Colors.grey.shade900 : Colors.white,
      appBar: AppBar(
        backgroundColor: _isPdf ? Colors.black.withOpacity(0.8) : Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.note.title,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_isPdf && _totalPages > 0)
              Text(
                'Page ${_currentPage + 1} of $_totalPages',
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              )
            else if (!_isPdf)
              Text(
                'Document Viewer',
                style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7)),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: isBookmarked ? Colors.amber : Colors.white,
            ),
            onPressed: () => ref.read(studyControllerProvider).toggleBookmark(widget.note.id),
          ),
        ],
      ),
      body: _isPdf ? _buildPdfView() : _buildWebView(),
      bottomNavigationBar: (_isPdf && _totalPages > 0) ? _buildProgressSlider() : null,
    );
  }

  Widget _buildPdfView() {
    return PdfViewPinch(
      controller: _pdfController!,
      onDocumentLoaded: (document) {
        setState(() {
          _totalPages = document.pagesCount;
        });
      },
      onPageChanged: _onPageChanged,
      onDocumentError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening PDF: $error')),
        );
        Navigator.pop(context);
      },
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        WebViewWidget(controller: _webViewController!),
        if (_isWebLoading)
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.indigo),
                SizedBox(height: 16),
                Text('Preparing document...', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProgressSlider() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: SafeArea(
        child: Row(
          children: [
            Text(
              '${_currentPage + 1}',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: Slider(
                value: _currentPage.toDouble(),
                min: 0,
                max: (_totalPages - 1).toDouble(),
                activeColor: Colors.indigoAccent,
                inactiveColor: Colors.white24,
                onChanged: (val) {
                  _pdfController?.jumpToPage(val.toInt() + 1);
                },
              ),
            ),
            Text(
              '$_totalPages',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
