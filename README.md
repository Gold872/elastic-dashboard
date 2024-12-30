# ![Elastic Logo](assets/logos/logo_full.png)

[![Elastic](https://github.com/Gold872/elastic-dashboard/actions/workflows/elastic-ci.yml/badge.svg)](https://github.com/Gold872/elastic-dashboard/actions/workflows/elastic-ci.yml) [![codecov](https://codecov.io/gh/Gold872/elastic-dashboard/graph/badge.svg?token=4MQYW8SMQI)](https://codecov.io/gh/Gold872/elastic-dashboard)

A simple and modern dashboard for FRC.

Download files can be found [here](https://github.com/Gold872/elastic-dashboard/releases/latest), the supported platforms are Windows, MacOS, and Linux.

_Important Notes/Warnings:_ 
* _Your robot code must be using WPILib version 2023.3.1 or higher, otherwise you might not be able to add widgets._
    * _WPILib v2023.3.1 fixed a bug in Network Tables where values wouldn't be sent to a client after subscribing topics only. Since the program subscribes topics only to everything, any widget that is built using a sendable will not be possible to add since the program will not be able to retrieve the widget's type. See https://github.com/wpilibsuite/allwpilib/pull/4991 for more info._

## About

Elastic is a simple and modern FRC dashboard made by Nadav from FRC Team 353. It is meant to be used behind the glass as a competition driver dashboard, but it can also be used for testing. Some unique features include:
* Customizable color scheme with over 20 variants
* Subscription sharing to reduce bandwidth consumption
* Optimized camera streams which automatically deactivate when not in use
* Automatic height resizing to the FRC Driver Station

![Example Layout](/screenshots/example_layout.png)

## Documentation
View the online documentation [here](https://frc-elastic.gitbook.io/docs)

## Special Thanks

This dashboard wouldn't have been made without the help and inspiration from the following people

* [Michael Jansen](https://github.com/mjansen4857) from Team 3015
* [Jonah](https://github.com/jwbonner) from Team 6328
* [Oh yes 10 FPS](https://github.com/oh-yes-0-fps) from Team 3173
* [Jason](https://github.com/jasondaming) and [Peter](https://github.com/PeterJohnson) from WPILib
* All mentors and advisors of Team 353, the POBots
