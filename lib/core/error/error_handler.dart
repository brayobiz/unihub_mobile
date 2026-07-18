import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_logger.dart';

class AppErrorHandler {
  /// Maps any caught exception to a user-friendly string message.
  static String mapError(dynamic error) {
    if (error is FirebaseAuthException) {
      return _handleAuthException(error);
    }
    
    if (error is FirebaseException) {
      return _handleFirestoreException(error);
    }

    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    }

    if (error is HttpException) {
      return 'Server error. Please try again later.';
    }

    // Handle generic exceptions that might have been thrown manually
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('exception: ')) {
      return error.toString().replaceAll('Exception: ', '');
    }

    if (errorString.contains('network error') || errorString.contains('connection reset')) {
      return 'Network error: Please check your internet connection.';
    }

    if (errorString.contains('permission denied')) {
      return 'You don\'t have permission to perform this action.';
    }

    return 'Something went wrong. Please try again.';
  }

  static String _handleAuthException(FirebaseAuthException e) {
    AppLogger.warning('🛑 Auth Error Code: ${e.code}', 'ERROR_HANDLER');
    switch (e.code) {
      case 'user-not-found':
      case 'user-disabled':
      case 'invalid-email':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in instead.';
      case 'operation-not-allowed':
        return 'This authentication method is currently disabled.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again in a few minutes.';
      case 'requires-recent-login':
        return 'This operation is sensitive and requires recent authentication. Please sign in again.';
      default:
        return e.message ?? 'An unexpected authentication error occurred.';
    }
  }

  static String _handleFirestoreException(FirebaseException e) {
    AppLogger.warning('🛑 Firestore Error Code: ${e.code}', 'ERROR_HANDLER');
    switch (e.code) {
      case 'permission-denied':
        return 'You don\'t have permission to perform this action.';
      case 'unavailable':
        return 'The service is temporarily unavailable. Please try again later.';
      case 'not-found':
        return 'The requested information was not found.';
      case 'already-exists':
        return 'This record already exists.';
      case 'deadline-exceeded':
        return 'The request took too long. Please try again.';
      case 'resource-exhausted':
        return 'Ulify is experiencing high traffic. Please try again in a moment.';
      case 'failed-precondition':
        return 'This action cannot be completed in the current state.';
      case 'aborted':
        return 'The operation was aborted. Please try again.';
      case 'unauthenticated':
        return 'Your session has expired. Please sign in again.';
      default:
        return 'Database error. Please try again later.';
    }
  }
}
