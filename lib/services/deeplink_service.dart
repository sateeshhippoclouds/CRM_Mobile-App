import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:stacked_services/stacked_services.dart';

import '../app/app.router.dart';

class DeepLinkService {
  final NavigationService _navigationService = NavigationService();
  final _appLinks = AppLinks();
  StreamSubscription? _sub;

  void initialize() {
    _sub = _appLinks.uriLinkStream.listen((Uri uri) {
      _handleDeepLink(uri);
    }, onError: (_) {});
  }

  void _handleDeepLink(Uri uri) {
    if (uri.path == '/login-view') {
      _navigationService.navigateTo(Routes.loginView);
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
