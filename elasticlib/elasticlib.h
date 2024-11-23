// Copyright (c) 2023-2024 Gold87 and other Elastic contributors
// This software can be modified and/or shared under the terms
// defined by the Elastic license:
// https://github.com/Gold872/elastic-dashboard/blob/main/LICENSE

#pragma once

#include <string>

#include <units/time.h>

namespace elastic {

/**
 * Defines severity levels for alerts.
 */
enum class AlertLevel { INFO, WARNING, ERROR };

/**
 * Represents an alert with various display properties.
 */
struct Alert {
  /// Set the display time to this value to disable the auto-dismiss behavior.
  static constexpr units::millisecond_t NO_AUTO_DISMISS{0_s};

  // Set the height to this value to have the dashboard automatically determine
  // the height.
  static constexpr int AUTOMATIC_HEIGHT = -1;

  /// Alert severity level.
  AlertLevel level = AlertLevel::INFO;

  /// Title of the alert.
  std::string title;

  /// Description of the alert.
  std::string description;

  /// Display time.
  units::millisecond_t displayTime{3_s};

  /// Display width in pixels.
  int width = 350;

  /// Display height in pixels.
  int height = AUTOMATIC_HEIGHT;
};

/**
 * Publishes an alert as a JSON string to the NetworkTables topic.
 *
 * @param alert The alert to send.
 */
void SendAlert(const Alert& alert);

}  // namespace elastic
