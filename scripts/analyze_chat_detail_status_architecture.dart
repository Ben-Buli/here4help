#!/usr/bin/env dart
// ChatDetailPage 任務狀態 Bar 架構分析驗證腳本
// 使用方法：dart scripts/analyze_chat_detail_status_architecture.dart

import 'dart:io';

void main() {
  print('🔍 ChatDetailPage 任務狀態 Bar 架構分析驗證\n');

  final results = <String, bool>{};
  final details = <String, List<String>>{};

  // 檢查 1：核心組件文件
  results['核心組件文件'] = _checkCoreComponents(details);

  // 檢查 2：配置管理文件
  results['配置管理文件'] = _checkConfigFiles(details);

  // 檢查 3：狀態管理邏輯
  results['狀態管理邏輯'] = _checkStatusManagement(details);

  // 檢查 4：實時更新機制
  results['實時更新機制'] = _checkRealtimeUpdates(details);

  // 檢查 5：UI 組件完整性
  results['UI 組件完整性'] = _checkUIComponents(details);

  // 輸出結果
  _printResults(results, details);

  // 提供建議
  _provideRecommendations(results);
}

bool _checkCoreComponents(Map<String, List<String>> details) {
  final files = [
    'lib/chat/pages/chat_detail_page.dart',
    'lib/chat/widgets/dynamic_action_bar.dart',
    'lib/chat/utils/action_bar_config.dart',
  ];

  print('📁 檢查核心組件文件:');
  bool allExist = true;
  final componentDetails = <String>[];

  for (final file in files) {
    final exists = File(file).existsSync();
    final status = exists ? '✅' : '❌';
    print('  $status $file');
    componentDetails.add('$file: ${exists ? '存在' : '缺失'}');

    if (exists) {
      _analyzeFile(file, componentDetails);
    }

    allExist = allExist && exists;
  }

  details['核心組件文件'] = componentDetails;
  return allExist;
}

bool _checkConfigFiles(Map<String, List<String>> details) {
  const filePath = 'lib/chat/utils/action_bar_config.dart';
  final file = File(filePath);

  print('\n⚙️ 檢查配置管理文件:');
  final configDetails = <String>[];

  if (!file.existsSync()) {
    print('  ❌ 配置文件不存在: $filePath');
    configDetails.add('配置文件缺失');
    details['配置管理文件'] = configDetails;
    return false;
  }

  final content = file.readAsStringSync();
  final checks = <String, bool>{};

  // 檢查枚舉定義
  checks['TaskStatus 枚舉'] = content.contains('enum TaskStatus');
  checks['UserRole 枚舉'] = content.contains('enum UserRole');

  // 檢查核心類
  checks['ActionBarConfigManager 類'] =
      content.contains('class ActionBarConfigManager');
  checks['ActionBarAction 類'] = content.contains('class ActionBarAction');

  // 檢查核心方法
  checks['getActionsForStatus 方法'] = content.contains('getActionsForStatus');
  checks['parseTaskStatus 方法'] = content.contains('parseTaskStatus');
  checks['getStatusColor 方法'] = content.contains('getStatusColor');
  checks['getStatusIcon 方法'] = content.contains('getStatusIcon');

  for (final entry in checks.entries) {
    final status = entry.value ? '✅' : '❌';
    print('  $status ${entry.key}');
    configDetails.add('${entry.key}: ${entry.value ? '存在' : '缺失'}');
  }

  details['配置管理文件'] = configDetails;
  return checks.values.every((v) => v);
}

