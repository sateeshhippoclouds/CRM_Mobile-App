import 'package:stacked/stacked.dart';

class CompanyTermsViewModel extends BaseViewModel {
  List<Map<String, dynamic>> items = [];
  String? fetchError;

  Future<void> init() async {
    setBusy(true);
    fetchError = null;
    setBusy(false);
  }
}
