Elastic supports sending notifications to the dashboard via robot code. This could be helpful in situations where you want to grab the attention of the user when something goes wrong or if there's an important warning to display.

Sending notifications via robot code requires the use of ElasticLib. Currently the only supported language is Java, but contributions for a C++ or Python port are open.

## Installing ElasticLib

First, copy this file into your robot project: https://github.com/Gold872/elastic-dashboard/blob/main/elasticlib/Elastic.java

It is recommended to put this in a folder called `util`, however any location within a robot project works. Depending on where the file is located, you may need to change the top line of the file.

## Customizing a Notification

Notification data is stored in an object called `ElasticNotification`. Currently, this has 3 properties, which are `level` for the type of notification, `title` for the notification title, and `description` for the notification text.

There are 3 notification levels:
1. Error
2. Warning
3. Info

An example of an `ElasticNotification` for an error notification would be
```java
ElasticNotification errorNotification = new ElasticNotification(NotificationLevel.ERROR, "Error Notification", "This is an example error notification.");
```

## Sending a notification

In order to send a notification, there is a method called `sendAlert` in the `Elastic` class to send an `ElasticNotification`.

To send the error notification that was declared above, you would call
```java
Elastic.sendAlert(errorNotification);
```

When this is called, a popup will appear on the dashboard that looks like this

![Error Notification](https://github.com/Gold872/elastic-dashboard/blob/main/screenshots/robot_notifications/error_notification.png)