import json
from enum import Enum

from ntcore import NetworkTableInstance, PubSubOptions


class NotificationLevel(Enum):
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"


class Notification:
    """Represents an notification with various display properties."""

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


__topic = None
__publisher = None


def send_notification(notification: Notification):
    """
    Sends an notification notification to the Elastic dashboard.
    The notification is serialized as a JSON string before being published.

    Args:
        notification (ElasticNotification): The notification object containing the notification details.

    Raises:
        Exception: If there is an error during serialization or publishing the notification.
    """
    global __topic
    global __publisher

    if not __topic:
        __topic = NetworkTableInstance.getDefault().getStringTopic(
            "/Elastic/RobotNotifications"
        )
    if not __publisher:
        __publisher = __topic.publish(PubSubOptions(sendAll=True, keepDuplicates=True))

    try:
        __publisher.set(
            json.dumps(
                {
                    "level": notification.level,
                    "title": notification.title,
                    "description": notification.description,
                    "displayTime": notification.display_time,
                    "width": notification.width,
                    "height": notification.height,
                }
            )
        )
    except Exception as e:
        print(f"Error serializing notification: {e}")
