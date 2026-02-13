// features/owner/presentation/providers/dashboard_layout_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardLayoutState {
  final int index;
  final bool isSidebarOpen;

  const DashboardLayoutState({
    required this.index,
    required this.isSidebarOpen,
  });

  DashboardLayoutState copyWith({
    int? index,
    bool? isSidebarOpen,
  }) {
    return DashboardLayoutState(
      index: index ?? this.index,
      isSidebarOpen: isSidebarOpen ?? this.isSidebarOpen,
    );
  }
}

class DashboardLayoutNotifier
    extends Notifier<DashboardLayoutState> {
  @override
  DashboardLayoutState build() {
    return const DashboardLayoutState(
      index: 0,
      isSidebarOpen: false,
    );
  }

  void toggleSidebar() {
    state = state.copyWith(isSidebarOpen: !state.isSidebarOpen);
  }

  void openSidebar() {
    state = state.copyWith(isSidebarOpen: true);
  }

  void closeSidebar() {
    state = state.copyWith(isSidebarOpen: false);
  }

  void onItemSelected(int index, bool isDesktop) {
    state = state.copyWith(index: index);

    if (!isDesktop && state.isSidebarOpen) {
      state = state.copyWith(isSidebarOpen: false);
    }
  }
}

final dashboardLayoutProvider =
    NotifierProvider<DashboardLayoutNotifier, DashboardLayoutState>(
  DashboardLayoutNotifier.new,
);