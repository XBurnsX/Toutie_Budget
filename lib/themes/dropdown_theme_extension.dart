import 'package:flutter/material.dart';

// Extension de thème pour les dropdowns
class DropdownThemeExtension extends ThemeExtension<DropdownThemeExtension> {
  const DropdownThemeExtension({required this.dropdownColor});

  final Color dropdownColor;

  @override
  DropdownThemeExtension copyWith({Color? dropdownColor}) {
    return DropdownThemeExtension(
      dropdownColor: dropdownColor ?? this.dropdownColor,
    );
  }

  @override
  DropdownThemeExtension lerp(
    ThemeExtension<DropdownThemeExtension>? other,
    double t,
  ) {
    if (other is! DropdownThemeExtension) {
      return this;
    }
    return DropdownThemeExtension(
      dropdownColor:
          Color.lerp(dropdownColor, other.dropdownColor, t) ?? dropdownColor,
    );
  }
}

// Extension helper pour accéder facilement à la couleur des dropdowns
extension DropdownColorExtension on ThemeData {
  Color get dropdownColor {
    final extension = this.extension<DropdownThemeExtension>();
    return extension?.dropdownColor ??
        Color.lerp(
          cardTheme.color ?? const Color(0xFF232526),
          Colors.black,
          0.15,
        ) ??
        const Color(0xFF232526);
  }
}
