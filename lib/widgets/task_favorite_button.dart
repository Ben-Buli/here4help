import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:here4help/services/api/task_favorites_api.dart';

/// 任務收藏按鈕組件
class TaskFavoriteButton extends StatefulWidget {
  final String taskId;
  final bool initialIsFavorited;
  final VoidCallback? onFavoriteChanged;
  final double? size;
  final Color? favoriteColor;
  final Color? unfavoriteColor;

  const TaskFavoriteButton({
    super.key,
    required this.taskId,
    this.initialIsFavorited = false,
    this.onFavoriteChanged,
    this.size = 24.0,
    this.favoriteColor = Colors.red,
    this.unfavoriteColor = Colors.grey,
  });

  @override
  State<TaskFavoriteButton> createState() => _TaskFavoriteButtonState();
}

class _TaskFavoriteButtonState extends State<TaskFavoriteButton> {
  bool _isFavorited = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isFavorited = widget.initialIsFavorited;
  }

  @override
  void didUpdateWidget(TaskFavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIsFavorited != widget.initialIsFavorited) {
      setState(() {
        _isFavorited = widget.initialIsFavorited;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isFavorited) {
        // 取消收藏
        await TaskFavoritesApi.removeFavorite(taskId: widget.taskId);

        if (mounted) {
          setState(() {
            _isFavorited = false;
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已取消收藏'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        // 添加收藏
        await TaskFavoritesApi.addFavorite(taskId: widget.taskId);

        if (mounted) {
          setState(() {
            _isFavorited = true;
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已加入收藏'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }

      // 通知父組件收藏狀態變更
      widget.onFavoriteChanged?.call();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TaskFavoriteButton: 收藏操作失敗: $e');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isLoading ? null : _toggleFavorite,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: _isLoading
            ? SizedBox(
                width: widget.size,
                height: widget.size,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.favoriteColor ?? Colors.red,
                  ),
                ),
              )
            : Icon(
                _isFavorited ? Icons.favorite : Icons.favorite_border,
                size: widget.size,
                color: _isFavorited
                    ? (widget.favoriteColor ?? Colors.red)
                    : (widget.unfavoriteColor ?? Colors.grey),
              ),
      ),
    );
  }
}

/// 任務收藏按鈕（文字版本）
class TaskFavoriteTextButton extends StatefulWidget {
  final String taskId;
  final bool initialIsFavorited;
  final VoidCallback? onFavoriteChanged;

  const TaskFavoriteTextButton({
    super.key,
    required this.taskId,
    this.initialIsFavorited = false,
    this.onFavoriteChanged,
  });

  @override
  State<TaskFavoriteTextButton> createState() => _TaskFavoriteTextButtonState();
}

class _TaskFavoriteTextButtonState extends State<TaskFavoriteTextButton> {
  bool _isFavorited = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isFavorited = widget.initialIsFavorited;
  }

  @override
  void didUpdateWidget(TaskFavoriteTextButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIsFavorited != widget.initialIsFavorited) {
      setState(() {
        _isFavorited = widget.initialIsFavorited;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isFavorited) {
        await TaskFavoritesApi.removeFavorite(taskId: widget.taskId);

        if (mounted) {
          setState(() {
            _isFavorited = false;
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已取消收藏'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        await TaskFavoritesApi.addFavorite(taskId: widget.taskId);

        if (mounted) {
          setState(() {
            _isFavorited = true;
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已加入收藏'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }

      widget.onFavoriteChanged?.call();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TaskFavoriteTextButton: 收藏操作失敗: $e');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _isLoading ? null : _toggleFavorite,
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              _isFavorited ? Icons.favorite : Icons.favorite_border,
              size: 16,
              color: _isFavorited ? Colors.red : Colors.grey,
            ),
      label: Text(
        _isFavorited ? 'Favorited' : 'Favorite',
        style: TextStyle(
          color: _isFavorited ? Colors.red : Colors.grey[600],
        ),
      ),
    );
  }
}

