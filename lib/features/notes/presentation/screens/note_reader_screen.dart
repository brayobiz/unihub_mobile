import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:google_fonts/google_fonts.dart';
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
  late PdfControllerPinch _pdfController;
  int _totalPages = 0;
  int _currentPage = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pdfController = PdfControllerPinch(
      document: PdfDocument.openFile(widget.filePath),
      initialPage: widget.initialPage + 1, // pdfx is 1-indexed
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pdfController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    // page is 1-indexed
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
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.8),
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
            if (_totalPages > 0)
              Text(
                'Page ${_currentPage + 1} of $_totalPages',
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: isBookmarked ? Colors.indigoAccent : Colors.white,
            ),
            onPressed: () => ref.read(studyControllerProvider).toggleBookmark(widget.note.id),
          ),
        ],
      ),
      body: PdfViewPinch(
        controller: _pdfController,
        onDocumentLoaded: (document) {
          setState(() {
            _totalPages = document.pagesCount;
          });
        },
        onPageChanged: _onPageChanged,
        onDocumentError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error opening document: $error')),
          );
          Navigator.pop(context);
        },
      ),
      bottomNavigationBar: _totalPages > 0 ? _buildProgressSlider() : null,
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
                  _pdfController.jumpToPage(val.toInt() + 1);
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
