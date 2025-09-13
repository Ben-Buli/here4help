/**
 * Web 環境配置注入器
 * 安全地將 Flutter 環境配置注入到 Web JavaScript 中
 */

(function() {
  'use strict';
  
  // 等待 Flutter 應用初始化完成
  window.addEventListener('flutter-first-frame', function() {
    // 從 Flutter 獲取環境配置
    if (window.flutter_service_worker_version) {
      // Flutter Web 已載入，嘗試獲取環境配置
      requestEnvironmentConfig();
    }
  });

  // 請求環境配置
  function requestEnvironmentConfig() {
    // 發送消息到 Flutter 主應用
    if (window.parent && window.parent.postMessage) {
      window.parent.postMessage({
        type: 'REQUEST_ENVIRONMENT_CONFIG',
        source: 'web_oauth_handler'
      }, '*');
    }
  }

  // 監聽來自 Flutter 的環境配置回應
  window.addEventListener('message', function(event) {
    if (event.data && event.data.type === 'ENVIRONMENT_CONFIG_RESPONSE') {
      const config = event.data.config;
      
      // 設置全域環境配置（僅公開配置）
      window.environmentConfig = {
        googleClientId: config.google_client_id || '',
        facebookAppId: config.facebook_app_id || '',
        appleServiceId: config.apple_service_id || ''
      };

      console.log('✅ Web 環境配置已載入');
      
      // 觸發自定義事件，通知配置已準備好
      window.dispatchEvent(new CustomEvent('environmentConfigReady', {
        detail: window.environmentConfig
      }));
    }
  });

  // 備用方案：使用預設配置（開發環境）
  setTimeout(function() {
    if (!window.environmentConfig) {
      console.warn('⚠️ 未能獲取 Flutter 環境配置，使用預設值');
      
      // 僅在開發環境使用預設配置
      if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
        window.environmentConfig = {
          googleClientId: '102744926949-bhrnm2970bgt3dfm2nmdbqt03mrvdh3i.apps.googleusercontent.com',
          facebookAppId: '1037019294991326', 
          appleServiceId: 'com.example.here4help.login'
        };
        
        window.dispatchEvent(new CustomEvent('environmentConfigReady', {
          detail: window.environmentConfig
        }));
      }
    }
  }, 3000); // 3秒後觸發備用方案
})();