bool _checkStatusManagement(Map<String, List<String>> details) {
  const filePath = 'lib/chat/pages/chat_detail_page.dart';
  final file = File(filePath);

  print('\n🔄 檢查狀態管理邏輯:');
  final statusDetails = <String>[];

  if (!file.existsSync()) {
    print('  ❌ ChatDetailPage 文件不存在');
    statusDetails.add('ChatDetailPage 文件缺失');
    details['狀態管理邏輯'] = statusDetails;
    return false;
  }

  final content = file.readAsStringSync();
  final checks = <String, bool>{};

  // 檢查狀態相關方法
  checks['_getStatusDisplayNameForUserRole'] =
      content.contains('_getStatusDisplayNameForUserRole');
  checks['_getColorSchemeForUserRole'] =
      content.contains('_getColorSchemeForUserRole');
  checks['_updateTaskStatusLocally'] =
      content.contains('_updateTaskStatusLocally');
  checks['_updateApplicationStatusLocally'] =
      content.contains('_updateApplicationStatusLocally');
  checks['_updateDerivedStates'] = content.contains('_updateDerivedStates');

  // 檢查 DynamicActionBar 集成
  checks['DynamicActionBar 使用'] = content.contains('DynamicActionBar(');
  checks['狀態參數傳遞'] = content.contains('statusDisplayName:');
  checks['配色方案參數'] = content.contains('colorScheme:');

  for (final entry in checks.entries) {
    final status = entry.value ? '✅' : '❌';
    print('  $status ${entry.key}');
    statusDetails.add('${entry.key}: ${entry.value ? '存在' : '缺失'}');
  }

  details['狀態管理邏輯'] = statusDetails;
  return checks.values.every((v) => v);
}

bool _checkRealtimeUpdates(Map<String, List<String>> details) {
  const filePath = 'lib/chat/pages/chat_detail_page.dart';
  final file = File(filePath);

  print('\n⚡ 檢查實時更新機制:');
  final realtimeDetails = <String>[];

  if (!file.existsSync()) {
    print('  ❌ ChatDetailPage 文件不存在');
    realtimeDetails.add('ChatDetailPage 文件缺失');
    details['實時更新機制'] = realtimeDetails;
    return false;
  }

  final content = file.readAsStringSync();
  final checks = <String, bool>{};

  // 檢查 Socket 監聽器設置
  checks['Socket 服務初始化'] = content.contains('_setupSocket');
  checks['任務狀態更新監聽'] =
      content.contains('onTaskStatusUpdate = _onTaskStatusUpdate');
  checks['應徵狀態更新監聽'] = content
      .contains('onApplicationStatusUpdate = _onApplicationStatusUpdate');
  checks['封鎖狀態更新監聽'] =
      content.contains('onBlockStatusUpdate = _onBlockStatusUpdate');

  // 檢查事件處理方法
  checks['_onTaskStatusUpdate 方法'] =
      content.contains('void _onTaskStatusUpdate(');
  checks['_onApplicationStatusUpdate 方法'] =
      content.contains('void _onApplicationStatusUpdate(');
  checks['狀態變更通知'] = content.contains('_showTaskStatusChangeNotification');

  // 檢查通知機制
  checks['Provider 刷新通知'] = content.contains('_notifyProviderRefresh');

  for (final entry in checks.entries) {
    final status = entry.value ? '✅' : '❌';
    print('  $status ${entry.key}');
    realtimeDetails.add('${entry.key}: ${entry.value ? '存在' : '缺失'}');
  }

  details['實時更新機制'] = realtimeDetails;
  return checks.values.every((v) => v);
}

