import json
from typing import Dict
from ntcore import NetworkTableInstance, PubSubOptions


class ElasticNotification:
    """
    Represents a notification object to be sent to the Elastic dashboard.
    This object holds properties such as level, title, description, display time,
    and dimensions to control how the alert is displayed on the dashboard.
    """

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
        """
        Initializes an ElasticNotification object.

        Args:
            level (str): The severity level of the notification. Default is 'INFO'.
            title (str): The title of the notification. Default is an empty string.
            description (str): The description of the notification. Default is an empty string.
            display_time (int): Time in milliseconds for which the notification should be displayed. Default is 3000 ms.
            width (float): Width of the notification display area. Default is 350.
            height (float): Height of the notification display area. Default is -1 (automatic height).
        """
        self.level = level
        self.title = title
        self.description = description
        self.display_time = display_time
        self.width = width
        self.height = height

    def to_dict(self) -> Dict[str, str | float | int | NotificationLevel]:
        """
        Converts the notification to a dictionary for JSON serialization.

        Returns:
            dict: A dictionary representation of the notification object.
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
        """
        Sets the notification level and returns the object for chaining.

        Args:
            level (str): The level to set the notification to.

        Returns:
            ElasticNotification: The current notification object with the updated level.
        """
        self.level = level
        return self

    def with_title(self, title: str):
        """
        Sets the title and returns the object for chaining.

        Args:
            title (str): The title to set for the notification.

        Returns:
            ElasticNotification: The current notification object with the updated title.
        """
        self.title = title
        return self

    def with_description(self, description: str):
        """
        Sets the description and returns the object for chaining.

        Args:
            description (str): The description to set for the notification.

        Returns:
            ElasticNotification: The current notification object with the updated description.
        """
        self.description = description
        return self

    def with_display_seconds(self, seconds: float):
        """
        Sets the display time in seconds and returns the object for chaining.

        Args:
            seconds (float): The number of seconds the notification should be displayed for.

        Returns:
            ElasticNotification: The current notification object with the updated display time.
        """
        self.display_time = int(round(seconds * 1000))
        return self

    def with_display_milliseconds(self, display_time: int):
        """
        Sets the display time in milliseconds and returns the object for chaining.

        Args:
            display_time (int): The display time in milliseconds.

        Returns:
            ElasticNotification: The current notification object with the updated display time.
        """
        self.display_time = display_time
        return self

    def with_width(self, width: float):
        """
        Sets the display width and returns the object for chaining.

        Args:
            width (float): The width to set for the notification.

        Returns:
            ElasticNotification: The current notification object with the updated width.
        """
        self.width = width
        return self

    def with_height(self, height: float):
        """
        Sets the display height and returns the object for chaining.

        Args:
            height (float): The height to set for the notification.

        Returns:
            ElasticNotification: The current notification object with the updated height.
        """
        self.height = height
        return self

    def with_automatic_height(self):
        """
        Sets the height to automatic and returns the object for chaining.

        Returns:
            ElasticNotification: The current notification object with automatic height.
        """
        self.height = -1
        return self

    def with_no_auto_dismiss(self):
        """
        Sets the display time to 0 to prevent automatic dismissal.

        This method prevents the notification from disappearing automatically.

        Returns:
            None
        """
        self.display_time = 0

    def get_level(self) -> str:
        """
        Returns the level of this notification.

        Returns:
            str: The current level of the notification.
        """
        return self.level

    def set_level(self, level: str):
        """
        Updates the level of this notification.

        Args:
            level (str): The level to set the notification to.

        Returns:
            None
        """
        self.level = level

    def get_title(self) -> str:
        """
        Returns the title of this notification.

        Returns:
            str: The current title of the notification.
        """
        return self.title

    def set_title(self, title: str):
        """
        Updates the title of this notification.

        Args:
            title (str): The title to set the notification to.

        Returns:
            None
        """
        self.title = title

    def get_description(self) -> str:
        """
        Returns the description of this notification.

        Returns:
            str: The current description of the notification.
        """
        return self.description

    def set_description(self, description: str):
        """
        Updates the description of this notification.

        Args:
            description (str): The description to set the notification to.

        Returns:
            None
        """
        self.description = description

    def get_display_time_millis(self) -> int:
        """
        Returns the number of milliseconds the notification is displayed for.

        Returns:
            int: The display time in milliseconds.
        """
        return self.display_time

    def set_display_time_seconds(self, seconds: float):
        """
        Updates the display time of the notification in seconds.

        Args:
            seconds (float): The number of seconds to display the notification for.

        Returns:
            None
        """
        self.display_time = int(round(seconds * 1000))

    def set_display_time_millis(self, display_time_millis: int):
        """
        Updates the display time of the notification in milliseconds.

        Args:
            display_time_millis (int): The number of milliseconds to display the notification for.

        Returns:
            None
        """
        self.display_time = display_time_millis

    def get_width(self) -> float:
        """
        Returns the width of this notification.

        Returns:
            float: The current width of the notification.
        """
        return self.width

    def set_width(self, width: float):
        """
        Updates the width of this notification.

        Args:
            width (float): The width to set for the notification.

        Returns:
            None
        """
        self.width = width

    def get_height(self) -> float:
        """
        Returns the height of this notification.

        Returns:
            float: The current height of the notification.
        """
        return self.height

    def set_height(self, height: float):
        """
        Updates the height of this notification.

        Args:
            height (float): The height to set for the notification. If height is -1, it indicates automatic height.

        Returns:
            None
        """
        self.height = height


class Elastic:
    """
    A class responsible for sending alert notifications to the Elastic dashboard.

    This class uses NetworkTables to publish notifications to the dashboard.
    The alerts are serialized as JSON strings before being sent.
    """

    _topic = NetworkTableInstance.getDefault().getStringTopic(
        "/Elastic/RobotNotifications"
    )
    _publisher = _topic.publish(PubSubOptions(sendAll=True, keepDuplicates=True))

    @staticmethod
    def send_alert(alert: ElasticNotification):
        """
        Sends an alert notification to the Elastic dashboard.
        The alert is serialized as a JSON string before being published.

        Args:
            alert (ElasticNotification): The notification object containing the alert details.

        Raises:
            Exception: If there is an error during serialization or publishing the alert.
        """
        try:
            Elastic._publisher.set(json.dumps(alert.to_dict()))
        except Exception as e:
            print(f"Error serializing alert: {e}")
