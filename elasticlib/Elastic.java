package frc.robot;

import edu.wpi.first.networktables.NetworkTableInstance;
import edu.wpi.first.networktables.PubSubOption;
import edu.wpi.first.networktables.PubSubOptions;
import edu.wpi.first.networktables.StringArrayEntry;
import edu.wpi.first.networktables.StringArrayPublisher;
import edu.wpi.first.networktables.StringArrayTopic;

public final class Elastic {
    private static final StringArrayTopic topic = NetworkTableInstance.getDefault().getStringArrayTopic("notifications");
    private static final StringArrayPublisher publisher = topic.publish(PubSubOption.sendAll(true));

    public static void sendAlert(AlertLevel level, String title, String description) {
        publisher.set(new String[] {level.toString(), title, description});
    }
    public enum AlertLevel {
        INFO,
        WARNING,
        ERROR
    }
}
