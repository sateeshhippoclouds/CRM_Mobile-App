// Flutter imports:
import 'package:flutter/material.dart';

// Project imports:
import 'app_colors.dart';

abstract class Prefs {
  static const String isLoggedIn = "isLoggedIn";
   static const String isEmailVerified = 'isEmailVerified'; 
  static const String stepCount = "stepCount";
  static const String ageLimit = "ageLimit";
  static const String user = "user";
  static const String uid = "user_id";
  static const String profile = "profile";
  static const String home = "home";
  static const String collegeReg = "collegeRegistrationStep1";
}

abstract class NotificationChannel {
  static const String channelHighId = "high_importance_channel";
  static const String channelHighName = "High Importance Notifications";
  static const String channelLowId = "low_importance_channel";
  static const String channelLowName = "Low Importance Notifications";
  static const int foregroundServiceNotificationId = 888;
}


abstract class AppRegexp {
  static final RegExp nameRegExp = RegExp(r"^[a-zA-Z]+(\s+[a-zA-Z]+)*$");
  static final RegExp abnRegExp = RegExp(r"^(\d *?){11}$");
  static final RegExp phoneRegExp = RegExp("^[0-9]{10}");
  static final RegExp yearRegExp = RegExp(r"^(19|20)\d{2}$");
  static final RegExp percentageRegExp = RegExp(r"^((100)|(\d{1,2}(.\d{4})?))$");
  static final RegExp panRegExp = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
  static final RegExp aadhaarRegExp = RegExp(r'^[2-9]{1}[0-9]{3}[0-9]{4}[0-9]{4}$');
  static final RegExp gstRegExp =
  RegExp(r"\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}[A-Z]{1}[A-Z\d]{1}");
  static final RegExp urlRegExp = RegExp(
      r"^(?:http(s)?://)?[\w.-]+(?:\.[\w.-]+)+[\w\-._~:/?#[\]@!$&'()*+,;=]+$");
  static final RegExp passwordRegExp = RegExp(r'^[a-zA-Z0-9]+([a-zA-Z0-9]+)*$');
  static final RegExp emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
}


double getStatusBarHeight(context) {
  return (MediaQuery.of(context).viewPadding.top);
}

enum ToastType {
  success(0),
  error(1);

  const ToastType(this.value);

  final int value;

  static ToastType fromValue(int? value) {
    switch (value) {
      case 0:
        return success;
      case 1:
        return error;
      default:
        return error;
    }
  }

  Color get toColor {
    if (this == success) {
      return Palette.primary;
    }
    return Colors.red;
  }
}
