import 'package:flutter/material.dart';

const List<Color> _swatches = [
  // backgrounds
  Colors.white, Color(0xFFF5F5F5), Color(0xFFFFF8E1), Color(0xFFE3F2FD),
  Color(0xFFE8F5E9), Color(0xFFFCE4EC), Color(0xFF212121), Color(0xFF121212),
  Color(0xFF0D1B2A), Color(0xFF1B2A1B), Color(0xFF2A1B2A), Colors.black,
  // accents
  Colors.indigo, Colors.blue, Colors.teal, Colors.green, Colors.orange,
  Colors.deepOrange, Colors.red, Colors.pink, Colors.purple, Colors.brown,
  Colors.blueGrey, Colors.amber,
];

// "#3F51B5" or "3F51B5" → a colour number (null if it isn't valid)
int? _parseHex(String input) {
  final hex = input.trim().replaceAll('#', '');
  if (hex.length != 6) return null;
  final value = int.tryParse(hex, radix: 16);
  return value == null ? null : (0xFF000000 | value);
}

// Shows a bottom sheet with colour circles and a hex box.
// Returns the chosen colour, or null if closed.
Future<Color?> pickColor(BuildContext context, {required String title}) {
  final controller = TextEditingController();

  return showModalBottomSheet<Color>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(sheetContext).viewInsets.bottom, // above keyboard
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(sheetContext).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in _swatches)
                      GestureDetector(
                        onTap: () => Navigator.pop(sheetContext, c),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Or type a hex colour',
                    hintText: '#3F51B5',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: () {
                        final value = _parseHex(controller.text);
                        if (value != null) {
                          Navigator.pop(sheetContext, Color(value));
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}