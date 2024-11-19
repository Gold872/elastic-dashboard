import json
from typing import Dict
from ntcore import NetworkTableInstance, PubSubOptions


class ElasticNotification:
    class NotificationLevel:
        INFO = "INFO"
        WARNING = "WARNING"
        ERROR = "ERROR"

    def __init__(
        self,
        level=NotificationLevel.INFO,
        title: str = "",
        description: str = "",
        display_time: int = 3000,
        width: float = 350,
        height: float = -1,
    ):
        self.level = level
        self.title = title
        self.description = description
        self.display_time = display_time
        self.width = width
        self.height = height

    def to_dict(self) -> Dict[str, str | float | int | NotificationLevel]:
        """
        Converts the notification to a dictionary for JSON serialization.
        """
        return {
            "level": self.level,
            "title": self.title,
            "description": self.description,
            "displayTime": self.display_time,
            "width": self.width,
            "height": self.height,
        }

    def with_level(self, level: str):
        self.level = level
        return self

    def with_title(self, title: str):
        self.title = title
        return self

    def with_description(self, description: str):
        self.description = description
        return self

    def with_display_seconds(self, seconds: float):
        self.display_time = int(round(seconds * 1000))
        return self

    def with_display_milliseconds(self, display_time: int):
        self.display_time = display_time
        return self

    def with_width(self, width: float):
        self.width = width
        return self

    def with_height(self, height: float):
        self.height = height
        return self

    def with_automatic_height(self):
        self.height = -1
        return self

    def with_no_auto_dismiss(self):
        self.display_time = 0

    def get_level(self) -> str:
        """Returns the level of this notification."""
        return self.level

    def set_level(self, level: str):
        """
        Updates the level of this notification.

        :param level: The level to set the notification to.
        """
        self.level = level

    def get_title(self) -> str:
        """Returns the title of this notification."""
        return self.title

    def set_title(self, title: str):
        """
        Updates the title of this notification.

        :param title: The title to set the notification to.
        """
        self.title = title

    def get_description(self) -> str:
        """Returns the description of this notification."""
        return self.description

    def set_description(self, description: str):
        """
        Updates the description of this notification.

        :param description: The description to set the notification to.
        """
        self.description = description

    def get_display_time_millis(self) -> int:
        """Returns the number of milliseconds the notification is displayed for."""
        return self.display_time_millis

    def set_display_time_seconds(self, seconds: float):
        """
        Updates the display time of the notification in seconds.

        :param seconds: The number of seconds to display the notification for.
        """
        self.display_time_millis = int(round(seconds * 1000))

    def set_display_time_millis(self, display_time_millis: int):
        """
        Updates the display time of the notification in milliseconds.

        :param display_time_millis: The number of milliseconds to display the notification for.
        """
        self.display_time_millis = display_time_millis

    def get_width(self) -> float:
        """Returns the width of the notification."""
        return self.width

    def set_width(self, width: float):
        """
        Updates the width of the notification.

        :param width: The width to set the notification to.
        """
        self.width = width

    def get_height(self) -> float:
        """Returns the height of the notification."""
        return self.height

    def set_height(self, height: float):
        """
        Updates the height of the notification.

        If the height is set to -1, the height will be determined automatically by the dashboard.

        :param height: The height to set the notification to.
        """
        self.height = height


class Elastic:
    _topic = NetworkTableInstance.getDefault().getStringTopic(
        "/Elastic/RobotNotifications"
    )
    _publisher = _topic.publish(PubSubOptions(sendAll=True, keepDuplicates=True))

    @staticmethod
    def send_alert(alert: ElasticNotification):
        """
        Sends an alert notification to the Elastic dashboard.
        The alert is serialized as a JSON string before being published.

        :param alert: ElasticNotification object containing alert details
        """
        try:
            Elastic._publisher.set(json.dumps(alert.to_dict()))
        except Exception as e:
            print(f"Error serializing alert: {e}")