bool _checkUIComponents(Map<String, List<String>> details) {
  const filePath = 'lib/chat/widgets/dynamic_action_bar.dart';
  final file = File(filePath);

  print('\n🎨 檢查 UI 組件完整性:');
  final uiDetails = <String>[];

  if (!file.existsSync()) {
    print('  ❌ DynamicActionBar 文件不存在');
    uiDetails.add('DynamicActionBar 文件缺失');
    details['UI 組件完整性'] = uiDetails;
    return false;
  }

  final content = file.readAsStringSync();
  final checks = <String, bool>{};

  // 檢查核心 UI 組件
  checks['DynamicActionBar 類'] = content.contains('class DynamicActionBar');
  checks['_buildStatusBar 方法'] = content.contains('_buildStatusBar');
  checks['_buildActionBar 方法'] = content.contains('_buildActionBar');

  // 檢查狀態顯示邏輯
  checks['狀態顏色映射'] = content.contains('getStatusColor');
  checks['狀態圖標映射'] = content.contains('getStatusIcon');
  checks['進度條顯示'] = content.contains('LinearProgressIndicator');
  checks['狀態名稱顯示'] = content.contains('statusDisplayName');

  // 檢查參數完整性
  checks['taskStatus 參數'] = content.contains('final TaskStatus taskStatus');
  checks['userRole 參數'] = content.contains('final UserRole userRole');
  checks['applicationStatus 參數'] =
      content.contains('final String? applicationStatus');
  checks['colorScheme 參數'] = content.contains('final String? colorScheme');

  for (final entry in checks.entries) {
    final status = entry.value ? '✅' : '❌';
    print('  $status ${entry.key}');
    uiDetails.add('${entry.key}: ${entry.value ? '存在' : '缺失'}');
  }

  details['UI 組件完整性'] = uiDetails;
  return checks.values.every((v) => v);
}

void _analyzeFile(String filePath, List<String> details) {
  try {
    final file = File(filePath);
    final content = file.readAsStringSync();
    final lines = content.split('\n').length;

    details.add('  文件行數: $lines');

    // 分析文件特徵
    if (filePath.contains('chat_detail_page.dart')) {
      final classes = RegExp(r'class\s+\w+').allMatches(content).length;
      final methods =
          RegExp(r'(void|Future|Widget|String|bool|int|double)\s+\w+\s*\(')
              .allMatches(content)
              .length;
      details.add('  類別數量: $classes, 方法數量: $methods');
    }
  } catch (e) {
    details.add('  分析失敗: $e');
  }
}

void _printResults(
    Map<String, bool> results, Map<String, List<String>> details) {
  print('\n📊 架構分析結果摘要:');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  for (final entry in results.entries) {
    final status = entry.value ? '✅ 通過' : '❌ 失敗';
    print('  ${entry.key.padRight(12)} $status');

    // 顯示詳細信息
    final itemDetails = details[entry.key] ?? [];
    if (itemDetails.isNotEmpty && !entry.value) {
      for (final detail in itemDetails.take(3)) {
        print('    💡 $detail');
      }
    }
  }

  final totalChecks = results.length;
  final passedChecks = results.values.where((v) => v).length;
  final passRate = (passedChecks / totalChecks * 100).toStringAsFixed(1);

  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('  架構完整度: $passedChecks/$totalChecks ($passRate%)');

  if (passedChecks == totalChecks) {
    print('\n🎉 架構分析通過！系統設計完整。');
  } else {
    print('\n⚠️  發現 ${totalChecks - passedChecks} 個架構問題，需要檢查。');
  }
}

void _provideRecommendations(Map<String, bool> results) {
  print('\n💡 架構建議:');
  print('━━━━━━━━━━━━━━━━━━');

  if (!results['核心組件文件']!) {
    print('1. 確保核心組件文件完整');
    print('   - ChatDetailPage, DynamicActionBar, ActionBarConfigManager');
  }

  if (!results['配置管理文件']!) {
    print('2. 完善配置管理系統');
    print('   - 枚舉定義、狀態映射、顏色配置');
  }

  if (!results['實時更新機制']!) {
    print('3. 實現完整的實時更新');
    print('   - Socket 監聽、事件處理、狀態同步');
  }

  print('\n📚 詳細架構文檔:');
  print('   - docs/chat_detail_status_bar_architecture_analysis.md');
  print('   - docs/chat_detail_status_bar_architecture_diagram.md');

  print('\n🔧 架構優化建議:');
  print('1. 考慮狀態管理的類型安全');
  print('2. 增加單元測試覆蓋');
  print('3. 優化組件性能');
  print('4. 增強錯誤處理機制');
}
