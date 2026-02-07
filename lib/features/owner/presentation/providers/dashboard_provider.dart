import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardProvider =
    NotifierProvider<DashboardNotifier, int>(DashboardNotifier.new);

class DashboardNotifier extends Notifier<int> {
  @override
  int build() {
    return 0; // initial index
  }

  void setIndex(int index) {
    state = index;
  }
}