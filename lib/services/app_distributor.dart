bool get isWPILib => const bool.fromEnvironment('ELASTIC_WPILIB');

String logoPath = 'assets/logos/logo.png';

String get appTitle => (!isWPILib) ? 'Elastic' : 'Elastic (WPILib)';
