// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// StackedNavigatorGenerator
// **************************************************************************

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:eduvy/application.dart' as _i2;
import 'package:eduvy/ui/screens/dashboard/ceo/ceo_dashboard_view.dart' as _i5;
import 'package:eduvy/ui/screens/dashboard/ceo/ceo_subscriptions_view.dart'
    as _i7;
import 'package:eduvy/ui/screens/dashboard/ceo/ceo_tenant_payments_view.dart'
    as _i9;
import 'package:eduvy/ui/screens/dashboard/ceo/ceo_tenants_view.dart' as _i8;
import 'package:eduvy/ui/screens/dashboard/company/company_dashboard_view.dart'
    as _i6;
import 'package:eduvy/ui/screens/login/login_view.dart' as _i4;
import 'package:eduvy/ui/screens/splash/splash_view.dart' as _i3;
import 'package:flutter/material.dart' as _i10;
import 'package:stacked/stacked.dart' as _i1;
import 'package:stacked_services/stacked_services.dart' as _i11;

class Routes {
  static const application = '/';
  static const splashView = '/splash-view';
  static const loginView = '/login-view';
  static const ceoDashboardView = '/ceo-dashboard';
  static const companyDashboardView = '/company-dashboard';
  static const ceoSubscriptionsView = '/ceo-subscriptions';
  static const ceoTenantsView = '/ceo-tenants';
  static const ceoTenantPaymentsView = '/ceo-tenant-payments';

  static const all = <String>{
    application,
    splashView,
    loginView,
    ceoDashboardView,
    companyDashboardView,
    ceoSubscriptionsView,
    ceoTenantsView,
    ceoTenantPaymentsView,
  };
}

class StackedRouter extends _i1.RouterBase {
  final _routes = <_i1.RouteDef>[
    _i1.RouteDef(Routes.application, page: _i2.Application),
    _i1.RouteDef(Routes.splashView, page: _i3.SplashView),
    _i1.RouteDef(Routes.loginView, page: _i4.LoginView),
    _i1.RouteDef(Routes.ceoDashboardView, page: _i5.CeoDashboardView),
    _i1.RouteDef(Routes.companyDashboardView, page: _i6.CompanyDashboardView),
    _i1.RouteDef(Routes.ceoSubscriptionsView, page: _i7.CeoSubscriptionsView),
    _i1.RouteDef(Routes.ceoTenantsView, page: _i8.CeoTenantsView),
    _i1.RouteDef(Routes.ceoTenantPaymentsView, page: _i9.CeoTenantPaymentsView),
  ];

  final _pagesMap = <Type, _i1.StackedRouteFactory>{
    _i2.Application: (data) {
      final args = data.getArgs<ApplicationArguments>(
        orElse: () => const ApplicationArguments(),
      );
      return _i10.MaterialPageRoute<dynamic>(
        builder: (context) => _i2.Application(key: args.key),
        settings: data,
      );
    },
    _i3.SplashView: (data) {
      final args = data.getArgs<SplashViewArguments>(
        orElse: () => const SplashViewArguments(),
      );
      return _i10.MaterialPageRoute<dynamic>(
        builder: (context) => _i3.SplashView(key: args.key),
        settings: data,
      );
    },
    _i4.LoginView: (data) {
      final args = data.getArgs<LoginViewArguments>(
        orElse: () => const LoginViewArguments(),
      );
      return _i10.MaterialPageRoute<dynamic>(
        builder: (context) => _i4.LoginView(key: args.key),
        settings: data,
      );
    },
    _i5.CeoDashboardView: (data) {
      final args = data.getArgs<CeoDashboardViewArguments>(
        orElse: () => const CeoDashboardViewArguments(),
      );
      return _i10.MaterialPageRoute<dynamic>(
        builder: (context) => _i5.CeoDashboardView(key: args.key),
        settings: data,
      );
    },
    _i6.CompanyDashboardView: (data) {
      final args = data.getArgs<CompanyDashboardViewArguments>(
        orElse: () => const CompanyDashboardViewArguments(),
      );
      return _i10.MaterialPageRoute<dynamic>(
        builder: (context) => _i6.CompanyDashboardView(key: args.key),
        settings: data,
      );
    },
    _i7.CeoSubscriptionsView: (data) {
      final args = data.getArgs<CeoSubscriptionsViewArguments>(
        orElse: () => const CeoSubscriptionsViewArguments(),
      );
      return _i10.MaterialPageRoute<dynamic>(
        builder: (context) => _i7.CeoSubscriptionsView(key: args.key),
        settings: data,
      );
    },
    _i8.CeoTenantsView: (data) {
      final args = data.getArgs<CeoTenantsViewArguments>(
        orElse: () => const CeoTenantsViewArguments(),
      );
      return _i10.MaterialPageRoute<dynamic>(
        builder: (context) => _i8.CeoTenantsView(key: args.key),
        settings: data,
      );
    },
    _i9.CeoTenantPaymentsView: (data) {
      final args = data.getArgs<CeoTenantPaymentsViewArguments>(
        orElse: () => const CeoTenantPaymentsViewArguments(),
      );
      return _i10.MaterialPageRoute<dynamic>(
        builder: (context) => _i9.CeoTenantPaymentsView(key: args.key),
        settings: data,
      );
    },
  };

