import 'package:flutter/material.dart';

import 'package:titlebar_buttons/titlebar_buttons.dart';
import 'package:window_manager/window_manager.dart';

import 'package:elastic_dashboard/services/settings.dart';

class CustomAppBar extends AppBar {
  final String titleText;
  final Color? appBarColor;
  final VoidCallback? onWindowClose;

  final List<Widget> trailing;

  static const double _leadingSize = 500;
  static const ThemeType buttonType = ThemeType.materia;

  CustomAppBar({
    super.key,
    this.titleText = 'Elastic',
    this.appBarColor,
    this.onWindowClose,
    this.trailing = const [],
    required super.leading,
  }) : super(
          toolbarHeight: 36,
          backgroundColor: appBarColor ?? const Color.fromARGB(255, 25, 25, 25),
          elevation: 0.0,
          scrolledUnderElevation: 0.0,
          leadingWidth: _leadingSize,
          centerTitle: true,
          notificationPredicate: (_) => false,
          actions: [
            SizedBox(
              width: _leadingSize,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Expanded(
                    child: _WindowDragArea(),
                  ),
                  ...trailing.map((e) => ExcludeFocus(child: e)),
                  InkWell(
                    canRequestFocus: false,
                    onTap: () async => await windowManager.minimize(),
                    child: const AbsorbPointer(
                      child: DecoratedMinimizeButton(
                        type: buttonType,
                        onPressed: null,
                      ),
                    ),
                  ),
                  InkWell(
                    canRequestFocus: false,
                    onTap: () async {
                      if (!Settings.isWindowMaximizable) {
                        return;
                      }

                      if (await windowManager.isMaximized()) {
                        windowManager.unmaximize();
                      } else {
                        windowManager.maximize();
                      }
                    },
                    child: const AbsorbPointer(
                      child: DecoratedMaximizeButton(
                        type: buttonType,
                        onPressed: null,
                      ),
                    ),
                  ),
                  InkWell(
                    canRequestFocus: false,
                    hoverColor: Colors.red,
                    onTap: () async {
                      if (onWindowClose == null) {
                        await windowManager.close();
                      } else {
                        onWindowClose.call();
                      }
                    },
                    child: const AbsorbPointer(
                      child: DecoratedCloseButton(
                        type: buttonType,
                        onPressed: null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          title: _WindowDragArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: Text(
                    titleText,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
          ),
        );
}

class _WindowDragArea extends StatelessWidget {
  final Widget? child;

  const _WindowDragArea({this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) {
        if (!Settings.isWindowDraggable) {
          return;
        }

        windowManager.startDragging();
      },
      onDoubleTap: () async {
        if (!Settings.isWindowMaximizable) {
          return;
        }

        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
      child: child ?? Container(),
    );
  }
}
