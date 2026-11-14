import 'package:flutter/material.dart';
import 'insync_brand.dart';

class Spinner extends StatelessWidget {
  final double size;
  const Spinner({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    // The brand loader (sync arrows turning around the play button).
    return InsyncSpinner(size: size);
  }
}
