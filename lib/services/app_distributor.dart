bool get isWPILib => const bool.fromEnvironment('ELASTIC_WPILIB');

String get logoPath =>
    (!isWPILib) ? 'assets/logos/logo.png' : 'assets/logos/wpilib_logo.png';

String get appTitle => (!isWPILib) ? 'Elastic' : 'Elastic (WPILib)';
