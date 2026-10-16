import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String friendlyError(Object error) {
  if (error is AuthException) return error.message;
  if (error is PostgrestException) return error.message;
  if (error is StorageException) return error.message;
  if (error is StateError) return error.message;
  return '$error';
}

void showErrorSnack(BuildContext context, Object error) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(friendlyError(error))));
}
