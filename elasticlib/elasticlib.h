// Copyright (c) 2023-2024 Gold87 and other Elastic contributors
// This software can be modified and/or shared under the terms
// defined by the Elastic license:
// https://github.com/Gold872/elastic-dashboard/blob/main/LICENSE

#pragma once

#include <networktables/NetworkTableInstance.h>
#include <networktables/StringTopic.h>
#include <wpi/json.h>

#include <cmath>
#include <iostream>
#include <stdexcept>
#include <string>

/**
 * @class Elastic
 * @brief Handles publishing notifications to the Elastic Robot Notifications
 * topic on NetworkTables.
 */
class Elastic {
 public:
  /**
   * @struct Notification
   * @brief Represents a notification with various display properties.
   */
  struct Notification {
    /**
     * @enum Level
     * @brief Defines severity levels for notifications.
     */
    enum class Level { INFO, WARNING, ERROR };

    Notification() : level(Level::INFO), title(""), description("") {}

    /**
     * @brief Constructs a Notification with default display time and
     * dimensions.
     * @param level The severity level of the notification.
     * @param title The title of the notification.
     * @param description The description of the notification.
     */
    Notification(Level level, const std::string& title,
                 const std::string& description)
        : level(level),
          title(title),
          description(description),
          displayTimeMillis(3000),
          width(350),
          height(-1) {}

    /**
     * @brief Constructs a Notification with specified display time.
     * @param level The severity level of the notification.
     * @param title The title of the notification.
     * @param description The description of the notification.
     * @param displayTimeInMillis Duration to display the notification, in
     * milliseconds.
     */
    Notification(Level level, const std::string& title,
                 const std::string& description, int displayTimeInMillis)
        : level(level),
          title(title),
          description(description),
          displayTimeMillis(displayTimeInMillis),
          width(350),
          height(-1) {}

    /**
     * @brief Constructs a Notification with specified display time and
     * dimensions.
     * @param level The severity level of the notification.
     * @param title The title of the notification.
     * @param description The description of the notification.
     * @param displayTimeInMillis Duration to display the notification, in
     * milliseconds.
     * @param width Width of the notification display.
     * @param height Height of the notification display.
     */
    Notification(Level level, const std::string& title,
                 const std::string& description, int displayTimeInMillis,
                 double width, double height)
        : level(level),
          title(title),
          description(description),
          displayTimeMillis(displayTimeInMillis),
          width(width),
          height(height) {}

    /**
     * @brief Sets the notification level.
     * @param level The new severity level.
     */
    void SetLevel(Level level) { this->level = level; }

    /**
     * @brief Gets the notification level.
     * @return The current severity level.
     */
    Level GetLevel() const { return level; }

    /**
     * @brief Sets the title of the notification.
     * @param title The new title.
     */
    void SetTitle(const std::string& title) { this->title = title; }

    /**
     * @brief Gets the title of the notification.
     * @return The current title.
     */
    std::string GetTitle() const { return title; }

    /**
     * @brief Sets the description of the notification.
     * @param description The new description.
     */
    void SetDescription(const std::string& description) {
      this->description = description;
    }

    /**
     * @brief Gets the description of the notification.
     * @return The current description.
     */
    std::string GetDescription() const { return description; }

    /**
     * @brief Gets the display duration of the notification.
     * @return Display time in milliseconds.
     */
    int GetDisplayTimeMillis() const { return displayTimeMillis; }

    /**
     * @brief Sets the display duration of the notification.
     * @param newDisplayTimeMillis New display time in milliseconds.
     */
    void SetDisplayTimeMillis(int newDisplayTimeMillis) {
      this->displayTimeMillis = newDisplayTimeMillis;
    }

    void SetDisplayTimeSeconds(double seconds) {
      SetDisplayTimeMillis((int)std::round(seconds * 1000));
    }

    /**
     * @brief Gets the display width of the notification.
     * @return The width in pixels.
     */
    double GetWidth() const { return width; }

    /**
     * @brief Sets the display width of the notification.
     * @param width The new width in pixels.
     */
    void SetWidth(double width) { this->width = width; }

    /**
     * @brief Gets the display height of the notification.
     * @return The height in pixels.
     */
    double GetHeight() const { return height; }

    /**
     * @brief Sets the display height of the notification.
     * @param height The new height in pixels.
     */
    void SetHeight(double height) { this->height = height; }

    /**
     * Modifies the notification's level and returns itself to allow for method
     * chaining.
     *
     * @param level The level to set the notification to.
     * @return A reference to the current notification.
     */
    Notification& WithLevel(Level level) {
      this->level = level;
      return *this;
    }

