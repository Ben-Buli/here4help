// home_page.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:here4help/services/scroll_event_bus.dart';
import 'package:provider/provider.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/auth/services/auth_service.dart';
import 'package:here4help/constants/app_colors.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/utils/image_helper.dart';
import 'package:here4help/providers/rating_provider.dart';
import 'package:here4help/services/rating_service.dart';
import 'package:here4help/providers/achievement_provider.dart';
import 'package:here4help/config/app_config.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<String>? _scrollSub;

  // 學生證審核狀態相關
  Map<String, dynamic>? _studentVerificationData;
  bool _isCheckingStudentVerification = false;

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

    // 載入評分統計和成就數據
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RatingProvider>().loadUserRatingStats();
      context.read<AchievementProvider>().loadUserAchievements();
      _checkStudentVerificationStatus();
    });
  }

  // 檢查學生證審核狀態
  Future<void> _checkStudentVerificationStatus() async {
    if (_isCheckingStudentVerification || !mounted) return;

    setState(() {
      _isCheckingStudentVerification = true;
    });

    try {
      final userService = context.read<UserService>();
      final user = userService.currentUser;

      if (user?.id == null) {
        return;
      }

      // 檢查本地是否已經隱藏過通知
      final prefs = await SharedPreferences.getInstance();
      final hiddenNotificationKey =
          'student_verification_rejected_hidden_${user!.id}';
      final isHidden = prefs.getBool(hiddenNotificationKey) ?? false;

      if (isHidden) {
        return; // 用戶已經隱藏過這個通知，不再顯示
      }

      // 呼叫API檢查學生證狀態
      final token = await AuthService.getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse(
            '${AppConfig.apiBaseUrl}/api/auth/get-student-verification-status.php'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final verificationData = data['data'] as Map<String, dynamic>;

          // 只有當狀態為 'rejected' 時才顯示按鈕
          if (verificationData['verification_status'] == 'rejected') {
            setState(() {
              _studentVerificationData = verificationData;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('檢查學生證狀態失敗: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingStudentVerification = false;
        });
      }
    }
  }

  // 隱藏學生證審核失敗通知
  Future<void> _hideStudentVerificationNotification() async {
    final userService = context.read<UserService>();
    final user = userService.currentUser;

    if (user?.id != null) {
      final prefs = await SharedPreferences.getInstance();
      final hiddenNotificationKey =
          'student_verification_rejected_hidden_${user!.id}';
      await prefs.setBool(hiddenNotificationKey, true);

      setState(() {
        _studentVerificationData = null;
      });
    }
  }

  // 導航到學生證更新頁面
  void _navigateToStudentIdUpdate() {
    // TODO: 實現導航到學生證更新頁面，並傳遞被拒絕的資料
    context.go('/signup/student-id/update', extra: _studentVerificationData);
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
                            Row(
                              children: [
                                Builder(
                                  // 使用 Builder 來確保 user 顯示名稱(顯示順序: nickname -> name -> User)
                                  builder: (context) {
                                    final displayName = [
                                      user?.nickname,
                                      user?.name,
                                      'User'
                                    ]
                                        .firstWhere(
                                            (v) => v != null && v.isNotEmpty)
                                        .toString();
                                    return Text(displayName,
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black));
                                  },
                                ),
                                Builder(
                                  builder: (context) {
                                    String? getPermissionStatus(int? level) {
                                      if (level == -1 || level == -3) {
                                        return 'Suspended';
                                      } else if (level == 0) {
                                        return 'Unverified';
                                      }
                                      return null;
                                    }

                                    final status =
                                        getPermissionStatus(user?.permission);
                                    if (status != null) {
                                      return Row(
                                        children: [
                                          const SizedBox(width: 12),
                                          Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                '($status)',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .secondary,
                                                  fontWeight: FontWeight.bold,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              )),
                                        ],
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ),
                            Text(
                                '${NumberFormat.decimalPattern().format(user?.points ?? 0)} points',
                                style: const TextStyle(fontSize: 16)),
                            Consumer<RatingProvider>(
                              builder: (context, ratingProvider, child) {
                                final stats = ratingProvider.userRatingStats;

                                if (ratingProvider.isLoading) {
                                  return const Row(
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Loading ratings...',
                                          style: TextStyle(
                                              fontSize: 12, color: Colors.grey))
                                    ],
                                  );
                                }

                                if (stats == null || stats.totalReviews == 0) {
                                  return const Row(
                                    children: [
                                      Icon(Icons.star_border,
                                          color: Colors.grey, size: 16),
                                      SizedBox(width: 4),
                                      Text('No ratings yet',
                                          style: TextStyle(
                                              fontSize: 12, color: Colors.grey))
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    ...RatingService.buildStarRating(
                                        stats.avgRating,
                                        size: 16),
                                    const SizedBox(width: 4),
                                    Text(RatingService.formatRatingText(stats),
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey))
                                  ],
                                );
                              },
                            )
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 學生證審核失敗通知按鈕
                    if (_studentVerificationData != null) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_outlined,
                                  color: Colors.orange,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Student ID Verification Failed',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed:
                                      _hideStudentVerificationNotification,
                                  icon: Icon(
                                    Icons.close,
                                    color: Colors.grey[600],
                                    size: 20,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_studentVerificationData![
                                    'verification_notes'] !=
                                null) ...[
                              Text(
                                'Reason: ${_studentVerificationData!['verification_notes']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _navigateToStudentIdUpdate,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Re-upload Student ID'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

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
                    Consumer<AchievementProvider>(
                      builder: (context, achievementProvider, child) {
                        if (achievementProvider.isLoading) {
                          return const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _AchievementBox(
                                  label: 'Total Coins', value: '...'),
                              _AchievementBox(
                                  label: 'Task Completed', value: '...'),
                              _AchievementBox(
                                  label: 'Five-Star Ratings', value: '...'),
                              _AchievementBox(
                                  label: 'Avg Rating', value: '...'),
                            ],
                          );
                        }

                        final formatted =
                            achievementProvider.getFormattedAchievements();

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _AchievementBox(
                                label: 'Total Coins',
                                value: formatted['total_coins']!),
                            _AchievementBox(
                                label: 'Task Completed',
                                value: formatted['tasks_completed']!),
                            _AchievementBox(
                                label: 'Five-Star Ratings',
                                value: formatted['five_star_ratings']!),
                            _AchievementBox(
                                label: 'Avg Rating',
                                value: formatted['avg_rating']! == 'N/A'
                                    ? '0.0'
                                    : formatted['avg_rating']!),
                          ],
                        );
                      },
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
                    color: themeManager.currentTheme.onSecondary,
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
                          themeManager.currentTheme.secondary,
                          themeManager.currentTheme.primary,
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

// 上下平的六邊形 - 類似圖片中的形狀
class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final double w = size.width;

    // 正六邊形公式：高度 = sqrt(3)/2 * width
    final double hexHeight = (sqrt(3) / 2) * w;

    final List<Offset> points = [
      Offset(w * 0.25, 0), // 左上
      Offset(w * 0.75, 0), // 右上
      Offset(w, hexHeight / 2), // 右中
      Offset(w * 0.75, hexHeight), // 右下
      Offset(w * 0.25, hexHeight), // 左下
      Offset(0, hexHeight / 2), // 左中
    ];

    return Path()..addPolygon(points, true);
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
