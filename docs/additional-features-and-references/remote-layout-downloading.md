# Remote Layout Downloading

For situations where you want to load a dashboard layout from your robot, Elastic supports downloading a layout remotely and merging it with your current layout.

## On-Robot Configuration

In your robot code, add the following line in `robotInit()` or another initialization function

{% tabs %}
{% tab title="Java" %}
```java
WebServer.start(5800, Filesystem.getDeployDirectory().getPath());
```
{% endtab %}

{% tab title="C++" %}
```cpp
WebServer::GetInstance().Start(5800, frc::Filesystem::GetDeployDirectory());
```
{% endtab %}
{% endtabs %}

Next, you will have to deploy the Elastic configuration file to your robot:

1. Export the layout from Elastic
2. Move the exported json file into the deploy folder of your robot project
3. Deploy your robot code

{% hint style="info" %}
The name of the exported json file MUST be "elastic-layout.json", and should be placed at the root directory of your deploy folder, the folder structure should look like this:

/deploy\
&#x20;   elastic-layout.json\
&#x20;   ...
{% endhint %}

## Downloading Your Layout

To download the layout to your dashboard, enter the `File` menu, and click `Load Layout From Robot`

<figure><img src="../.gitbook/assets/remote_layout.png" alt=""><figcaption></figcaption></figure>

Alternatively, you can use the shortcut `Ctrl + D`

## Shuffleboard API Migration Guide

### Code-Driven Layouts

Migrating Shuffleboard API layouts to remote downloading layouts is simple:

1. Clear all tabs and widgets of your dashboard, it is recommended you save your layout to a safe location before doing this step
2. Connect to your robot to populate Elastic with the code-driven layout
3. Export your dashboard layout
4. Set up the remote layout downloading as described [here](remote-layout-downloading.md#on-robot-configuration)

After migrating your layout, it is advised to remove any Shuffleboard API-related code from your robot project.
