// Copyright (c) 2023-2024 Gold87 and other Elastic contributors
// This software can be modified and/or shared under the terms
// defined by the Elastic license:
// https://github.com/Gold872/elastic-dashboard/blob/main/LICENSE

#include "elasticlib.h"

#include <exception>

#include <fmt/core.h>
#include <networktables/NetworkTableInstance.h>
#include <networktables/StringTopic.h>
#include <wpi/json.h>

namespace elastic {

void SendAlert(const Alert& alert) {
  static nt::StringTopic topic =
      nt::NetworkTableInstance::GetDefault().GetStringTopic(
          "/Elastic/RobotNotifications");
  static nt::StringPublisher publisher =
      topic.Publish({.sendAll = true, .keepDuplicates = true});

  try {
    // Convert Alert to JSON string
    wpi::json jsonData;

    if (alert.level == AlertLevel::INFO) {
      jsonData["level"] = "INFO";
    } else if (alert.level == AlertLevel::WARNING) {
      jsonData["level"] = "WARNING";
    } else if (alert.level == AlertLevel::ERROR) {
      jsonData["level"] = "ERROR";
    } else {
      jsonData["level"] = "UNKNOWN";
    }

    jsonData["title"] = alert.title;
    jsonData["description"] = alert.description;
    jsonData["displayTime"] = alert.displayTime.value();
    jsonData["width"] = alert.width;
    jsonData["height"] = alert.height;

    // Publish the JSON string
    publisher.Set(jsonData.dump());
  } catch (const std::exception& e) {
    fmt::println(stderr, "Error processing JSON: {}", e.what());
  } catch (...) {
    fmt::println(stderr, "Unknown error occurred while processing JSON.");
  }
}

}  // namespace elastic
