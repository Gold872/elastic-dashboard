# Shuffleboard API

{% hint style="warning" %}
Support for the Shuffleboard API is deprecated in favor of downloading full layouts from the robot, see the [migration guide](remote-layout-downloading.md#shuffleboard-api-migration-guide) for more information\
\
Shuffleboard API support will be removed after the 2025 season
{% endhint %}

Elastic supports generating layouts with code via the Shuffleboard API. Most features of the API work the same way as they do with Shuffleboard. However, some features are either not supported, or behave in different ways. The documentation for how to use the Shuffleboard API can be found [here](https://docs.wpilib.org/en/stable/docs/software/dashboards/shuffleboard/layouts-with-code/index.html).

**Tabs**

Tabs work the exact same way as with Shuffleboard, except the tabs created with code are not separated from tabs that are manually created.

**Setting Size, Position, & Widget Type**

Setting the size, position, and type of widget works the exact same way as it does with Shuffleboard. However, some widgets may not be implemented yet. To know if you can use a certain widget type, see [Widgets & Properties Reference](https://github.com/Gold872/elastic-dashboard/wiki/Widgets-List-&-Properties-Reference). For the `widgetType` parameter in the `withWidget()` method, put the name of the widget exactly how it is displayed in the widgets reference. For example, if you wanted to add a ComboBox Chooser with the API, you would call `.withWidget("ComboBox Chooser")`.

**Layouts**

Only List Layouts are supported.

**Properties**

Properties are supported, however some parameter names may differ from widget to widget. To see the parameters for each widget, see [Widgets & Properties Reference](https://github.com/Gold872/elastic-dashboard/wiki/Widgets-List-&-Properties-Reference). Be sure that the data types for each property are correct, otherwise widgets may not display properly.

**Recording**

Recording is not supported, and recordings will not be added. For logging data and viewing it after a match, we recommend using the [WPILib DataLogManager](https://docs.wpilib.org/en/stable/docs/software/telemetry/datalog.html) to save logs to your roboRIO, and use a software such as [AdvantageScope](https://github.com/Mechanical-Advantage/AdvantageScope) to visualize them. Recording logs directly from the roboRIO is much more reliable, will allow you to see data update much more frequently, and will not be affected by disconnections.
