/// App version, stamped by CI (`--dart-define=APP_VERSION=1.0.<run>`).
/// Local builds show "dev".
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
