const bool isWPILib = bool.fromEnvironment('ELASTIC_WPILIB');

const String logoPath = 'assets/logos/logo.png';

const String appTitle = !isWPILib ? 'PurpleBoard' : 'Elastic (WPILib)';
