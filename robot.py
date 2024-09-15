import wpilib


class MyRobot(wpilib.TimedRobot):
    def __init__(self, period: float = 0.02) -> None:
        super().__init__(period)
        self.counter = 0

    def robotPeriodic(self):
        # Increment the counter
        self.counter += 1

        # Publish the counter value to NetworkTables
        wpilib.SmartDashboard.putNumber("Counter", self.counter)


if __name__ == "__main__":
    wpilib.run(MyRobot)