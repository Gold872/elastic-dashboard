package frc.robot;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

import edu.wpi.first.networktables.NetworkTableInstance;
import edu.wpi.first.networktables.PubSubOption;
import edu.wpi.first.networktables.StringArrayPublisher;
import edu.wpi.first.networktables.StringArrayTopic;
import edu.wpi.first.networktables.StringPublisher;
import edu.wpi.first.networktables.StringTopic;

public final class Elastic {
    private static final StringTopic topic = NetworkTableInstance.getDefault().getStringTopic("elastic/robotalerts");
    private static final StringPublisher publisher = topic.publish(PubSubOption.sendAll(true));
    private static final ObjectMapper objectMapper = new ObjectMapper();

    public static void sendAlert(RobotAlert alert) {
        try {
            publisher.set(objectMapper.writeValueAsString(alert));
        } catch (JsonProcessingException e) {
            e.printStackTrace();
        }
    }

    static class RobotAlert {
        private final AlertLevel level;
        private final String title;
        private final String description;

        public RobotAlert(AlertLevel level, String title, String description) {
            this.level = level;
            this.title = title;
            this.description = description;
        }

        public AlertLevel getLevel() {
            return level;
        }

        public String getTitle() {
            return title;
        }

        public String getDescription() {
            return description;
        }
    }

    public enum AlertLevel {
        INFO, WARNING, ERROR
    }
}