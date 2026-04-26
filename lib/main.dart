import 'dart:io' show Platform, SecurityContext;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:statusbarz/statusbarz.dart';

import 'app/app.router.dart';
import 'constants/app_colors.dart';
import 'constants/app_strings.dart';
import 'gen/assets.gen.dart';
import 'gen/fonts.gen.dart';
import 'services/analyticsservice.dart';
import 'ui/tools/screen_size.dart';
import 'ui/widgets/setup_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && Platform.isAndroid) {
    final data = await PlatformAssetBundle().load(Assets.ca.letsEncryptR3);
    SecurityContext.defaultContext.setTrustedCertificatesBytes(
      data.buffer.asUint8List(),
    );
  }

  await setupDependencies();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, child) {
        return StatusbarzCapturer(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: AppStrings.appName,
            scrollBehavior: const ScrollBehavior().copyWith(overscroll: false),
            theme: ThemeData(
              useMaterial3: false,
              primarySwatch: generateMaterialColor(Palette.primary),
              primaryColor: Palette.primary,
              primaryColorDark: Palette.primaryDark,
              primaryColorLight: Palette.primaryLight,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Palette.primary,
                primary: Palette.primary,
                primaryContainer: Palette.primaryLight,
                secondary: Palette.primaryDark,
              ),
              fontFamily: FontFamily.plusJakartaSans,
              scaffoldBackgroundColor: Palette.scaffoldBackgroundColor,
            ),
            builder: FlutterSmartDialog.init(
              builder: (context, child) {
                ScreenSize.init(context);
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaleFactor: 1),
                  child: child!,
                );
              },
            ),
            navigatorKey: StackedService.navigatorKey,
            onGenerateRoute: StackedRouter().onGenerateRoute,
            navigatorObservers: [
              StackedService.routeObserver,
              Statusbarz.instance.observer,
              FlutterSmartDialog.observer,
              AnalyticsObserver(),
            ],
          ),
        );
      },
    );
  }
}
