import json
from ntcore import NetworkTableInstance, PubSubOptions


class ElasticNotification:
    class NotificationLevel:
        INFO = "INFO"
        WARNING = "WARNING"
        ERROR = "ERROR"

    def __init__(
        self,
        level=NotificationLevel.INFO,
        title="",
        description="",
        display_time=3000,
        width=350,
        height=-1,
    ):
        self.level = level
        self.title = title
        self.description = description
        self.display_time = display_time
        self.width = width
        self.height = height

    def to_dict(self):
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
        return self


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
