import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/main_controller.dart';
import '../../models/home_components.dart';
import '../../models/items_list.dart';
import '../../utils/image_index.dart';
import '../../widgets/menu_drawer.dart';
import '../../widgets/side_bar_widtget.dart';
import '../../widgets/home/card_shadow.dart';
import '../../widgets/home/channels_live_widget.dart';
import '../../widgets/home/home_calendar_widget.dart';
import '../../widgets/home/show_list_widget.dart';
import '../../widgets/common/item_list_widget.dart';

/// Home screen. Section order and content widgets mirror `one_golf_app`
/// (channels/live → calendar → leagues → shows → itemslist_N) — NOT the
/// baseball TV base's layout, which shows different sections entirely.
///
/// Cross-section D-pad Up/Down is wired explicitly, chaining one `FocusNode`
/// per visible section (see `_focusFor`/`_buildContent`), instead of relying
/// on Flutter's default directional focus traversal — confirmed on-device
/// that the default traversal doesn't reliably escape horizontally-scrolling
/// rows stacked in a vertical scroll view.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final controller = Get.put(MainController());
  final authController = Get.find<AuthController>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final scrollController = ScrollController();

  final Map<String, FocusNode> _sectionFocus = {};
  bool _initialFocusRequested = false;

  FocusNode _focusFor(String key) =>
      _sectionFocus.putIfAbsent(key, () => FocusNode());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!authController.isAuthenticated.value) {
        Get.offAllNamed('/login');
      }
    });
    controller.scaffoldKey.value = _scaffoldKey;
    controller.getData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      authController.validateSessionIfNeeded();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final node in _sectionFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder(
      init: controller,
      builder: (_) {
        return PopScope(
          canPop: controller.exitApp.isTrue,
          onPopInvokedWithResult: (didPop, result) {
            if (controller.exitApp.isTrue) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            key: _scaffoldKey,
            drawer: const MenuDrawer(),
            body: Stack(
              children: [
                SizedBox(width: double.infinity, height: double.infinity),
                const CardShadow(startOpacity: 0.0, endOpacity: 0.6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SideBarWidget(
                      currentIndex: controller.currentIndex.value,
                      onFocusChange: () {
                        _scaffoldKey.currentState!.openDrawer();
                      },
                    ),
                    _buildContent(),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    if (controller.isLoading.isTrue && controller.hasHomeComponents.isFalse) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (controller.loadFailed.isTrue && controller.hasHomeComponents.isFalse) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, color: Colors.white70, size: 48),
              const SizedBox(height: 16),
              const Text(
                'No se pudo cargar el contenido',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: controller.getData,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final home = controller.homeComponents.value;
    final sections = _buildSections(home);

    final widgets = <Widget>[];
    for (var i = 0; i < sections.length; i++) {
      final entryFocus = _focusFor(sections[i].key);
      final nextFocus = i + 1 < sections.length
          ? _focusFor(sections[i + 1].key)
          : null;
      final previousFocus = i - 1 >= 0 ? _focusFor(sections[i - 1].key) : null;
      widgets.add(sections[i].builder(entryFocus, nextFocus, previousFocus));
    }

    if (!_initialFocusRequested && sections.isNotEmpty) {
      _initialFocusRequested = true;
      final firstFocus = _focusFor(sections.first.key);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        firstFocus.requestFocus();
      });
    }

    return Expanded(
      child: Column(
        children: [
          const SizedBox(height: 5),
          _appBar(),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(children: widgets),
            ),
          ),
        ],
      ),
    );
  }

  List<_HomeSection> _buildSections(HomeComponents home) {
    final sections = <_HomeSection>[];

    final hasChannels = home.channels?.items?.isNotEmpty ?? false;
    final hasLeagues = home.leagues?.items?.isNotEmpty ?? false;
    if (hasChannels || hasLeagues) {
      sections.add(
        _HomeSection(
          'channels',
          (entry, next, previous) => ChannelsLiveWidget(
            channels: home.channels ?? OBChannels(items: []),
            leagues: home.leagues,
            entryFocus: entry,
            nextFocus: next,
            previousFocus: previous,
          ),
        ),
      );
    }

    if (home.calendar?.isNotEmpty ?? false) {
      sections.add(
        _HomeSection(
          'calendar',
          (entry, next, previous) => HomeCalendar(
            calendar: home.calendar!,
            entryFocus: entry,
            nextFocus: next,
            previousFocus: previous,
          ),
        ),
      );
    }

    if (home.shows?.items?.isNotEmpty ?? false) {
      sections.add(
        _HomeSection(
          'shows',
          (entry, next, previous) => ShowListWidget(
            shows: home.shows!,
            entryFocus: entry,
            nextFocus: next,
            previousFocus: previous,
          ),
        ),
      );
    }

    final itemLists = <String, ItemsList?>{
      'itemslist_1': home.itemslist1,
      'itemslist_2': home.itemslist2,
      'itemslist_3': home.itemslist3,
      'itemslist_4': home.itemslist4,
      'itemslist_5': home.itemslist5,
      'itemslist_6': home.itemslist6,
      'itemslist_7': home.itemslist7,
      'itemslist_8': home.itemslist8,
      'itemslist_9': home.itemslist9,
      'itemslist_10': home.itemslist10,
      'itemslist_11': home.itemslist11,
      'itemslist_12': home.itemslist12,
      'itemslist_13': home.itemslist13,
      'itemslist_14': home.itemslist14,
      'itemslist_15': home.itemslist15,
      'itemslist_16': home.itemslist16,
      'itemslist_17': home.itemslist17,
      'itemslist_18': home.itemslist18,
      'itemslist_19': home.itemslist19,
      'itemslist_20': home.itemslist20,
    };

    for (final entry in itemLists.entries) {
      final list = entry.value;
      if (list?.items == null || list!.items!.isEmpty) continue;
      sections.add(
        _HomeSection(
          entry.key,
          (focus, next, previous) => ItemListWidget(
            itemsList: list,
            entryFocus: focus,
            nextFocus: next,
            previousFocus: previous,
          ),
        ),
      );
    }

    return sections;
  }

  Widget _appBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Expanded(child: SizedBox()),
          Image.asset(ImageIndex.logo, height: 40),
          const SizedBox(width: 20),
        ],
      ),
    );
  }
}

typedef _SectionBuilder =
    Widget Function(FocusNode entry, FocusNode? next, FocusNode? previous);

class _HomeSection {
  const _HomeSection(this.key, this.builder);
  final String key;
  final _SectionBuilder builder;
}
