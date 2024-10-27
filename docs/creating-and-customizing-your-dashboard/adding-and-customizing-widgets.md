Widgets are the cards on the grid that display information about the robot.

## Adding Widgets

On the menu bar at the top of the screen, there is a button that says "Add Widget" with a **+**. Clicking it will open the widget dialog, which will look like this. You must be connected to your robot in order for tiles to appear.

![Widget Dialog](https://github.com/Gold872/elastic-dashboard/blob/main/screenshots/adding_widgets/dialog_collapsed.png)

By clicking on each table name, you will reveal any sub-tables that Network Tables has.

![Sub-Tables](https://github.com/Gold872/elastic-dashboard/blob/main/screenshots/adding_widgets/dialog_expanded.png)

To make finding the data you want to display easier, you can type a search query into the search box at the bottom of the dialog. This will only display values that match the search query.

![Search Query](https://github.com/Gold872/elastic-dashboard/blob/main/screenshots/adding_widgets/dialog_search.png)

When you find the data for the widget you would like to add, simply click on it, and drag it to the location you want to place the widget. A red or green outline will appear indicating weather or not the location you are hovering on is a valid location.

![Dragging a Widget to the Grid](https://github.com/Gold872/elastic-dashboard/blob/main/screenshots/adding_widgets/dialog_dragging.png)

A widget will be dragged only if there is a valid type for that widget. For example, if you try to drag a boolean value from the dialog, a boolean box will be dragged by your mouse cursor. If you drag a table such as `/Shuffleboard`, which does not have a data type property to it, nothing will appear under your mouse cursor.

When you let go of your mouse, the widget will be added to the grid.

After you place a widget on the grid, you can resize it by dragging the edges of the widget's box.

![Resizing a Widget](https://github.com/Gold872/elastic-dashboard/blob/main/screenshots/adding_widgets/dialog_resizing.png)

## Customizing Widgets

When you right click on a widget container (the card that holds the widget), a context menu will appear with several options: `Edit Properties`, or `Remove`.

![Right Click Menu](https://github.com/Gold872/elastic-dashboard/blob/main/screenshots/adding_widgets/context_menu.png)

Clicking `Remove` will remove the widget from the grid, and clicking `Edit Properties` will open a menu with several customization options.

![Edit Properties Menu](https://github.com/Gold872/elastic-dashboard/blob/main/screenshots/adding_widgets/properties_menu.png)

Every widget will have `Container Settings` and `Network Tables Settings`. The container settings allow you to change the title and widget type. Depending on what type of data you are displaying, you are able to change the widget type. You must be connected to your robot for any additional options to appear.

Under `Container Settings`, there will be settings unique for the widget type, titled `<Widget Type> Settings`. Not every widget will have unique properties to it, if your widget does not have any unique edit properties, there will not be anything listed.

Under `Network Tables Settings`, there will be several advanced settings allowing you to change the topic that the widget will be receiving data from, along with its update period. It is recommended to not change any of these unless you are familiar with the basics of Network Tables. For more info on Network Tables, see [What is NetworkTables - FIRST Robotics Competition Documentation](https://docs.wpilib.org/en/stable/docs/software/networktables/networktables-intro.html).

## Adding a Voltage Widget (Example)

This gif is an example of how to add a widget. This adds a widget that displays the voltage, and changes a few of its settings.

![Adding Voltage Example](https://github.com/Gold872/elastic-dashboard/blob/main/screenshots/adding_widgets/adding_voltage.gif)

## Copying and Pasting Widgets

Elastic supports copying and pasting widgets and layouts between different tabs. When right clicking on a widget, there is an option to copy it to the clipboard.

*Note: This is separate from the system clipboard*

![Copying Widget](https://github.com/Gold872/elastic-dashboard/blob/main/screenshots/widget_copy_paste/copying_widget.png)

Right clicking in an empty spot will show a button to paste the widget. This will attempt to insert the widget into the grid with the top left corner of the widget in the grid space that the cursor is hovering in. If the widget does not fit on the grid, then it will not paste.

![Pasting Widget](https://github.com/Gold872/elastic-dashboard/blob/main/screenshots/widget_copy_paste/pasting_widget.png)

![Widget After Pasting](https://github.com/Gold872/elastic-dashboard/blob/main/screenshots/widget_copy_paste/widget_after_pasting.png)

## Camera Streams

Elastic only supports adding camera streams that are published to the RoboRIO's Camera Server. If you have a USB camera plugged into your RoboRIO, adding this line of code in your `robotInit()` method will allow you to add a camera stream to your dashboard.

```java
CameraServer.startAutomaticCapture();
```

To add a camera stream, navigate to the `CameraPublisher` table, and there will be different tables for different camera streams that can be viewed. Dragging one of these tables will create a Camera Stream widget that displays live video from the camera.

![Adding Camera Stream](https://github.com/Gold872/elastic-dashboard/blob/main/screenshots/adding_widgets/camera_stream.png)