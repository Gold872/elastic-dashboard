import 'package:flutter/material.dart';

import 'package:titlebar_buttons/titlebar_buttons.dart';
import 'package:window_manager/window_manager.dart';

import 'package:elastic_dashboard/services/app_distributor.dart';
import 'package:elastic_dashboard/services/settings.dart';

class CustomAppBar extends AppBar {
  final String titleText;
  final Color? appBarColor;
  final VoidCallback? onWindowClose;

  static const ThemeType buttonType = ThemeType.materia;

  static const double windowButtonSize = 24;

  static const double titleSize = !isWPILib ? 60.0 : 140.0;

  CustomAppBar({
    super.key,
    this.titleText = 'Elastic',
    this.appBarColor,
    this.onWindowClose,
    required super.leadingWidth,
    required super.leading,
  }) : super(
          toolbarHeight: 36,
          backgroundColor: appBarColor ?? const Color.fromARGB(255, 25, 25, 25),
          elevation: 0.0,
          scrolledUnderElevation: 0.0,
          centerTitle: true,
          flexibleSpace: const _WindowDragArea(),
          notificationPredicate: (_) => false,
          actions: [
            InkWell(
              canRequestFocus: false,
              onTap: () async => await windowManager.minimize(),
              child: const AbsorbPointer(
                child: DecoratedMinimizeButton(
                  width: windowButtonSize,
                  height: windowButtonSize,
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
                  width: windowButtonSize,
                  height: windowButtonSize,
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
                  width: windowButtonSize,
                  height: windowButtonSize,
                  type: buttonType,
                  onPressed: null,
                ),
              ),
            ),
          ],
          title: _WindowDragArea(
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  (constraints.maxWidth >= titleSize)
                      ? Text(
                          titleText,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.visible,
                        )
                      : const SizedBox(),
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
