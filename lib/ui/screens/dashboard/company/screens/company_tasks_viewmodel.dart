import 'package:stacked/stacked.dart';

class CompanyTasksViewModel extends BaseViewModel {
  List<Map<String, dynamic>> items = [];
  String? fetchError;

  Future<void> init() async {
    setBusy(true);
    fetchError = null;
    setBusy(false);
  }
}
