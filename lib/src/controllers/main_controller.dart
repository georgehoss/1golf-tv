import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/app_response.dart';
import '../models/home_components.dart';
import '../models/league_details.dart';
import '../models/show_details.dart';
import '../providers/golf_provider.dart';
import 'auth_controller.dart';

/// Home/navigation state for the TV app: drawer/focus chrome (mirrors the
/// baseball TV base) plus the golf content-loading logic (mirrors
/// `one_golf_app`'s MainController, trimmed to what the Home + league/show
/// detail pages need).
class MainController extends GetxController {
  // ─── TV navigation chrome ──────────────────────────────────────────────

  var exitApp = false.obs;
  void setExitApp(bool value) => exitApp.value = value;

  var currentIndex = 1.obs;
  void setCurrentIndex(int index) {
    currentIndex.value = index;
    update();
  }

  var scaffoldKey = GlobalKey<ScaffoldState>().obs;
  var canOpenDrawer = true.obs;

  void openDrawer() {
    if (canOpenDrawer.isTrue) {
      scaffoldKey.value.currentState!.openDrawer();
    } else if (Get.context != null) {
      Navigator.of(Get.context!).pop();
    }
  }

  void closeDrawer() => scaffoldKey.value.currentState!.openEndDrawer();

  var mainFocus = FocusNode().obs;
  void setMainFocus(FocusNode focus) => mainFocus.value = focus;

  // ─── Live channel ──────────────────────────────────────────────────────

  Rx<OBChannel?> selectedChannel = Rx<OBChannel?>(null);

  void selectChannel(OBChannel channel) {
    selectedChannel.value = channel;
    update();
  }

  void setFirstChannelAsDefault() {
    if (selectedChannel.value != null) return;
    final items = homeComponents.value.channels?.items;
    if (items != null && items.isNotEmpty) {
      selectedChannel.value = items.first;
    }
  }

  // ─── Home data ─────────────────────────────────────────────────────────

  var isLoading = true.obs;
  var loadFailed = false.obs;
  var homeComponents = HomeComponents().obs;
  var hasHomeComponents = false.obs;

  Future<void> getData() async {
    isLoading.value = true;
    loadFailed.value = false;
    update();
    try {
      final response = await GolfProvider().getHome();
      final home = _findScreen(response, 'home');
      if (home?.components == null) {
        loadFailed.value = true;
      } else {
        homeComponents.value = HomeComponents.fromJson(home!.components!);
        hasHomeComponents.value = true;
        setFirstChannelAsDefault();
      }
    } catch (e) {
      loadFailed.value = true;
    } finally {
      isLoading.value = false;
      update();
    }
  }

  AppResponse? _findScreen(AppResponseList response, String name) {
    for (final item in response.list) {
      if (item.name == name) return item;
    }
    return null;
  }

  // ─── Show detail ───────────────────────────────────────────────────────

  var selectedShow = VideoItem().obs;
  var isLoadingShow = false.obs;
  var showDetails = Rx<ShowDetails?>(null);
  var hasShowDetail = false.obs;

  void setSelectedShow(VideoItem show) {
    selectedShow.value = show;
    getShowDetails();
    update();
  }

  Future<void> getShowDetails() async {
    isLoadingShow(true);
    update();
    final response = await GolfProvider().getShowDetails(
      selectedShow.value.objectId ?? 0,
    );
    showDetails.value = response;
    hasShowDetail.value =
        response?.components?.items != null &&
        response!.components!.items!.isNotEmpty;
    isLoadingShow(false);
    update();
  }

  // ─── League/Tour detail ────────────────────────────────────────────────

  var selectedLeague = VideoItem().obs;
  var isLoadingLeague = false.obs;
  var leagueDetails = Rx<LeagueDetails?>(null);
  var hasLeagueDetail = false.obs;

  void setSelectedLeague(VideoItem league) {
    selectedLeague.value = league;
    getLeagueDetails();
    update();
  }

  Future<void> getLeagueDetails() async {
    isLoadingLeague(true);
    update();
    final response = await GolfProvider().getLeagueDetails(
      selectedLeague.value.objectId ?? 0,
    );
    leagueDetails.value = response;
    hasLeagueDetail.value =
        response?.components?.items != null &&
        response!.components!.items!.isNotEmpty;
    isLoadingLeague(false);
    update();
  }

  // ─── Session ───────────────────────────────────────────────────────────

  Future<void> logout() => Get.find<AuthController>().logout();
}
