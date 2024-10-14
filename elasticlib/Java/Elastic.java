package frc.robot.util;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.wpi.first.networktables.NetworkTableInstance;
import edu.wpi.first.networktables.PubSubOption;
import edu.wpi.first.networktables.StringPublisher;
import edu.wpi.first.networktables.StringTopic;

public final class Elastic {
  private static final StringTopic topic =
      NetworkTableInstance.getDefault().getStringTopic("/Elastic/RobotNotifications");
  private static final StringPublisher publisher =
      topic.publish(PubSubOption.sendAll(true), PubSubOption.keepDuplicates(true));
  private static final ObjectMapper objectMapper = new ObjectMapper();

  public static void sendAlert(ElasticNotification alert) {
    try {
      publisher.set(objectMapper.writeValueAsString(alert));
    } catch (JsonProcessingException e) {
      e.printStackTrace();
    }
  }

  public static class ElasticNotification {
    @JsonProperty("level")
    private NotificationLevel level;

    @JsonProperty("title")
    private String title;

    @JsonProperty("description")
    private String description;

    public ElasticNotification(NotificationLevel level, String title, String description) {
      this.level = level;
      this.title = title;
      this.description = description;
    }

    public void setLevel(NotificationLevel level) {
      this.level = level;
    }

    public NotificationLevel getLevel() {
      return level;
    }

    public void setTitle(String title) {
      this.title = title;
    }

    public String getTitle() {
      return title;
    }

    public void setDescription(String description) {
      this.description = description;
    }

    public String getDescription() {
      return description;
    }

    public enum NotificationLevel {
      INFO,
      WARNING,
      ERROR
    }
  }
}
