import 'package:flutter/material.dart';

@immutable
class Here4HelpThemeExtension extends ThemeExtension<Here4HelpThemeExtension> {
  final Color appBarTextColor;
  final Color appBarSubtitleColor;
  final List<Color> appBarGradient;
  final Color navigationBarBackground;
  final Color navigationBarSelectedColor;
  final Color navigationBarUnselectedColor;
  final Color dialogBackgroundColor;
  final Color dialogTitleColor;
  final Color dialogContentColor;
  final Color dialogPrimaryColor;

  const Here4HelpThemeExtension({
    required this.appBarTextColor,
    required this.appBarSubtitleColor,
    required this.appBarGradient,
    required this.navigationBarBackground,
    required this.navigationBarSelectedColor,
    required this.navigationBarUnselectedColor,
    required this.dialogBackgroundColor,
    required this.dialogTitleColor,
    required this.dialogContentColor,
    required this.dialogPrimaryColor,
  });

  @override
  Here4HelpThemeExtension copyWith({
    Color? appBarTextColor,
    Color? appBarSubtitleColor,
    List<Color>? appBarGradient,
    Color? navigationBarBackground,
    Color? navigationBarSelectedColor,
    Color? navigationBarUnselectedColor,
    Color? dialogBackgroundColor,
    Color? dialogTitleColor,
    Color? dialogContentColor,
    Color? dialogPrimaryColor,
  }) {
    return Here4HelpThemeExtension(
      appBarTextColor: appBarTextColor ?? this.appBarTextColor,
      appBarSubtitleColor: appBarSubtitleColor ?? this.appBarSubtitleColor,
      appBarGradient: appBarGradient ?? this.appBarGradient,
      navigationBarBackground:
          navigationBarBackground ?? this.navigationBarBackground,
      navigationBarSelectedColor:
          navigationBarSelectedColor ?? this.navigationBarSelectedColor,
      navigationBarUnselectedColor:
          navigationBarUnselectedColor ?? this.navigationBarUnselectedColor,
      dialogBackgroundColor: dialogBackgroundColor ?? this.dialogBackgroundColor,
      dialogTitleColor: dialogTitleColor ?? this.dialogTitleColor,
      dialogContentColor: dialogContentColor ?? this.dialogContentColor,
      dialogPrimaryColor: dialogPrimaryColor ?? this.dialogPrimaryColor,
    );
  }

  @override
  Here4HelpThemeExtension lerp(
      ThemeExtension<Here4HelpThemeExtension>? other, double t) {
    if (other is! Here4HelpThemeExtension) {
      return this;
    }
    return Here4HelpThemeExtension(
      appBarTextColor: Color.lerp(appBarTextColor, other.appBarTextColor, t) ??
          appBarTextColor,
      appBarSubtitleColor:
          Color.lerp(appBarSubtitleColor, other.appBarSubtitleColor, t) ??
              appBarSubtitleColor,
      appBarGradient: [
        if (appBarGradient.isNotEmpty && other.appBarGradient.isNotEmpty)
          for (int i = 0;
              i < appBarGradient.length && i < other.appBarGradient.length;
              i++)
            Color.lerp(appBarGradient[i], other.appBarGradient[i], t) ??
                appBarGradient[i]
        else
          ...appBarGradient,
      ],
      navigationBarBackground: Color.lerp(
              navigationBarBackground, other.navigationBarBackground, t) ??
          navigationBarBackground,
      navigationBarSelectedColor: Color.lerp(
              navigationBarSelectedColor, other.navigationBarSelectedColor, t) ??
          navigationBarSelectedColor,
      navigationBarUnselectedColor: Color.lerp(navigationBarUnselectedColor,
              other.navigationBarUnselectedColor, t) ??
          navigationBarUnselectedColor,
      dialogBackgroundColor:
          Color.lerp(dialogBackgroundColor, other.dialogBackgroundColor, t) ??
              dialogBackgroundColor,
      dialogTitleColor:
          Color.lerp(dialogTitleColor, other.dialogTitleColor, t) ??
              dialogTitleColor,
      dialogContentColor:
          Color.lerp(dialogContentColor, other.dialogContentColor, t) ??
              dialogContentColor,
      dialogPrimaryColor:
          Color.lerp(dialogPrimaryColor, other.dialogPrimaryColor, t) ??
              dialogPrimaryColor,
    );
  }
}
