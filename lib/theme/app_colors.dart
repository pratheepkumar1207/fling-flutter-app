import 'package:flutter/material.dart';

class AppColors {
  AppColors._();
  static const paper = Color(0xFFD4FF65);
  static const ink = Color(0xFF101B35);
  static const inkMuted = Color(0xFF34435E);

  static const bg = Color(0xFF0C1226);
  static const surface = Color(0xFF16213D);
  static const surface2 = Color(0xFF203052);
  static const surface3 = Color(
      0xFF2B4069); // one step past surface2, same progression rate as the design's surface->surface2 step
  static const border = Color(0xFF34496F);
  static const primary = Color(0xFF2455F5);
  static const primaryDim = Color(0xFF193CB8);
  static const accent = Color(0xFFD4FF65);
  static const accent2 = Color(0xFFD4FF65);
  static const gold = Color(0xFFDBB155);

  static const text = Color(0xFFF1F1F4);
  static const textDim = Color(0xFFADBBD7);
  static const textFaint = Color(0xFF91A1C2);

  static const success = Color(0xFF43B966);
  static const danger = Color(0xFFED4B43);
  static const warning = Color(0xFFDBB155);
}

class AppColorsLight {
  AppColorsLight._();

  static const bg = Color(0xFFFAF8F5);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF4F1ED);
  static const surface3 = Color(0xFFEBE7E1);
  static const border = Color(0xFFE4E1DD);

  static const primary = Color(0xFF2455F5);
  static const primaryDim = Color(0xFF193CB8);
  static const accent = Color(0xFFD4FF65);
  static const accent2 = Color(0xFFD4FF65);
  static const gold = Color(0xFFDBB155);

  static const text = Color(0xFF16130F);
  static const textDim = Color(0xFF5B5752);
  static const textFaint = Color(0xFF96918C);

  static const success = Color(0xFF45B164);
  static const danger = Color(0xFFD73431);
  static const warning = Color(0xFFDBB155);
}

class AppGradients {
  AppGradients._();

  static const List<Color> brand = [
    Color(0xFF2455F5),
    Color(0xFF315EDC),
  ];

  static const LinearGradient brandDiagonal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brand,
  );
  static const List<Color> volaCta = brand;

  static const LinearGradient volaCtaDiagonal = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: volaCta,
  );
}
