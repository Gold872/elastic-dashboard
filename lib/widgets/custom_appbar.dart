import 'package:flutter/material.dart';
import 'package:titlebar_buttons/titlebar_buttons.dart';
import 'package:window_manager/window_manager.dart';

class CustomAppBar extends AppBar {
  final String titleText;
  final Color? appBarColor;
  final MenuBar menuBar;
  final VoidCallback? onWindowClose;

  static const ThemeType buttonType = ThemeType.materia;

  CustomAppBar(
      {super.key,
      this.titleText = 'Elastic',
      this.appBarColor,
      this.onWindowClose,
      required this.menuBar})
      : super(
          toolbarHeight: 40,
          backgroundColor: appBarColor ?? const Color.fromARGB(255, 25, 25, 25),
          elevation: 0.0,
          scrolledUnderElevation: 0.0,
          leading: menuBar,
          leadingWidth: 460,
          centerTitle: true,
          actions: [
            ExcludeFocus(
              child: InkWell(
                onTap: () {},
                child: DecoratedMinimizeButton(
                  type: buttonType,
                  onPressed: () async => await windowManager.minimize(),
                ),
              ),
            ),
            ExcludeFocus(
              child: InkWell(
                onTap: () {},
                child: DecoratedMaximizeButton(
                  type: buttonType,
                  onPressed: () async {
                    if (await windowManager.isMaximized()) {
                      windowManager.unmaximize();
                    } else {
                      windowManager.maximize();
                    }
                  },
                ),
              ),
            ),
            ExcludeFocus(
              child: InkWell(
                hoverColor: Colors.red,
                onTap: () {},
                child: DecoratedCloseButton(
                  type: buttonType,
                  onPressed: () async {
                    if (onWindowClose == null) {
                      await windowManager.close();
                    } else {
                      onWindowClose.call();
                    }
                  },
                ),
              ),
            ),
          ],
          title: _WindowDragArea(
            child: Row(
              children: [
                Expanded(child: Center(child: Text(titleText))),
                const SizedBox(width: 365),
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
