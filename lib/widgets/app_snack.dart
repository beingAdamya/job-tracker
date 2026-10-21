import 'package:flutter/material.dart';

// How long messages at the bottom of the screen stay visible
const Duration snackDuration = Duration(milliseconds: 2500);

void showAppSnack(BuildContext context, String text, {SnackBarAction? action}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar(); // never queue messages up

  messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      duration: snackDuration,
      persist: false, // without this, a message with an action never auto-hides
      action: action,
    ),
  );
}