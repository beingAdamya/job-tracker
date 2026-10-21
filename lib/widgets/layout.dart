import 'package:flutter/material.dart';

// Side padding that keeps content at most `maxWidth` wide and centred.
// On a phone in portrait it simply returns `min`.
double sidePadding(BuildContext context, double maxWidth, {double min = 16}) {
  final width = MediaQuery.of(context).size.width;
  final extra = (width - maxWidth) / 2;
  return extra > min ? extra : min;
}