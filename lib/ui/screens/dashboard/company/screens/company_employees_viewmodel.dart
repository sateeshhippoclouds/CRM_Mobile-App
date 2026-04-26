import 'package:stacked/stacked.dart';

class CompanyEmployeesViewModel extends BaseViewModel {
  List<Map<String, dynamic>> items = [];
  String? fetchError;

  Future<void> init() async {
    setBusy(true);
    fetchError = null;
    setBusy(false);
  }
}
