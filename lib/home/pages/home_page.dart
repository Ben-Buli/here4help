// home_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:here4help/services/scroll_event_bus.dart';
import 'package:provider/provider.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/constants/app_colors.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/utils/image_helper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<String>? _scrollSub;

  @override
  void initState() {
    super.initState();
    _scrollSub = ScrollEventBus().stream.listen((route) {
      if (!mounted) return;
      if (route == '/home' && _scrollController.hasClients) {
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _scrollSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isWide = constraints.maxWidth > 800;
          final user = context.watch<UserService>().currentUser;
          return Align(
            alignment: Alignment.topCenter, // 將內容靠上對齊
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 800 : double.infinity,
              ),
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // 水平方向靠左對齊
                  mainAxisAlignment: MainAxisAlignment.start, // 垂直方向靠上對齊
                  children: [
                    Row(
                      children: [
                        user?.avatar_url != null && user!.avatar_url.isNotEmpty
                            ? CircleAvatar(
                                radius: 30,
                                backgroundImage:
                                    ImageHelper.getAvatarImage(user.avatar_url),
                                onBackgroundImageError:
                                    (exception, stackTrace) {
                                  debugPrint('頭像載入錯誤: $exception');
                                },
                              )
                            : const CircleAvatar(
                                radius: 30,
                                child: Icon(Icons.person),
                              ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.name ?? 'User',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(
                                '${NumberFormat.decimalPattern().format(user?.points ?? 0)} points',
                                style: const TextStyle(fontSize: 16)),
                            const Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 16),
                                Icon(Icons.star, color: Colors.amber, size: 16),
                                Icon(Icons.star, color: Colors.amber, size: 16),
                                Icon(Icons.star, color: Colors.amber, size: 16),
                                Icon(Icons.star, color: Colors.amber, size: 16),
                                SizedBox(width: 4),
                                Text('5 (16 comments)',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey))
                              ],
                            )
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ACHIEVEMENTS',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text(
                              'Congratulations on completing 4 tasks this week'),
                          Text(
                              'Complete just three more tasks to reach the Busy Bee Level and earn 70 coins')
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Your Achievements',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 12),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _AchievementBox(label: 'Total Coins', value: '1200'),
                        _AchievementBox(label: 'Task Completed', value: '20'),
                        _AchievementBox(
                            label: 'Five-Star Ratings', value: '10'),
                        _AchievementBox(label: 'Avg Rating', value: '4.5'),
                      ],
                    ),

                    /// 以下成就系統先隱藏不做
                    // const SizedBox(height: 24),
                    // const Text('Ongoing Challenges',
                    //     style: TextStyle(
                    //         fontWeight: FontWeight.bold, fontSize: 18)),
                    // const SizedBox(height: 12),
                    // SizedBox(
                    //   height: 160,
                    //   child: ListView(
                    //     scrollDirection: Axis.horizontal,
                    //     children: const [
                    //       _ChallengeCard(
                    //           title: 'Complete 3 lifestyle tasks',
                    //           progress: '1/3'),
                    //       _ChallengeCard(
                    //           title: 'Finish 5 tasks this week',
                    //           progress: '2/5'),
                    //       _ChallengeCard(
                    //           title: 'Try multilingual tasks', progress: ''),
                    //       _ChallengeCard(
                    //           title: 'Collect 10 five-star ratings',
                    //           progress: '7/10'),
                    //     ],
                    //   ),
                    // ),
                    // const SizedBox(height: 24),
                    // const Text('Unlockable Achievements',
                    //     style: TextStyle(
                    //         fontWeight: FontWeight.bold, fontSize: 18)),
                    // const SizedBox(height: 12),
                    // const Wrap(
                    //   spacing: 12,
                    //   children: [
                    //     Chip(
                    //       label: Column(
                    //         mainAxisSize: MainAxisSize.min,
                    //         mainAxisAlignment: MainAxisAlignment.center,
                    //         crossAxisAlignment: CrossAxisAlignment.center,
                    //         children: [
                    //           Text('🧭'),
                    //           Text('Explorer'),
                    //         ],
                    //       ),
                    //     ),
                    //     Chip(
                    //       label: Column(
                    //         mainAxisSize: MainAxisSize.min,
                    //         mainAxisAlignment: MainAxisAlignment.center,
                    //         crossAxisAlignment: CrossAxisAlignment.center,
                    //         children: [
                    //           Text('🐝'),
                    //           Text('Busy Bee'),
                    //         ],
                    //       ),
                    //     ),
                    //     Chip(
                    //       label: Column(
                    //         mainAxisSize: MainAxisSize.min,
                    //         mainAxisAlignment: MainAxisAlignment.center,
                    //         crossAxisAlignment: CrossAxisAlignment.center,
                    //         children: [
                    //           Text('💬'),
                    //           Text('Social Star'),
                    //         ],
                    //       ),
                    //     ),
                    //     Chip(
                    //       label: Column(
                    //         mainAxisSize: MainAxisSize.min,
                    //         mainAxisAlignment: MainAxisAlignment.center,
                    //         crossAxisAlignment: CrossAxisAlignment.center,
                    //         children: [
                    //           Text('⭐'),
                    //           Text('5 Star Warrior'),
                    //         ],
                    //       ),
                    //     ),
                    //   ],
                    // ),
                    // const SizedBox(height: 8),
                    // const Text(
                    //     '• Unlock Conditions: Tap to view requirements and progress\n• Rewards Upon Unlock: +10 Coins / Priority Matching / Exclusive Titles',
                    //     style: TextStyle(fontSize: 12, color: Colors.grey))
                    /// 以上，成就系統先隱藏不做
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AchievementBox extends StatelessWidget {
  final String label;
  final String value;
  const _AchievementBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        return Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ClipPath(
                  clipper: HexagonClipper(),
                  child: Container(
                    width: 60,
                    height: 60,
                    color: Colors.black,
                  ),
                ),
                ClipPath(
                  clipper: HexagonClipper(),
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          // 若為 lesbian theme，使用粉藍-白-粉紅漸層
                          if (themeManager.currentTheme.name
                              .startsWith('lesbian_theme')) ...[
                            const Color(0xFF89CFF0),
                            const Color(0xFFFFFFFF),
                            const Color(0xFFF8A1C4),
                          ] else ...[
                            themeManager.currentTheme.primary,
                            themeManager.currentTheme.secondary,
                            themeManager.currentTheme.accent,
                          ]
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 1.5
                          ..color = themeManager.currentTheme.primary,
                      ),
                    ),
                  ),
                ),
                ClipPath(
                  clipper: HexagonClipper(),
                  child: Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: themeManager.currentTheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12))
          ],
        );
      },
    );
  }
}

// 正六角形 - 上下左右長度一致
class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final double w = size.width;
    final double h = size.height;

    // 計算正六角形的邊長
    final double side = w / 2;
    final double centerX = w / 2;
    final double centerY = h / 2;

    // 正六角形的六個頂點
    final List<Offset> points = [
      Offset(centerX, centerY - side), // 頂點
      Offset(centerX + side * 0.866, centerY - side * 0.5), // 右上
      Offset(centerX + side * 0.866, centerY + side * 0.5), // 右下
      Offset(centerX, centerY + side), // 底點
      Offset(centerX - side * 0.866, centerY + side * 0.5), // 左下
      Offset(centerX - side * 0.866, centerY - side * 0.5), // 左上
    ];

    return Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[3].dx, points[3].dy)
      ..lineTo(points[4].dx, points[4].dy)
      ..lineTo(points[5].dx, points[5].dy)
      ..close();
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _ChallengeCard extends StatelessWidget {
  final String title;
  final String progress;
  const _ChallengeCard({required this.title, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (progress.isNotEmpty)
            Text('($progress completed)',
                style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {},
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Take on Task Now'),
            ),
          )
        ],
      ),
    );
  }
}
