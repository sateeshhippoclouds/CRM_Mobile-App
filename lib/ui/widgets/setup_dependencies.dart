import 'package:flutter/material.dart';
import 'package:stacked_services/stacked_services.dart';

import '../../app/app.locator.dart';
import '../../app/utils.dart';

Future<void> setupDependencies() async {
  setupLocator();
  setupDialogs();
  setupBottomSheet();
}

typedef DialogBuilder = Widget Function(
  BuildContext,
  DialogRequest,
  Function(DialogResponse),
);

enum DialogType { none }

void setupDialogs() {
  dialogService.registerCustomDialogBuilders({});
}

typedef SheetBuilder = Widget Function(
  BuildContext,
  SheetRequest,
  void Function(SheetResponse),
);

enum BottomSheetType { none }

void setupBottomSheet() {
  sheetService.setCustomSheetBuilders({});
}
