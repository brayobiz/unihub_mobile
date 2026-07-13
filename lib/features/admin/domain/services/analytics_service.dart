import '../../data/repositories/admin_analytics_repository.dart';
import '../models/platform_analytics.dart';
import '../models/user_analytics.dart';
import '../models/feature_analytics.dart';

class AnalyticsService {
  final AdminAnalyticsRepository _repository;

  AnalyticsService(this._repository);

  Stream<PlatformAnalytics> watchPlatformAnalytics() {
    return _repository.watchPlatformAnalytics();
  }

  Stream<UserAnalytics> watchUserAnalytics() {
    return _repository.watchUserAnalytics();
  }

  Stream<FeatureAnalytics> watchFeatureAnalytics() {
    return _repository.watchFeatureAnalytics();
  }

  Future<PlatformAnalytics> getPlatformAnalytics() {
    return _repository.getPlatformAnalytics();
  }

  Future<UserAnalytics> getUserAnalytics() {
    return _repository.getUserAnalytics();
  }

  Future<FeatureAnalytics> getFeatureAnalytics() {
    return _repository.getFeatureAnalytics();
  }
}
