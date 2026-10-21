import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

// Starts Firebase once, and remembers whether it worked
class FirebaseBoot {
  static bool ready = false;
  static String? error;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      ready = true;
      error = null;
    } catch (e) {
      ready = false;
      error = e.toString();
    }
  }
}