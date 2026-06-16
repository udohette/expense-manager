import 'package:flutter/material.dart';

class BrandedLogo extends StatelessWidget {
  const BrandedLogo({this.height = 56, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/eintelix_logo.png',
      height: height,
      fit: BoxFit.contain,
    );
  }
}