    /**
     * Modifies the notification's title and returns itself to allow for method
     * chaining.
     *
     * @param title The title to set the notification to.
     * @return A reference to the current notification.
     */
    Notification& WithTitle(const std::string& title) {
      SetTitle(title);
      return *this;
    }

    /**
     * Modifies the notification's description and returns itself to allow for
     * method chaining.
     *
     * @param description The description to set the notification to.
     * @return A reference to the current notification.
     */
    Notification& WithDescription(const std::string& description) {
      SetDescription(description);
      return *this;
    }

    /**
     * Modifies the notification's display time and returns itself to allow for
     * method chaining.
     *
     * @param seconds The number of seconds to display the notification for.
     * @return A reference to the current notification.
     */
    Notification& WithDisplaySeconds(double seconds) {
      return WithDisplayMilliseconds(
          static_cast<int>(std::round(seconds * 1000)));
    }

    /**
     * Modifies the notification's display time and returns itself to allow for
     * method chaining.
     *
     * @param displayTimeMillis The number of milliseconds to display the
     * notification for.
     * @return A reference to the current notification.
     */
    Notification& WithDisplayMilliseconds(int displayTimeMillis) {
      SetDisplayTimeMillis(displayTimeMillis);
      return *this;
    }

    /**
     * Modifies the notification's width and returns itself to allow for method
     * chaining.
     *
     * @param width The width to set the notification to.
     * @return A reference to the current notification.
     */
    Notification& WithWidth(double width) {
      SetWidth(width);
      return *this;
    }

    /**
     * Modifies the notification's height and returns itself to allow for method
     * chaining.
     *
     * @param height The height to set the notification to.
     * @return A reference to the current notification.
     */
    Notification& WithHeight(double height) {
      SetHeight(height);
      return *this;
    }

    /**
     * Modifies the notification's height and returns itself to allow for method
     * chaining.
     *
     * <p>This will set the height to -1 to have it automatically determined by
     * the dashboard.
     *
     * @return A reference to the current notification.
     */
    Notification& WithAutomaticHeight() {
      SetHeight(-1);
      return *this;
    }

    /**
     * Modifies the notification to disable the auto-dismiss behavior.
     *
     * <p>This sets the display time to 0 milliseconds.
     *
     * <p>The auto-dismiss behavior can be re-enabled by setting the display
     * time to a number greater than 0.
     *
     * @return A reference to the current notification.
     */
    Notification& WithNoAutoDismiss() {
      SetDisplayTimeMillis(0);
      return *this;
    }
    /**
     * @brief Converts the notification to a JSON string for publishing.
     * @return JSON string representing the notification.
     */
    std::string ToJson() const {
      wpi::json jsonData;
      jsonData["level"] = LevelToString(level);
      jsonData["title"] = title;
      jsonData["description"] = description;
      jsonData["displayTime"] = displayTimeMillis;
      jsonData["width"] = width;
      jsonData["height"] = height;
      return jsonData.dump();
    }

    /**
     * @brief Converts a notification level to its string representation.
     * @param level The notification level.
     * @return The string representation of the level.
     */
    static std::string LevelToString(Level level) {
      switch (level) {
        case Level::INFO:
          return "INFO";
        case Level::WARNING:
          return "WARNING";
        case Level::ERROR:
          return "ERROR";
        default:
          return "UNKNOWN";
      }
    }

   private:
    Level level;              ///< Notification severity level.
    std::string title;        ///< Title of the notification.
    std::string description;  ///< Description of the notification.
    int displayTimeMillis;    ///< Display time in milliseconds.
    double width;             ///< Display width in pixels.
    double height;            ///< Display height in pixels.
  };

  /**
   * @brief Publishes a notification as a JSON string to the NetworkTables
   * topic.
   * @param alert The notification to send.
   */
  static void SendAlert(const Notification& alert) {
    try {
      std::string jsonString =
          alert.ToJson();              // Convert Notification to JSON string
      GetPublisher().Set(jsonString);  // Publish the JSON string
    } catch (const std::exception& e) {
      std::cerr << "Error processing JSON: " << e.what() << std::endl;
    } catch (...) {
      std::cerr << "Unknown error occurred while processing JSON." << std::endl;
    }
  }

 private:
  static nt::StringPublisher& GetPublisher() {
    static nt::StringTopic topic =
        nt::NetworkTableInstance::GetDefault().GetStringTopic(
            "/Elastic/RobotNotifications");

    static nt::StringPublisher publisher =
        topic.Publish({.sendAll = true, .keepDuplicates = true});

    return publisher;
  }
};

using ElasticNotification = Elastic::Notification;
