import json

from ntcore import NetworkTableInstance, PubSubOptions


class Elastic:
    """
    The Elastic class facilitates sending alert notifications to the Elastic dashboard.
    It uses NetworkTables for communication and JSON for data serialization.

    Attributes:
        nt_instance (NetworkTableInstance): The default NetworkTables instance.
        topic (Topic): The string topic for publishing notifications.
        publisher (Publisher): The publisher for sending notifications.
    """

    nt_instance = NetworkTableInstance.getDefault()
    topic = nt_instance.getStringTopic("/Elastic/RobotNotifications")
    publisher = topic.publish(PubSubOptions(sendAll=True, keepDuplicates=True))

    @staticmethod
    def send_alert(alert):
        """
        Sends an alert notification to the Elastic dashboard.

        The alert is serialized as a JSON string before being published.

        Args:
            alert (Elastic.ElasticNotification): An instance containing alert details.

        Raises:
            TypeError: If the alert cannot be serialized to JSON.
            ValueError: If invalid data is encountered during serialization.
        """
        try:
            alert_json = json.dumps(alert.to_dict())
            Elastic.publisher.set(alert_json)
        except (TypeError, ValueError) as e:
            print(f"Error serializing alert: {e}")

    class ElasticNotification:
        """
        Represents a notification object to be sent to the Elastic dashboard.

        This object contains various properties to control how the alert is displayed.

        Attributes:
            level (str): The notification level (e.g., "INFO", "WARNING", "ERROR").
            title (str): The title of the notification.
            description (str): The description of the notification.
            display_time_millis (int): The display duration in milliseconds.
            width (float): The width of the notification area.
            height (float): The height of the notification area. -1 indicates automatic height.
        """

        def __init__(
            self,
            level="INFO",
            title="",
            description="",
            display_time_millis=3000,
            width=350,
            height=-1,
        ):
            """
            Initializes an ElasticNotification with default or specified parameters.

            Args:
                level (str): The notification level.
                title (str): The title text.
                description (str): The description text.
                display_time_millis (int): Display time in milliseconds (default: 3000).
                width (float): Width of the notification display area (default: 350).
                height (float): Height of the notification display area (default: -1).
            """
            self.level = level
            self.title = title
            self.description = description
            self.display_time_millis = display_time_millis
            self.width = width
            self.height = height

        def to_dict(self):
            """
            Converts the notification instance into a dictionary for JSON serialization.

            Returns:
                dict: A dictionary representation of the notification.
            """
            return {
                "level": self.level,
                "title": self.title,
                "description": self.description,
                "displayTime": self.display_time_millis,
                "width": self.width,
                "height": self.height,
            }

        # Chainable methods for setting properties
        def with_level(self, level):
            """
            Sets the notification level.

            Args:
                level (str): The level to set (e.g., "INFO", "WARNING", "ERROR").

            Returns:
                Elastic.ElasticNotification: The current instance for chaining.
            """
            self.level = level
            return self

        def with_title(self, title):
            """
            Sets the notification title.

            Args:
                title (str): The title text.

            Returns:
                Elastic.ElasticNotification: The current instance for chaining.
            """
            self.title = title
            return self

        def with_description(self, description):
            """
            Sets the notification description.

            Args:
                description (str): The description text.

            Returns:
                Elastic.ElasticNotification: The current instance for chaining.
            """
            self.description = description
            return self

        def with_display_seconds(self, seconds):
            """
            Sets the notification display time in seconds.

            Args:
                seconds (float): The display time in seconds.

            Returns:
                Elastic.ElasticNotification: The current instance for chaining.
            """
            self.display_time_millis = int(round(seconds * 1000))
            return self

        def with_display_milliseconds(self, millis):
            """
            Sets the notification display time in milliseconds.

            Args:
                millis (int): The display time in milliseconds.

            Returns:
                Elastic.ElasticNotification: The current instance for chaining.
            """
            self.display_time_millis = millis
            return self

        def with_width(self, width):
            """
            Sets the notification width.

            Args:
                width (float): The width of the notification.

            Returns:
                Elastic.ElasticNotification: The current instance for chaining.
            """
            self.width = width
            return self

        def with_height(self, height):
            """
            Sets the notification height.

            Args:
                height (float): The height of the notification.

            Returns:
                Elastic.ElasticNotification: The current instance for chaining.
            """
            self.height = height
            return self

        def with_automatic_height(self):
            """
            Sets the notification height to automatic (-1).

            Returns:
                Elastic.ElasticNotification: The current instance for chaining.
            """
            self.height = -1
            return self

        def with_no_auto_dismiss(self):
            """
            Disables automatic dismissal of the notification.

            Returns:
                Elastic.ElasticNotification: The current instance for chaining.
            """
            self.display_time_millis = 0
            return self
