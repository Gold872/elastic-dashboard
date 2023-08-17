import 'package:flutter/material.dart';
import 'package:titlebar_buttons/titlebar_buttons.dart';
import 'package:window_manager/window_manager.dart';

class CustomAppBar extends AppBar {
  final String titleText;
  final Color? appBarColor;
  final MenuBar menuBar;
  static const ThemeType buttonType = ThemeType.auto;

  CustomAppBar(
      {super.key,
      this.titleText = 'Elastic',
      this.appBarColor,
      required this.menuBar})
      : super(
          toolbarHeight: 40,
          backgroundColor: appBarColor ?? const Color.fromARGB(255, 35, 35, 35),
          leading: menuBar,
          leadingWidth: menuBar.children.length * 55,
          actions: [
            DecoratedMinimizeButton(
              type: buttonType,
              onPressed: () async => await windowManager.minimize(),
            ),
            DecoratedMaximizeButton(
              type: buttonType,
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
            ),
            DecoratedCloseButton(
              type: buttonType,
              onPressed: () async => await windowManager.close(),
            ),
          ],
          title: _WindowDragArea(
            child: Row(
              children: [
                Expanded(child: Center(child: Text(titleText))),
              ],
            ),
          ),
          centerTitle: true,
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
        windowManager.startDragging();
      },
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          windowManager.unmaximize();
        } else {
          windowManager.maximize();
        }
      },
      child: child ?? Container(),
    );
  }
}
