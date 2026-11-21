// Build-time settings, passed with:
// flutter run -d chrome --dart-define-from-file=private/env.json
// Empty SUPABASE_URL → the app uses fake AI data (handy for UI work and tests).

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const jobFunctionName = String.fromEnvironment(
  'JOB_FUNCTION',
  defaultValue: 'analyze-job',
);

/// The Edge Function: POST analyzes a job, GET lists the history.
Uri get jobFunctionUri =>
    Uri.parse('$supabaseUrl/functions/v1/$jobFunctionName');
