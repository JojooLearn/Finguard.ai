class AppConfig {
  static const String appName = 'FinGuard';
  static const String appVersion = '1.0.0';
  static const String defaultLocale = 'id-ID';
  static const String defaultCurrency = 'IDR';
  static const String defaultTimezone = 'Asia/Jakarta';

  // Supabase Configurations
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rxyzlfqqxiqwzbduqjad.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ4eXpsZnFxeGlxd3piZHVxamFkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI0MjEwMDksImV4cCI6MjEwNzk5NzAwOX0.UevH6vZe1Q98dTdL6IsNIzcjytxC4ZHc_IAl38RNqGM',
  );

  // OneSignal Push Notification Configurations
  static const String oneSignalAppId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '7f917228-fa3d-4952-b88a-98dfb0be17df',
  );
}
