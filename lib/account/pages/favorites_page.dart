import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:here4help/services/api/task_favorites_api.dart';
import 'package:here4help/widgets/task_favorite_button.dart';
import 'package:here4help/constants/app_colors.dart';

/// 收藏任務列表頁面
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (!_isLoading && _hasMoreData) {
        _loadMoreFavorites();
      }
    }
  }

  Future<void> _loadFavorites() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
    });

    try {
      final result = await TaskFavoritesApi.getFavorites(page: 1, perPage: 20);

      if (mounted) {
        setState(() {
          _favorites = List<Map<String, dynamic>>.from(result['favorites']);
          _isLoading = false;
          _hasMoreData = result['pagination']['current_page'] <
              result['pagination']['total_pages'];
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesPage: 載入收藏失敗: $e');
      }

      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreFavorites() async {
    if (_isLoading || !_hasMoreData) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await TaskFavoritesApi.getFavorites(
        page: _currentPage + 1,
        perPage: 20,
      );

      if (mounted) {
        setState(() {
          _favorites
              .addAll(List<Map<String, dynamic>>.from(result['favorites']));
          _currentPage++;
          _isLoading = false;
          _hasMoreData = result['pagination']['current_page'] <
              result['pagination']['total_pages'];
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesPage: 載入更多收藏失敗: $e');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('載入失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeFavoriteFromList(String taskId) {
    setState(() {
      _favorites.removeWhere((favorite) => favorite['task_id'] == taskId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorites'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFavorites,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _favorites.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load favorites',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFavorites,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No favorites yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tasks you favorite will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _favorites.length + (_hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _favorites.length) {
            // 載入更多指示器
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final favorite = _favorites[index];
          return _FavoriteTaskCard(
            favorite: favorite,
            onFavoriteRemoved: () =>
                _removeFavoriteFromList(favorite['task_id']),
          );
        },
      ),
    );
  }
}

/// 收藏任務卡片
class _FavoriteTaskCard extends StatelessWidget {
  final Map<String, dynamic> favorite;
  final VoidCallback? onFavoriteRemoved;

  const _FavoriteTaskCard({
    required this.favorite,
    this.onFavoriteRemoved,
  });

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return '';

    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateTimeString;
    }
  }

  Color _getStatusColor(String? statusCode) {
    switch (statusCode) {
      case 'open':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題與收藏按鈕
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    favorite['title'] ?? 'Untitled Task',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TaskFavoriteButton(
                  taskId: favorite['task_id'],
                  initialIsFavorited: true,
                  onFavoriteChanged: onFavoriteRemoved,
                  size: 20,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 描述
            if (favorite['description'] != null &&
                favorite['description'].isNotEmpty)
              Text(
                favorite['description'],
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

            const SizedBox(height: 12),

            // 獎勵點數與狀態
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.stars,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${favorite['reward_points'] ?? 0} pts',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(favorite['status_code'])
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    favorite['status_display'] ??
                        favorite['status_code'] ??
                        'Unknown',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _getStatusColor(favorite['status_code']),
                    ),
                  ),
                ),

                const Spacer(),

                // 收藏時間
                Text(
                  'Favorited ${_formatDateTime(favorite['favorited_at'])}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 創建者資訊
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundImage: favorite['creator_avatar'] != null
                      ? NetworkImage(favorite['creator_avatar'])
                      : null,
                  child: favorite['creator_avatar'] == null
                      ? const Icon(Icons.person, size: 14)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'by ${favorite['creator_name'] ?? 'Unknown'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),

                // 任務創建時間
                Text(
                  'Created ${_formatDateTime(favorite['task_created_at'])}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