  @override
  List<_i1.RouteDef> get routes => _routes;

  @override
  Map<Type, _i1.StackedRouteFactory> get pagesMap => _pagesMap;
}

// ── Argument classes ─────────────────────────────────────────────────────────

class ApplicationArguments {
  const ApplicationArguments({this.key});
  final _i10.Key? key;
  @override
  String toString() => '{"key": "$key"}';
  @override
  bool operator ==(covariant ApplicationArguments other) =>
      identical(this, other) || other.key == key;
  @override
  int get hashCode => key.hashCode;
}

class SplashViewArguments {
  const SplashViewArguments({this.key});
  final _i10.Key? key;
  @override
  String toString() => '{"key": "$key"}';
  @override
  bool operator ==(covariant SplashViewArguments other) =>
      identical(this, other) || other.key == key;
  @override
  int get hashCode => key.hashCode;
}

class LoginViewArguments {
  const LoginViewArguments({this.key});
  final _i10.Key? key;
  @override
  String toString() => '{"key": "$key"}';
  @override
  bool operator ==(covariant LoginViewArguments other) =>
      identical(this, other) || other.key == key;
  @override
  int get hashCode => key.hashCode;
}

class CeoDashboardViewArguments {
  const CeoDashboardViewArguments({this.key});
  final _i10.Key? key;
  @override
  String toString() => '{"key": "$key"}';
  @override
  bool operator ==(covariant CeoDashboardViewArguments other) =>
      identical(this, other) || other.key == key;
  @override
  int get hashCode => key.hashCode;
}

class CompanyDashboardViewArguments {
  const CompanyDashboardViewArguments({this.key});
  final _i10.Key? key;
  @override
  String toString() => '{"key": "$key"}';
  @override
  bool operator ==(covariant CompanyDashboardViewArguments other) =>
      identical(this, other) || other.key == key;
  @override
  int get hashCode => key.hashCode;
}

class CeoSubscriptionsViewArguments {
  const CeoSubscriptionsViewArguments({this.key});
  final _i10.Key? key;
  @override
  String toString() => '{"key": "$key"}';
  @override
  bool operator ==(covariant CeoSubscriptionsViewArguments other) =>
      identical(this, other) || other.key == key;
  @override
  int get hashCode => key.hashCode;
}

class CeoTenantsViewArguments {
  const CeoTenantsViewArguments({this.key});
  final _i10.Key? key;
  @override
  String toString() => '{"key": "$key"}';
  @override
  bool operator ==(covariant CeoTenantsViewArguments other) =>
      identical(this, other) || other.key == key;
  @override
  int get hashCode => key.hashCode;
}

class CeoTenantPaymentsViewArguments {
  const CeoTenantPaymentsViewArguments({this.key});
  final _i10.Key? key;
  @override
  String toString() => '{"key": "$key"}';
  @override
  bool operator ==(covariant CeoTenantPaymentsViewArguments other) =>
      identical(this, other) || other.key == key;
  @override
  int get hashCode => key.hashCode;
}

// ── NavigationService extensions ─────────────────────────────────────────────

extension NavigatorStateExtension on _i11.NavigationService {
  Future<dynamic> navigateToApplication({_i10.Key? key}) async =>
      navigateTo<dynamic>(Routes.application,
          arguments: ApplicationArguments(key: key));

  Future<dynamic> navigateToSplashView({_i10.Key? key}) async =>
      navigateTo<dynamic>(Routes.splashView,
          arguments: SplashViewArguments(key: key));

  Future<dynamic> navigateToLoginView({_i10.Key? key}) async =>
      navigateTo<dynamic>(Routes.loginView,
          arguments: LoginViewArguments(key: key));

  Future<dynamic> navigateToCeoDashboardView({_i10.Key? key}) async =>
      navigateTo<dynamic>(Routes.ceoDashboardView,
          arguments: CeoDashboardViewArguments(key: key));

  Future<dynamic> navigateToCompanyDashboardView({_i10.Key? key}) async =>
      navigateTo<dynamic>(Routes.companyDashboardView,
          arguments: CompanyDashboardViewArguments(key: key));

  Future<dynamic> navigateToCeoSubscriptionsView({_i10.Key? key}) async =>
      navigateTo<dynamic>(Routes.ceoSubscriptionsView,
          arguments: CeoSubscriptionsViewArguments(key: key));

  Future<dynamic> navigateToCeoTenantsView({_i10.Key? key}) async =>
      navigateTo<dynamic>(Routes.ceoTenantsView,
          arguments: CeoTenantsViewArguments(key: key));

  Future<dynamic> navigateToCeoTenantPaymentsView({_i10.Key? key}) async =>
      navigateTo<dynamic>(Routes.ceoTenantPaymentsView,
          arguments: CeoTenantPaymentsViewArguments(key: key));

  Future<dynamic> replaceWithLoginView({_i10.Key? key}) async =>
      replaceWith<dynamic>(Routes.loginView,
          arguments: LoginViewArguments(key: key));

  Future<dynamic> replaceWithSplashView({_i10.Key? key}) async =>
      replaceWith<dynamic>(Routes.splashView,
          arguments: SplashViewArguments(key: key));
}
