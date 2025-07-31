import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/theme_service.dart';
import 'package:here4help/constants/theme_schemes.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 主題選擇區域
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose Theme',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: themeService.currentTheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 下拉式選單
                      DropdownButtonFormField<ThemeScheme>(
                        value: themeService.currentTheme,
                        decoration: InputDecoration(
                          labelText: 'Theme Color',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: themeService.currentTheme.surface,
                        ),
                        items: themeService.allThemes.map((theme) {
                          return DropdownMenuItem<ThemeScheme>(
                            value: theme,
                            child: Row(
                              children: [
                                // 主題色彩預覽圓圈
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        theme.primary,
                                        theme.secondary,
                                        theme.accent,
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  theme.displayName,
                                  style: TextStyle(
                                    color: themeService.currentTheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (ThemeScheme? newTheme) {
                          if (newTheme != null) {
                            themeService.setTheme(newTheme);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 主題預覽區域
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theme Preview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: themeService.currentTheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // AppBar 預覽
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: themeService.currentTheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            Icon(
                              Icons.arrow_back,
                              color: themeService.currentTheme.onPrimary,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Here4Help',
                              style: TextStyle(
                                color: themeService.currentTheme.onPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 按鈕預覽
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    themeService.currentTheme.primary,
                                foregroundColor:
                                    themeService.currentTheme.onPrimary,
                              ),
                              child: const Text('Primary Button'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    themeService.currentTheme.primary,
                                side: BorderSide(
                                    color: themeService.currentTheme.primary),
                              ),
                              child: const Text('Secondary Button'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 文字預覽
                      Text(
                        'This is an example text, showing the text color effect of the current theme.',
                        style: TextStyle(
                          color: themeService.currentTheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 主題資訊區域
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Style Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: themeService.currentTheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildThemeInfoRow(
                          'Primary Color', themeService.currentTheme.primary),
                      _buildThemeInfoRow('Secondary Color',
                          themeService.currentTheme.secondary),
                      _buildThemeInfoRow(
                          'Accent Color', themeService.currentTheme.accent),
                      _buildThemeInfoRow('Background Color',
                          themeService.currentTheme.background),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeInfoRow(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$label: #${(color.value & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
