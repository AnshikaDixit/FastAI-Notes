// utils/app_strings.dart
// All user-facing strings in one place — no hardcoded strings in widgets.

class AppStrings {
  AppStrings._();

  // App
  static const String appName = 'FastAI Notes';
  static const String tagline = 'Your notes, always in sync.';

  // Auth
  static const String login = 'Log In';
  static const String signup = 'Sign Up';
  static const String logout = 'Log Out';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String fullName = 'Full Name (optional)';
  static const String dontHaveAccount = "Don't have an account? ";
  static const String alreadyHaveAccount = 'Already have an account? ';
  static const String loginSuccess = 'Welcome back!';
  static const String signupSuccess = 'Account created. Please log in.';

  // Notes
  static const String notes = 'Notes';
  static const String newNote = 'New Note';
  static const String editNote = 'Edit Note';
  static const String title = 'Title';
  static const String description = 'Description';
  static const String personal = 'Mark as personal 🔒';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String confirmDelete = 'Delete this note?';
  static const String confirmDeleteBody =
      'This action cannot be undone.';
  static const String cancel = 'Cancel';
  static const String noNotes = 'No notes yet.\nTap + to create your first note!';
  static const String noteCreated = 'Note created!';
  static const String noteUpdated = 'Note updated!';
  static const String noteDeleted = 'Note deleted.';

  // Export
  static const String exportBackground = 'Export (Background)';
  static const String exportStarted =
      'Export started! Check history for status.';
  static const String exportHistory = 'Export History';
  static const String noExports = 'No exports yet.';

  // Streaming
  static const String streamExport = 'Live Stream Export';
  static const String streamConnecting = 'Connecting to server...';
  static const String streamPreparing = 'Preparing your export...';
  static const String streamComplete = '✅ Export complete!';
  static const String streamError = 'Stream error. Please try again.';
  static const String copyMarkdown = 'Copy Markdown';
  static const String copied = 'Copied to clipboard!';

  // Errors
  static const String genericError = 'Something went wrong.';
  static const String networkError = 'Cannot reach the server.';
  static const String validationError = 'Please fill all required fields.';
}
