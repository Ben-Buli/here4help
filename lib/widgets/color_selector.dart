import 'package:flutter/material.dart';
import 'package:here4help/constants/theme_schemes.dart';

class ColorSelector extends StatelessWidget {
  final List<ThemeScheme> colorOptions;
  final ThemeScheme? selectedColor;
  final Function(ThemeScheme) onColorSelected;

  const ColorSelector({
    super.key,
    required this.colorOptions,
    this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Theme Colors',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose your preferred color scheme.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black54,
              ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 16,
          children: colorOptions
              .map((color) => _buildColorButton(
                    context,
                    color,
                    isSelected: selectedColor?.name == color.name,
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildColorButton(
    BuildContext context,
    ThemeScheme color, {
    bool isSelected = false,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          onColorSelected(color);
        },
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.black : Colors.grey.shade300,
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: ClipOval(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: color.backgroundGradient != null
                        ? LinearGradient(
                            begin: color.gradientBegin ?? Alignment.topLeft,
                            end: color.gradientEnd ?? Alignment.bottomRight,
                            colors: color.backgroundGradient!,
                          )
                        : null,
                    color:
                        color.backgroundGradient == null ? color.primary : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _getShortThemeName(color.displayName),
              style: TextStyle(
                fontSize: 10,
                color: Colors.black54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 獲取簡短的主題名稱
  String _getShortThemeName(String fullName) {
    bool isDark = fullName.contains('(Dark)');
    String baseName = fullName.replaceAll(' (Dark)', '');

    String shortName;
    if (baseName.contains('Morandi Blue')) {
      shortName = 'Blue';
    } else if (baseName.contains('Morandi Green')) {
      shortName = 'Green';
    } else if (baseName.contains('Morandi Purple')) {
      shortName = 'Purple';
    } else if (baseName.contains('Morandi Pink')) {
      shortName = 'Pink';
    } else if (baseName.contains('Morandi Orange')) {
      shortName = 'Orange';
    } else if (baseName.contains('Yellow')) {
      shortName = 'Yellow';
    } else if (baseName.contains('Ocean Gradient')) {
      shortName = 'Ocean';
    } else if (baseName.contains('Sandy Footprints')) {
      shortName = 'Sandy';
    } else if (baseName.contains('Beach Sunset')) {
      shortName = 'Beach';
    } else if (baseName.contains('Pantone Milk Tea')) {
      shortName = 'Milk Tea';
    } else if (baseName.contains('Minimalist Still')) {
      shortName = 'Minimalist';
    } else if (baseName.contains('Glassmorphism Blur')) {
      shortName = 'Glass';
    } else if (baseName.contains('Glassmorphism Blue Grey')) {
      shortName = 'Blue Grey';
    } else if (baseName.contains('Meta Business Style')) {
      shortName = 'Meta';
    } else if (baseName.contains('Rainbow')) {
      shortName = 'Rainbow';
    } else if (baseName.contains('Main Style')) {
      shortName = 'Main';
    } else {
      shortName = baseName;
    }

    return isDark ? '$shortName\nDark' : shortName;
  }
}
