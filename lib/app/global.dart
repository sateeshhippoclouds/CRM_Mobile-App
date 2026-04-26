// Dart imports:
import 'dart:io';

// Flutter imports:
import 'package:eduvy/app/utils.dart';

// Package imports:
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// To use [Global] functions
///
/// ```dart
/// class Foo with Global{}
/// ```
/// [more details here](https://stackoverflow.com/a/70462094/9427138)
///
/// Contribution from [adarshvijayanp] - [Buy me a coffee](https://www.instagram.com/adarshvijayanp)
/*
* mixin LaunchWebView on StatelessWidget { // you can also constrain the mixin to specific classes using on in this line.
  void launchWebView() {
    // Add web view logic here. We can add variables to the mixin itself as well.
  }
}
*
*
* class ExampleClass extends StatelessWidget with LaunchWebView {
  Widget build(BuildContext context) {
    ....
  }

  void testFunction() {
    // We now have access to launchWebView().
    launchWebView();
  }
}
* */

mixin Global {
  /// Common `ImagePicker` which return a XFile
  ///
  /// If you want to crop: use [cropImage] and pass [pickedImage] path
  ///```dart
  ///  var pickedImage = await pickImage();
  ///     if(pickedImage.isNotNull){
  ///       var croppedImage = await cropImage(path: pickedImage!.path);
  ///     }
  /// ```
  /// see also [cropImage]
  Future<XFile?> pickImage(
      {bool showGallery = true, bool openFrontCamera = false}) async {
    var source = await dialogService.showCustomDialog(
        data: showGallery, barrierDismissible: true);

    if (source?.data != null) {
      final ImagePicker picker = ImagePicker();
      printLog("source : ${source?.data}   openFrontCamera : $openFrontCamera");
      XFile? pickedImage = await picker.pickImage(
          source: source?.data,
          preferredCameraDevice:
              openFrontCamera ? CameraDevice.front : CameraDevice.rear);
      if (pickedImage != null) {
        return pickedImage;
      }
    } else {
      SmartDialog.showToast('Something went wrong, Try again!');
    }
    return null;
  }

  /// Common `ImageCropper` which return a File
  ///
  /// If you want to crop: pass `path` as [String]
  ///```dart
  ///
  ///  var croppedImage = await cropImage(path: pickedImage!.path);
  ///
  /// ```
  /// see also [pickImage]
  // Future<File?> cropImage({required String path}) async {
  //   final croppedFile = await ImageCropper().cropImage(
  //     sourcePath: path,
  //     compressFormat: ImageCompressFormat.jpg,
  //     compressQuality: 90,
  //     uiSettings: [
  //       AndroidUiSettings(
  //           toolbarColor: Palette.primary,
  //           toolbarWidgetColor: Colors.blue,
  //           initAspectRatio: CropAspectRatioPreset.original,
  //           activeControlsWidgetColor: Palette.blue,
  //           lockAspectRatio: false),
  //       IOSUiSettings(),
  //     ],
  //   );
  //   if (croppedFile != null) {
  //     var croppedImage = await croppedFile.readAsBytes();
  //
  //     final tempDir = await getTemporaryDirectory();
  //     File? uploadImageFile = await File(
  //       '${tempDir.path}/${getRandomString(6)}.jpg',
  //     ).create();
  //     uploadImageFile.writeAsBytesSync(croppedImage);
  //     printLog("UploadImageFile :: $uploadImageFile");
  //     return uploadImageFile;
  //   } else {
  //     //SmartDialog.showToast('Something went wrong, Try again!');
  //   }
  //   return null;
  // }

  /// common function to make calls and redirection to apps

  /// Call
  Future<void> makePhoneCall(String? callPhoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: callPhoneNumber,
    );
    await launchUrl(launchUri);
  }

  ///email
  Future<void> makeEmail(String? email) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: email,
      /*query: encodeQueryParameters(<String, String>{
        'subject': 'Example Subject & Symbols are allowed!',
      }),*/
    );
    await launchUrl(launchUri);
  }

  ///whatsapp
  Future<void> openWhatsapp(
      {required String? phoneNumberWithCountryCode, String text = ''}) async {
    launchUrl(Uri.parse('https://wa.me/$phoneNumberWithCountryCode?text=$text'),
        mode: LaunchMode.externalApplication);
  }

  ///launch Url
  Future<void> launchInBrowser(String url) async {
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } else {
      SmartDialog.showToast('Could not launch $url');
      throw 'Could not launch $url';
    }
  }

  ///launch map
  Future<void> openMap(double latitude, double longitude) async {
    String mapUrl = '';
    if (Platform.isIOS) {
      mapUrl = 'https://maps.apple.com/?daddr=$latitude,$longitude';
    } else {
      mapUrl =
          'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving';
    }

    if (await canLaunchUrl(Uri.parse(mapUrl))) {
      await launchUrl(Uri.parse(mapUrl), mode: LaunchMode.externalApplication);
    } else {
      SmartDialog.showToast('Could not open the map');
      throw 'Could not open the map.';
    }
  }
}
