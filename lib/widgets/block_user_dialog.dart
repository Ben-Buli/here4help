import 'package:flutter/material.dart';
import 'package:here4help/chat/services/chat_service.dart';

/// 封鎖用戶對話框
class BlockUserDialog extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;
  final bool isCurrentlyBlocked;
  final VoidCallback? onBlockStatusChanged;

  const BlockUserDialog({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    this.isCurrentlyBlocked = false,
    this.onBlockStatusChanged,
  });

  @override
  State<BlockUserDialog> createState() => _BlockUserDialogState();
}

class _BlockUserDialogState extends State<BlockUserDialog> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.isCurrentlyBlocked ? Icons.block : Icons.block,
            color: widget.isCurrentlyBlocked ? Colors.orange : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(widget.isCurrentlyBlocked ? 'Unblock User' : 'Block User'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isCurrentlyBlocked
                ? 'Are you sure you want to unblock ${widget.targetUserName}?'
                : 'Are you sure you want to block ${widget.targetUserName}?',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          if (widget.isCurrentlyBlocked) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unblocking will restore full communication capabilities.',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Blocking will disable all communication in this chat room.',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _handleBlockAction,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                widget.isCurrentlyBlocked ? Colors.orange : Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(widget.isCurrentlyBlocked ? 'Unblock' : 'Block'),
        ),
      ],
    );
  }

  Future<void> _handleBlockAction() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await ChatService().blockUser(
        targetUserId: int.parse(widget.targetUserId),
        block: !widget.isCurrentlyBlocked,
      );

      if (mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isCurrentlyBlocked
                  ? 'User unblocked successfully'
                  : 'User blocked successfully',
            ),
            backgroundColor:
                widget.isCurrentlyBlocked ? Colors.green : Colors.red,
          ),
        );

        // 通知父組件刷新狀態
        widget.onBlockStatusChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isCurrentlyBlocked
                  ? 'Failed to unblock user: $e'
                  : 'Failed to block user: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// 封鎖狀態檢查工具
class BlockStatusChecker {
  /// 檢查當前用戶是否封鎖了目標用戶
  static bool isUserBlockedByMe({
    required Map<String, dynamic> chatData,
    required int currentUserId,
    required int targetUserId,
  }) {
    // 這裡需要從 chatData 中獲取封鎖狀態
    // 或者通過 API 查詢 user_blocks 表
    return false; // 暫時返回 false，需要實際實現
  }

  /// 檢查當前用戶是否被目標用戶封鎖
  static bool isUserBlockedByTarget({
    required Map<String, dynamic> chatData,
    required int currentUserId,
    required int targetUserId,
  }) {
    // 這裡需要從 chatData 中獲取封鎖狀態
    // 或者通過 API 查詢 user_blocks 表
    return false; // 暫時返回 false，需要實際實現
  }

  /// 獲取封鎖狀態文字描述
  static String getBlockStatusText({
    required bool isBlockedByMe,
    required bool isBlockedByTarget,
  }) {
    if (isBlockedByMe && isBlockedByTarget) {
      return 'Both users have blocked each other';
    } else if (isBlockedByMe) {
      return 'You have blocked this user';
    } else if (isBlockedByTarget) {
      return 'You are blocked by this user';
    } else {
      return 'No blocking relationship';
    }
  }
}
