# Robot Notifications with ElasticLib

Elastic supports sending notifications to the dashboard via robot code. This could be helpful in situations where you want to grab the attention of the user when something goes wrong or if there's an important warning to display.

Sending notifications via robot code requires the use of ElasticLib. Currently the only supported languages are Java and C++, but contributions for a Python port are open.

### Installing ElasticLib

First, copy this file into your robot project: [https://github.com/Gold872/elastic-dashboard/blob/main/elasticlib/Elastic.java](https://github.com/Gold872/elastic-dashboard/blob/main/elasticlib/Elastic.java)

If you are using C++, you will have to copy this file instead: [https://github.com/Gold872/elastic-dashboard/blob/main/elasticlib/elasticlib.h](https://github.com/Gold872/elastic-dashboard/blob/main/elasticlib/elasticlib.h)

It is recommended to put this in a folder called `util`, however any location within a robot project works. Depending on where the file is located, you may need to change the top line of the file.

### Creating a Notification

Notification data is stored in an object called `ElasticNotification`. Currently, this has the following properties:

* `level` for the type of notification
* `title` for the notification title
* `description` for the notification text
* `width` for the notification width (optional)
* `height` for the notification height (optional)
* `displayTimeMillis` for the time to show the notification in milliseconds (optional)

There are 3 notification levels:

1. Error
2. Warning
3. Info

An example of an `ElasticNotification` for an error notification would be

{% tabs %}
{% tab title="Java" %}
```java
ElasticNotification notification = new ElasticNotification(NotificationLevel.ERROR, "Error Notification", "This is an example error notification.");
```
{% endtab %}

{% tab title="C++" %}
<pre class="language-cpp"><code class="lang-cpp"><strong>ElasticNotification notification = ElasticNotification(ElasticNotification::Level::ERROR, "Error Notification", "This is an example error notification");
</strong></code></pre>
{% endtab %}
{% endtabs %}

### Sending a notification

In order to send a notification, there is a method called `sendAlert` in the `Elastic` class to send an `ElasticNotification`.

To send the error notification that was declared above, you would call

{% tabs %}
{% tab title="Java" %}
```java
Elastic.sendAlert(notification);
```
{% endtab %}

{% tab title="C++" %}
```cpp
Elastic::SendAlert(notification);
```
{% endtab %}
{% endtabs %}

When this is called, a popup will appear on the dashboard that looks like this

![Error Notification](../.gitbook/assets/error\_notification.png)

### Customizing a Notification

Notifications and their settings can be customized after being created, allowing them to be reused.

For example, the error notification created above can be customized into a warning notification.

{% tabs %}
{% tab title="Java" %}
```java
/* code that created the notification */
notification.setLevel(NotificationLevel.WARNING);
notification.setTitle("Warning Notification");
notification.setDescription("This is an example warning notification");
```
{% endtab %}

{% tab title="C++" %}
```cpp
/* code that created the notification */
notification.SetLevel(ElasticNotification::Level::WARNING);
notification.SetTitle("Warning Notification");
notification.SetDescription("This is an example warning notification");
```
{% endtab %}
{% endtabs %}

### Customizing with Method Chaining

The simpler and recommended way to customize notifications is with method chaining. This allows for customizing multiple properties with just one line of code.

For example, here's how a notification can be entirely customized and sent with just one line of code.

{% tabs %}
{% tab title="Java" %}
```java
ElasticNotification notification = new ElasticNotification();

/* ... */

Elastic.sendAlert(notification
    .withLevel(NotificationLevel.INFO)
    .withTitle("Some Information")
    .withDescription("Your robot is doing fantastic!")
    .withDisplaySeconds(5.0)
);
```
{% endtab %}

{% tab title="C++" %}
```cpp
ElasticNotification notification = ElasticNotification();

/* ... */

Elastic::SendAlert(notification
    .WithLevel(ElasticNotification::Level::INFO)
    .WithTitle("Some Information")
    .WithDescription("Your robot is doing fantastic!")
    .WithDisplaySeconds(5.0)
);
```
{% endtab %}
{% endtabs %}
