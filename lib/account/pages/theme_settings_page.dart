import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/constants/theme_schemes.dart';
import 'package:here4help/widgets/glassmorphism_app_bar.dart';
import 'package:here4help/widgets/color_selector.dart';

class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  bool _isThemePreviewExpanded = false; // 主題預覽展開狀態

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThemeModeSection(context, themeManager),
              const SizedBox(height: 24),
              _buildThemeSelectionSection(context, themeManager),
              const SizedBox(height: 24),
              _buildColorSelectionSection(context, themeManager),
              const SizedBox(height: 24),
              _buildThemePreviewSection(context, themeManager),
            ],
          ),
        );
      },
    );
  }

  /// 主題模式選擇區域
  Widget _buildThemeModeSection(
      BuildContext context, ThemeConfigManager themeManager) {
    return GlassmorphismCard(
      blurRadius: themeManager.currentTheme.surfaceBlur ?? 5.0,
      backgroundColor: themeManager.currentTheme.surface.withOpacity(0.8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Theme Mode',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: themeManager.currentTheme.onSurface,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: themeManager.themeModes.map((mode) {
                final isSelected = themeManager.themeMode == mode;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      themeManager.setThemeMode(mode);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? themeManager.currentTheme.primary.withOpacity(0.2)
                            : themeManager.currentTheme.surface
                                .withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? themeManager.currentTheme.primary
                              : themeManager.currentTheme.onSurface
                                  .withOpacity(0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _getThemeModeIcon(mode),
                            color: isSelected
                                ? themeManager.currentTheme.primary
                                : themeManager.currentTheme.onSurface
                                    .withOpacity(0.7),
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getThemeModeText(mode),
                            style: TextStyle(
                              color: isSelected
                                  ? themeManager.currentTheme.primary
                                  : themeManager.currentTheme.onSurface
                                      .withOpacity(0.7),
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 主題選擇區域
  Widget _buildThemeSelectionSection(
      BuildContext context, ThemeConfigManager themeManager) {
    return GlassmorphismCard(
      blurRadius: themeManager.currentTheme.surfaceBlur ?? 5.0,
      backgroundColor: themeManager.currentTheme.surface.withOpacity(0.8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Theme',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: themeManager.currentTheme.onSurface,
                  ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ThemeScheme>(
              value: _getCurrentThemeGroupRepresentative(themeManager),
              style: TextStyle(
                color: themeManager.inputTextColor,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                labelText: 'Theme Color',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: _getDropdownFillColor(themeManager),
                labelStyle: TextStyle(
                  color: themeManager.inputTextColor,
                ),
                hintStyle: TextStyle(
                  color: themeManager.inputHintTextColor,
                ),
              ),
              items:
                  themeManager.groupedThemesWithDarkMode.entries.map((entry) {
                // 為每個主題類型創建一個組
                final representativeTheme = entry.value.first;
                return DropdownMenuItem<ThemeScheme>(
                  value: representativeTheme, // 使用該組的第一個主題作為代表
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: representativeTheme.backgroundGradient !=
                                  null
                              ? LinearGradient(
                                  begin: representativeTheme.gradientBegin ??
                                      Alignment.topLeft,
                                  end: representativeTheme.gradientEnd ??
                                      Alignment.bottomRight,
                                  colors:
                                      representativeTheme.backgroundGradient!,
                                )
                              : null,
                          color: representativeTheme.backgroundGradient == null
                              ? representativeTheme.primary
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        entry.key, // 顯示主題類型名稱
                        style: TextStyle(
                          color: themeManager.inputTextColor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (ThemeScheme? newTheme) {
                if (newTheme != null) {
                  themeManager.setTheme(newTheme);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 顏色選擇區域
  Widget _buildColorSelectionSection(
      BuildContext context, ThemeConfigManager themeManager) {
    final colorOptions =
        themeManager.getColorOptionsForTheme(themeManager.currentTheme);

    return GlassmorphismCard(
      blurRadius: themeManager.currentTheme.surfaceBlur ?? 5.0,
      backgroundColor: themeManager.currentTheme.surface.withOpacity(0.8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ColorSelector(
          colorOptions: colorOptions,
          selectedColor: themeManager.currentTheme,
          onColorSelected: (ThemeScheme selectedColor) {
            themeManager.setTheme(selectedColor);
          },
        ),
      ),
    );
  }

  /// 主題預覽區域
  Widget _buildThemePreviewSection(
      BuildContext context, ThemeConfigManager themeManager) {
    return GlassmorphismCard(
      blurRadius: themeManager.currentTheme.surfaceBlur ?? 5.0,
      backgroundColor: themeManager.currentTheme.surface.withOpacity(0.8),
      child: Column(
        children: [
          // 標題欄（可點擊）
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              onTap: () {
                setState(() {
                  _isThemePreviewExpanded = !_isThemePreviewExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Theme Preview',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: themeManager.currentTheme.onSurface,
                            ),
                      ),
                    ),
                    Icon(
                      _isThemePreviewExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: themeManager.currentTheme.onSurface,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 內容區域（可折疊）
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isThemePreviewExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AppBar 預覽
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: themeManager.appBarGradient,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Icon(
                          Icons.arrow_back,
                          color: themeManager.appBarTextColor,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Here4Help',
                          style: TextStyle(
                            color: themeManager.appBarTextColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 卡片預覽
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: themeManager.currentTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            themeManager.currentTheme.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor:
                                  themeManager.currentTheme.primary,
                              child: Icon(
                                Icons.person,
                                color: themeManager.currentTheme.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'User Profile',
                                    style: TextStyle(
                                      color:
                                          themeManager.currentTheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Sample user information',
                                    style: TextStyle(
                                      color: themeManager.currentTheme.onSurface
                                          .withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                            backgroundColor: themeManager.currentTheme.primary,
                            foregroundColor:
                                themeManager.currentTheme.onPrimary,
                          ),
                          child: const Text('Primary'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            foregroundColor: themeManager.currentTheme.primary,
                            side: BorderSide(
                                color: themeManager.currentTheme.primary),
                          ),
                          child: const Text('Secondary'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            foregroundColor: themeManager.currentTheme.primary,
                          ),
                          child: const Text('Text'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 輸入框預覽
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Sample Input',
                      hintText: 'Enter your text here',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: themeManager.currentTheme.surface,
                      labelStyle: TextStyle(color: themeManager.inputTextColor),
                      hintStyle:
                          TextStyle(color: themeManager.inputHintTextColor),
                    ),
                    style: TextStyle(color: themeManager.inputTextColor),
                  ),
                  const SizedBox(height: 16),

                  // 狀態指示器預覽
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: themeManager.currentTheme.success,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Success',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: themeManager.currentTheme.warning,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Warning',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: themeManager.currentTheme.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Error',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 文字樣式預覽
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Heading Text',
                        style: TextStyle(
                          color: themeManager.currentTheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Body text with normal weight and size.',
                        style: TextStyle(
                          color: themeManager.currentTheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Small caption text',
                        style: TextStyle(
                          color: themeManager.currentTheme.onSurface
                              .withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 圖標預覽
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Icon(
                        Icons.home,
                        color: themeManager.currentTheme.primary,
                        size: 24,
                      ),
                      Icon(
                        Icons.search,
                        color: themeManager.currentTheme.secondary,
                        size: 24,
                      ),
                      Icon(
                        Icons.favorite,
                        color: themeManager.currentTheme.accent,
                        size: 24,
                      ),
                      Icon(
                        Icons.settings,
                        color: themeManager.currentTheme.onSurface,
                        size: 24,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 進度條預覽
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progress',
                        style: TextStyle(
                          color: themeManager.currentTheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: 0.7,
                        backgroundColor: themeManager.currentTheme.surface,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          themeManager.currentTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(), // 收縮時顯示空內容
          ),
        ],
      ),
    );
  }

  /// 獲取主題模式圖標
  IconData _getThemeModeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return Icons.wb_sunny;
      case AppThemeMode.dark:
        return Icons.nightlight_round;
      case AppThemeMode.system:
        return Icons.settings_system_daydream;
    }
  }

  /// 獲取主題模式文字
  String _getThemeModeText(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'Light Mode';
      case AppThemeMode.dark:
        return 'Dark Mode';
      case AppThemeMode.system:
        return 'System Default';
    }
  }

  /// 獲取下拉選單的填充顏色
  Color _getDropdownFillColor(ThemeConfigManager themeManager) {
    final currentTheme = themeManager.currentTheme;

    // Meta 主題使用配對的背景色
    if (currentTheme.name.contains('meta_business')) {
      return currentTheme.background; // 使用主題的背景色，不透明
    }

    // Business 主題使用不透明背景
    if (currentTheme.name.contains('business')) {
      return Colors.white; // 純白色，不透明
    }

    // 其他主題使用半透明背景
    return themeManager.currentTheme.surface.withOpacity(0.9);
  }

  /// 獲取當前主題組的代表主題
  ThemeScheme _getCurrentThemeGroupRepresentative(
      ThemeConfigManager themeManager) {
    final currentTheme = themeManager.currentTheme;
    final groupedThemes = themeManager.groupedThemesWithDarkMode;

    // 找到當前主題所屬的組
    for (final entry in groupedThemes.entries) {
      if (entry.value.contains(currentTheme)) {
        return entry.value.first; // 返回該組的第一個主題作為代表
      }
    }

    // 如果找不到，返回當前主題
    return currentTheme;
  }
}
