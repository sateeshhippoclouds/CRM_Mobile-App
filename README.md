# eduvy

# build runner
flutter packages pub run build_runner build --delete-conflicting-outputs
dart run build_runner build --delete-conflicting-outputs
# build runner - watch
flutter pub run build_runner watch --use-polling-watcher --delete-conflicting-outputs

# import sorter
flutter pub run import_sorter:main

### ------- Please go through each page for more info   ------- ###

This Project Contains
* [main] ->
  Main initializations (FirebaseMessaging) etc...
* [application] ->
  FirebaseMessaging background foreground etc...
    * firebase_options.dart --> update firebase using CLI
* [app] ->
    * extensions.dart - common extensions
    * global.dart     - common functions (usage class Foo with Global{}) pickImage,cropImage,launchInBrowser etc..
    * utils.dart      - printLog, printDebugLog, getDeviceType etc
* [constants] ->
  app_constants.dart - AppRegexp etc...
* [services] ->
    * api_service.dart - common api calls and response fetching (Pagination, Multipart, POST, GET example)
    * api_helper.dart  - all functions to perform related to api
    * firebase_auth_service.dart  - firebase phone auth
    * notification_service.dart   - notification handling
    * user_service.dart   - user related
* [UI] ->
    * bottom-sheet - sample bs custom UI
    * dialog       - sample dialog custom UI
    * [screens] ->
    * splash_view.dart - splash screen redirections
    * login_view.dart  - firebase phone auth
    * otp_view.dart    - firebase otp
    * registration_form_view.dart - register view with sample api call using api helper
    * home_view.dart - home with pagination api sample
* [widgets] ->
    * shared.dart - commonAlertDialog, CustomFormField, PrimaryButton

# Don't forget to remove the assets and fonts etc you don't need

# Rename package/app
[android]
change_app_package_name: ^1.1.0
---> flutter pub run change_app_package_name:main com.eduvy.app

[iOS]
rename: ^2.1.1
flutter pub global activate rename

flutter pub global run rename --bundleId com.eduvy.app --target ios

APP Rename :-
flutter pub global run rename --appname "APP NAME" --target ios

# Firebase CLI
https://codewithandrea.com/articles/flutter-firebase-flutterfire-cli/

#to get the SHA1 key
Right click "gradlew" file and select Open in Terminal -
Go to the terminal view and paste: gradlew signingReport

mailto:eduvytech@gmail.com
pass:- eduvytech000 