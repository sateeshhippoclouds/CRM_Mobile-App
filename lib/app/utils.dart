// Dart imports:
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';

// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Package imports:
import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:stacked_services/stacked_services.dart';

// Project imports:
import 'app.locator.dart';

///
/// Contribution from [adarshvijayanp] - [Buy me a coffee](https://www.instagram.com/adarshvijayanp)
///

NavigationService get navigationService => locator<NavigationService>();
DialogService get dialogService => locator<DialogService>();
BottomSheetService get sheetService => locator<BottomSheetService>();

String getDeviceType() {
  String deviceType = '';
  if (Platform.isAndroid) {
    deviceType = '1';
  } else if (Platform.isIOS) {
    deviceType = '2';
  }
  return deviceType;
}

/// A function that return image url after appending it's [baseUrlImage] with end point
String appendImageDomain(String? url) {
  //check contains http in url if you want to
  String imageUrl = '';
  url?.contains('http') ?? false
      ? imageUrl = (url ?? '')
      : imageUrl = (url ?? '');
  printLog('AppendImageDomain URL :: $imageUrl');
  return imageUrl;
}

/// A function that return Unique device ID in different app build modes
Future<String?> getUUID() async {
  if (Platform.isIOS) {
    var deviceInfo = DeviceInfoPlugin();
    var iosDeviceInfo = await deviceInfo.iosInfo;
    return iosDeviceInfo.identifierForVendor; // unique ID on iOS
  }
  if (Platform.isAndroid) {
    const _androidIdPlugin = AndroidId();
    return await _androidIdPlugin.getId(); // unique ID on Android
  }
  return null;
}

/// A function that print [debugPrint] in different app build modes
///
/// Default value is [kDebugMode].
///
/// You can change mode in 2 ways
///
/// 1. change it entirely
/// ```dart
/// void printDebugLog(value,{mode = 'change_mode_here'})
/// ```
/// 2. pass mode in one time call
///```dart
/// printDebugLog('',mode: 'pass_mode_here')
/// ```
///
/// Contribution from [adarshvijayanp] - [Buy me a coffee](https://www.instagram.com/adarshvijayanp)
///
/// See also:
///  * [printLog], which print [dev.log].
void printDebugLog(value, {mode = kDebugMode}) {
  switch (mode) {
    case kDebugMode:
      debugPrint("$value");
      break;
    case kReleaseMode:
      debugPrint("$value");
      break;
    case kIsWeb:
      debugPrint("$value");
      break;
    case kProfileMode:
      debugPrint("$value");
      break;
    default:
      debugPrint('PrintDebugLog: no mode selected');
  }
}

/// A function that print [dev.log] in different app build modes
///
/// Default value is [kDebugMode].
///
/// You can change mode in 2 ways
///
/// 1. change it entirely
/// ```dart
/// void printLog(value,{mode = 'change_mode_here'})
/// ```
/// 2. pass mode in one time call
///```dart
/// printLog('',mode: 'pass_mode_here')
/// ```
///
/// Contribution from [adarshvijayanp] - [Buy me a coffee](https://www.instagram.com/adarshvijayanp)
///
/// See also:
///  * [printDebugLog], which print [debugPrint].
void printLog(value, {mode = kDebugMode}) {
  switch (mode) {
    case kDebugMode:
      dev.log("$value");
      break;
    case kReleaseMode:
      dev.log("$value");
      break;
    case kIsWeb:
      dev.log("$value");
      break;
    case kProfileMode:
      dev.log("$value");
      break;
    default:
      dev.log('PrintLog: no mode selected');
  }
}

Color getRandomColors() {
  var generatedColor = Random().nextInt(Colors.primaries.length);
  var colors = Colors.primaries[generatedColor];

  return colors;
}

void dismissKeyboard(BuildContext context) {
  FocusScopeNode currentFocus = FocusScope.of(context);

  if (!currentFocus.hasPrimaryFocus) {
    currentFocus.unfocus();
  }
}

String removeZero(double? value) {
  if (value == null) return "0";
  RegExp regex = RegExp(r"([.]*0)(?!.*\d)");
  return value.toString().replaceAll(regex, "");
}

String getRandomString(int length) {
  const chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  Random rnd = Random();

  return String.fromCharCodes(
    Iterable.generate(
      length,
      (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
    ),
  );
}

String secToTime(int sec) {
  String time = Duration(seconds: sec).toString();
  return time.substring(time.indexOf(':') + 1, time.lastIndexOf('.'));
}

bool isAdult(DateTime dob) {
  DateTime adultDate = DateTime(dob.year + 21, dob.month, dob.day);
  return adultDate.isBefore(DateTime.now());
}

String listToString(List<String?> list) {
  String s = "";
  for (var i = 0; i < list.length; i++) {
    if (list[i] != null) {
      if (i < list.length - 1) {
        s += '${list[i]!}, ';
      } else {
        s += list[i]!;
      }
    }
  }
  return s;
}
