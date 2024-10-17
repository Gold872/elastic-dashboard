#pragma once

#include <iostream>
#include <networktables/NetworkTableInstance.h>
#include <networktables/StringTopic.h>
#include <string>
#include <wpi/json.h>

namespace elastic {

class NotificationHandler {
public:
  NotificationHandler() {
    topic = nt::NetworkTableInstance::GetDefault().GetStringTopic(
        "/Elastic/RobotNotifications");
    publisher =  topic.Publish({.sendAll = true, .keepDuplicates = true}); }

  struct Notification {
    enum class Level { INFO, WARNING, ERROR };

    Notification(Level level, const std::string &title,
                 const std::string &description)
        : level(level), title(title), description(description) {}

    void SetLevel(Level level) { this->level = level; }

    Level GetLevel() const { return level; }

    void SetTitle(const std::string &title) { this->title = title; }

    std::string GetTitle() const { return title; }

    void SetDescription(const std::string &description) {
      this->description = description;
    }

    std::string GetDescription() const { return description; }

    std::string ToJson() const {
      wpi::json jsonData;
      jsonData["level"] = LevelToString(level);
      jsonData["title"] = title;
      jsonData["description"] = description;
      return jsonData.dump();
    }

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
    Level level;
    std::string title;
    std::string description;
  };

  void SendAlert(const Notification &alert) {
    try {
      std::string jsonString = alert.ToJson();
      publisher.Set(jsonString);
    } catch (const std::exception &e) {
      std::cerr << "Error processing JSON: " << e.what() << std::endl;
    }
  }

private:
  nt::StringTopic topic;
  nt::StringPublisher publisher;
};

} // namespace elastic
