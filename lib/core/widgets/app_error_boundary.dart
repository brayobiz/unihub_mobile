import 'package:flutter/material.dart';
import '../utils/app_logger.dart';
import 'error_view.dart';

Widget buildGlobalErrorWidget(FlutterErrorDetails details) {
  AppLogger.error('Flutter Framework Error', details.exception, details.stack, 'FRAMEWORK');
  return const ErrorView(
    message: 'Something went wrong in the app interface.',
    isFullPage: true,
  );
}

class AppErrorBoundary extends StatefulWidget {
  final Widget child;

  const AppErrorBoundary({super.key, required this.child});

  @override
  State<AppErrorBoundary> createState() => _AppErrorBoundaryState();
}

class _AppErrorBoundaryState extends State<AppErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ErrorView(
        message: 'Something went wrong. Our team has been notified.',
        onRetry: () {
          setState(() {
            _error = null;
            _stackTrace = null;
          });
        },
      );
    }

    return ErrorWidget.builder == null 
      ? widget.child 
      : widget.child;
  }
}
