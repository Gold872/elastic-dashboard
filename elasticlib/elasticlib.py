import json
from enum import Enum
from typing import Dict

from ntcore import NetworkTableInstance, PubSubOptions


class AlertLevel(Enum):
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"


class Alert:
    """Represents an alert with various display properties."""

    def __init__(
        self,
        level=AlertLevel.INFO,
        title: str = "",
        description: str = "",
        display_time: int = 3000,
        width: float = 350,
        height: float = -1,
    ):
        """
        Initializes an ElasticAlert object.

        Args:
            level (str): The severity level of the alert. Default is 'INFO'.
            title (str): The title of the alert. Default is an empty string.
            description (str): The description of the alert. Default is an empty string.
            display_time (int): Time in milliseconds for which the alert should be displayed. Default is 3000 ms.
            width (float): Width of the alert display area. Default is 350.
            height (float): Height of the alert display area. Default is -1 (automatic height).
        """
        self.level = level
        self.title = title
        self.description = description
        self.display_time = display_time
        self.width = width
        self.height = height


__topic = None
__publisher = None


def send_alert(alert: Alert):
    """
    Sends an alert alert to the Elastic dashboard.
    The alert is serialized as a JSON string before being published.

    Args:
        alert (ElasticAlert): The alert object containing the alert details.

    Raises:
        Exception: If there is an error during serialization or publishing the alert.
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
                    "level": alert.level,
                    "title": alert.title,
                    "description": alert.description,
                    "displayTime": alert.display_time,
                    "width": alert.width,
                    "height": alert.height,
                }
            )
        )
    except Exception as e:
        print(f"Error serializing alert: {e}")
