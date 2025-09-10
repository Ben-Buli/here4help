/// 非 Web 平台的 stub 實現
class WebEnvironmentBridgeImpl {
  /// 設置消息監聽器（非 Web 平台不執行）
  static void setupMessageListener() {
    // 非 Web 平台不需要實現
  }

  /// 處理環境配置請求（非 Web 平台不執行）
  static void handleEnvironmentConfigRequest() {
    // 非 Web 平台不需要實現
  }
}
