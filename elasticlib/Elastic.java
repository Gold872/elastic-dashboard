package frc.robot.util;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.wpi.first.networktables.NetworkTableInstance;
import edu.wpi.first.networktables.PubSubOption;
import edu.wpi.first.networktables.StringPublisher;
import edu.wpi.first.networktables.StringTopic;

public final class Elastic {
  private static final StringTopic topic = NetworkTableInstance.getDefault()
      .getStringTopic("/Elastic/RobotNotifications");
  private static final StringPublisher publisher = topic.publish(PubSubOption.sendAll(true),
      PubSubOption.keepDuplicates(true));
  private static final ObjectMapper objectMapper = new ObjectMapper();

  /**
   * Sends an alert notification to the Elastic dashboard.
   * The alert is serialized as a JSON string before being published.
   *
   * @param alert the {@link ElasticNotification} object containing alert details
   */
  public static void sendAlert(ElasticNotification alert) {
    try {
      publisher.set(objectMapper.writeValueAsString(alert));
    } catch (JsonProcessingException e) {
      e.printStackTrace();
    }
  }

  /**
   * Represents a notification object to be sent to the Elastic dashboard.
   * This object holds properties such as level, title, description, display time,
   * and dimensions
   * to control how the alert is displayed on the dashboard.
   */
  public static class ElasticNotification {
    @JsonProperty("level")
    private NotificationLevel level;

    @JsonProperty("title")
    private String title;

    @JsonProperty("description")
    private String description;

    @JsonProperty("displayTime")
    private int displayTimeMillis;

    @JsonProperty("width")
    private double width;

    @JsonProperty("height")
    private double height;

    /**
     * Creates a new ElasticNotification with all properties specified.
     *
     * @param level             the level of the notification (e.g., INFO, WARNING,
     *                          ERROR)
     * @param title             the title text of the notification
     * @param description       the descriptive text of the notification
     * @param displayTimeMillis the time in milliseconds for which the notification
     *                          is displayed
     * @param width             the width of the notification display area
     * @param height            the height of the notification display area,
     *                          inferred if below zero
     */
    public ElasticNotification(
        NotificationLevel level,
        String title,
        String description,
        int displayTimeMillis,
        double width,
        double height) {
      this.level = level;
      this.title = title;
      this.displayTimeMillis = displayTimeMillis;
      this.description = description;
      this.height = height;
      this.width = width;
    }

    /**
     * Creates a new ElasticNotification with default display time and dimensions.
     *
     * @param level       the level of the notification
     * @param title       the title text of the notification
     * @param description the descriptive text of the notification
     */
    public ElasticNotification(NotificationLevel level, String title, String description) {
      this(level, title, description, 3000, 350, -1);
    }

    /**
     * Creates a new ElasticNotification with a specified display time and default
     * dimensions.
     *
     * @param level             the level of the notification
     * @param title             the title text of the notification
     * @param description       the descriptive text of the notification
     * @param displayTimeMillis the display time in milliseconds
     */
    public ElasticNotification(NotificationLevel level, String title, String description, int displayTimeMillis) {
      this(level, title, description, displayTimeMillis, 350, -1);
    }

    /**
     * Creates a new ElasticNotification with specified dimensions and default
     * display time.
     * If the height is below zero, it is automatically inferred based on screen
     * size.
     *
     * @param level       the level of the notification
     * @param title       the title text of the notification
     * @param description the descriptive text of the notification
     * @param width       the width of the notification display area
     * @param height      the height of the notification display area, inferred if
     *                    below zero
     */
    public ElasticNotification(NotificationLevel level, String title, String description, double width, double height) {
      this(level, title, description, 3000, width, height);
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

    public int getDisplayTimeMillis() {
      return displayTimeMillis;
    }

    public void setDisplayTimeMillis(int displayTimeMillis) {
      this.displayTimeMillis = displayTimeMillis;
    }

    public void setDescription(String description) {
      this.description = description;
    }

    public String getDescription() {
      return description;
    }

    /**
     * Represents the possible levels of notifications for the Elastic dashboard.
     * These levels are used to indicate the severity or type of notification.
     */
    public enum NotificationLevel {
      INFO, // Informational message
      WARNING, // Warning message
      ERROR // Error message
    }
  }
}