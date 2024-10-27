In order for the program to connect to Network Tables, you need to be connected to your robot, and the program needs to know what the IP address of the robot is. There are several ways options to do this. If you click the settings gear at the top of the screen, there will be a dropdown menu for IP address connection.

## Driver Station

This is the easiest and recommended way of obtaining the IP address from the robot, as it requires very little manual work. First, connect to your robot, then open the Driver Station. Once the driver station is opened, the program will automatically retrieve the IP address from the TCP Port in the DS.

## Team Number (10.TE.AM.2)

_NOTE: This will not work when running a robot simulation_

This will connect to network tables using the radio's default IP address for your team number (10.TE.AM.2). For example, if your team number is 353, it will use the IP address `10.3.53.2`

For more information: see [IP Configuration - FIRST Robotics Competition documentation](https://docs.wpilib.org/en/stable/docs/networking/networking-introduction/ip-configurations.html)

## RoboRIO mDNS (roboRIO-###-FRC.local)

_NOTE: This will not work when running a robot simulation_

This will use the roboRIO mDNS to connect to your robot. If your team number is 353, it will attempt to connect with the mDNS address: `roboRIO-353-FRC.local`

## localhost

_NOTE: This will only work when running a robot simulation_

This will connect to network tables with the IP address: `localhost`

## Custom

This method is generally not recommended, but is available in case if it is needed. When you select the "Custom" option, you will be able to type your IP address in the "IP Address" text box.

# Connection Status

At the bottom of the screen, there is text displaying your connection status to Network Tables. If you are not connected, there will be red text displaying `Network Tables: Disconnected`. If you are connected, then there will be green text displaying `Network Tables: Connected (<IP Address of Connection>)`.

_When you are disconnected from your robot, all widgets will be disabled._