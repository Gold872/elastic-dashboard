## Single Color View

```java
Color exampleColor = new Color(68, 238, 255);
SmartDashboard.putString("Example Color", exampleColor.toHexString());
```

## SwerveDrive

_Note: Velocity must be in meters per second, and angles must be in either radians, degrees, or rotations, and CCW+_

```java
SmartDashboard.putData("Swerve Drive", new Sendable() {
  @Override
  public void initSendable(SendableBuilder builder) {
    builder.setSmartDashboardType("SwerveDrive");

    builder.addDoubleProperty("Front Left Angle", () -> frontLeftModule.getAngle().getRadians(), null);
    builder.addDoubleProperty("Front Left Velocity", () -> frontLeftModule.getVelocity(), null);

    builder.addDoubleProperty("Front Right Angle", () -> frontRightModule.getAngle().getRadians(), null);
    builder.addDoubleProperty("Front Right Velocity", () -> frontRightModule.getVelocity(), null);

    builder.addDoubleProperty("Back Left Angle", () -> backLeftModule.getAngle().getRadians(), null);
    builder.addDoubleProperty("Back Left Velocity", () -> backLeftModule.getVelocity(), null);

    builder.addDoubleProperty("Back Right Angle", () -> backRightModule.getAngle().getRadians(), null);
    builder.addDoubleProperty("Back Right Velocity", () -> backRightModule.getVelocity(), null);

    builder.addDoubleProperty("Robot Angle", () -> getRotation().getRadians(), null);
  }
});
```

## YAGSL Swerve Drive

If you are using the YAGSL Swerve Library, you can create a Swerve Drive widget without even modifying your code. Simply head to the `SmartDashboard` table, and drag the `swerve` table onto the grid, and you will have created a Swerve widget that shows your current and desired module states.

## Alerts

This displays data from the NetworkAlerts by [Team 6328](https://github.com/Mechanical-Advantage). For examples and implementation, see [Mechanical Advantage 2023 Robot Code](https://github.com/Mechanical-Advantage/RobotCode2023/blob/main/src/main/java/org/littletonrobotics/frc2023/util/Alert.java)