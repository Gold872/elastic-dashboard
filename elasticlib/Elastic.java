// Copyright (c) 2023-2024 Gold87 and other Elastic contributors
// This software can be modified and/or shared under the terms
// defined by the Elastic license:
// https://github.com/Gold872/elastic-dashboard/blob/main/LICENSE

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

  /**
   * Sends an alert to the Elastic dashboard. The alert is serialized as a JSON string
   * before being published.
   *
   * @param alert the {@link Alert} object containing alert details
   */
  public static void sendAlert(Alert alert) {
    try {
      publisher.set(objectMapper.writeValueAsString(alert));
    } catch (JsonProcessingException e) {
      e.printStackTrace();
    }
  }

  /**
   * Represents an alert object to be sent to the Elastic dashboard. This object holds
   * properties such as level, title, description, display time, and dimensions to control how the
   * alert is displayed on the dashboard.
   */
  public static class Alert {
    @JsonProperty("level")
    private AlertLevel level;

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
     * Creates a new Alert with all default parameters. This constructor is intended
     * to be used with the chainable decorator methods
     *
     * <p>Title and description fields are empty.
     */
    public Alert() {
      this(AlertLevel.INFO, "", "");
    }

    /**
     * Creates a new Alert with all properties specified.
     *
     * @param level the level of the alert (e.g., INFO, WARNING, ERROR)
     * @param title the title text of the alert
     * @param description the descriptive text of the alert
     * @param displayTimeMillis the time in milliseconds for which the alert is displayed
     * @param width the width of the alert display area
     * @param height the height of the alert display area, inferred if below zero
     */
    public lert(
        AlertLevel level,
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
     * Creates a new Alert with default display time and dimensions.
     *
     * @param level the level of the alert
     * @param title the title text of the alert
     * @param description the descriptive text of the alert
     */
    public Alert(AlertLevel level, String title, String description) {
      this(level, title, description, 3000, 350, -1);
    }

    /**
     * Creates a new Alert with a specified display time and default dimensions.
     *
     * @param level the level of the alert
     * @param title the title text of the alert
     * @param description the descriptive text of the alert
     * @param displayTimeMillis the display time in milliseconds
     */
    public Alert(
        AlertLevel level, String title, String description, int displayTimeMillis) {
      this(level, title, description, displayTimeMillis, 350, -1);
    }

    /**
     * Creates a new Alert with specified dimensions and default display time. If the height is
     * below zero, it is automatically inferred based on screen size.
     *
     * @param level the level of the alert
     * @param title the title text of the alert
     * @param description the descriptive text of the alert
     * @param width the width of the alert display area
     * @param height the height of the alert display area, inferred if below zero
     */
    public Alert(
        AlertLevel level, String title, String description, double width, double height) {
      this(level, title, description, 3000, width, height);
    }

    /**
     * Updates the level of this alert
     *
     * @param level the level to set the alert to
     */
    public void setLevel(AlertLevel level) {
      this.level = level;
    }

    /**
     * @return the level of this alert
     */
    public AlertLevel getLevel() {
      return level;
    }

    /**
     * Updates the title of this alert
     *
     * @param title the title to set the alert to
     */
    public void setTitle(String title) {
      this.title = title;
    }

    /**
     * Gets the title of this alert
     *
     * @return the title of this alert
     */
    public String getTitle() {
      return title;
    }

    /**
     * Updates the description of this alert
     *
     * @param description the description to set the alert to
     */
    public void setDescription(String description) {
      this.description = description;
    }

    public String getDescription() {
      return description;
    }

    /**
     * Updates the display time of the alert
     *
     * @param seconds the number of seconds to display the alert for
     */
    public void setDisplayTimeSeconds(double seconds) {
      setDisplayTimeMillis((int) Math.round(seconds * 1000));
    }

    /**
     * Updates the display time of the alert in milliseconds
     *
     * @param displayTimeMillis the number of milliseconds to display the alert for
     */
    public void setDisplayTimeMillis(int displayTimeMillis) {
      this.displayTimeMillis = displayTimeMillis;
    }

    /**
     * Gets the display time of the alert in milliseconds
     *
     * @return the number of milliseconds the alert is displayed for
     */
    public int getDisplayTimeMillis() {
      return displayTimeMillis;
    }

    /**
     * Updates the width of the alert
     *
     * @param width the width to set the alert to
     */
    public void setWidth(double width) {
      this.width = width;
    }

    /**
     * Gets the width of the alert
     *
     * @return the width of the alert
     */
    public double getWidth() {
      return width;
    }

    /**
     * Updates the height of the alert
     *
     * <p>If the height is set to -1, the height will be determined automatically by the dashboard
     *
     * @param height the height to set the alert to
     */
    public void setHeight(double height) {
      this.height = height;
    }

    /**
     * Gets the height of the alert
     *
     * @return the height of the alert
     */
    public double getHeight() {
      return height;
    }

    /**
     * Modifies the alert's level and returns itself to allow for method chaining
     *
     * @param level the level to set the alert to
     * @return the current alert
     */
    public Alert withLevel(AlertLevel level) {
      this.level = level;
      return this;
    }

    /**
     * Modifies the alert's title and returns itself to allow for method chaining
     *
     * @param title the title to set the alert to
     * @return the current alert
     */
    public Alert withTitle(String title) {
      setTitle(title);
      return this;
    }

    /**
     * Modifies the alert's description and returns itself to allow for method chaining
     *
     * @param description the description to set the alert to
     * @return the current alert
     */
    public Alert withDescription(String description) {
      setDescription(description);
      return this;
    }

    /**
     * Modifies the alert's display time and returns itself to allow for method chaining
     *
     * @param seconds the number of seconds to display the alert for
     * @return the current alert
     */
    public Alert withDisplaySeconds(double seconds) {
      return withDisplayMilliseconds((int) Math.round(seconds * 1000));
    }

    /**
     * Modifies the alert's display time and returns itself to allow for method chaining
     *
     * @param displayTimeMillis the number of milliseconds to display the alert for
     * @return the current alert
     */
    public Alert withDisplayMilliseconds(int displayTimeMillis) {
      setDisplayTimeMillis(displayTimeMillis);
      return this;
    }

    /**
     * Modifies the alert's width and returns itself to allow for method chaining
     *
     * @param width the width to set the alert to
     * @return the current alert
     */
    public Alert withWidth(double width) {
      setWidth(width);
      return this;
    }

    /**
     * Modifies the alert's height and returns itself to allow for method chaining
     *
     * @param height the height to set the alert to
     * @return the current alert
     */
    public Alert withHeight(double height) {
      setHeight(height);
      return this;
    }

    /**
     * Modifies the alert's height and returns itself to allow for method chaining
     *
     * <p>This will set the height to -1 to have it automatically determined by the dashboard
     *
     * @return the current alert
     */
    public Alert withAutomaticHeight() {
      setHeight(-1);
      return this;
    }

    /**
     * Modifies the alert to disable the auto dismiss behavior
     *
     * <p>This sets the display time to 0 milliseconds
     *
     * <p>The auto dismiss behavior can be re-enabled by setting the display time to a number
     * greater than 0
     *
     * @return the current alert
     */
    public Alert withNoAutoDismiss() {
      setDisplayTimeMillis(0);
      return this;
    }

    /**
     * Represents the possible levels of alerts for the Elastic dashboard. These levels are
     * used to indicate the severity or type of alert.
     */
    public enum AlertLevel {
      /** Informational Message */
      INFO,
      /** Warning message */
      WARNING,
      /** Error message */
      ERROR
    }
  }
}
