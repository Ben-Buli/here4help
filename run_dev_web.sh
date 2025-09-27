#!/bin/bash

# Flutter Web 本機開發腳本
# 使用與 cPanel 部署一致的 dart-define 方式，避免 .env 檔案載入問題

echo "🚀 啟動本機 Flutter Web 開發服務器..."

# 使用 dart-define 方式傳遞環境變數（與 cPanel 部署一致）
flutter run -d chrome \
  --dart-define=APP_ENVIRONMENT=development \
  --dart-define=APP_DEBUG=true \
  --dart-define=API_BASE_URL=http://localhost:8888/here4help/backend \
  --dart-define=API_ORIGIN=http://localhost:8888 \
  --dart-define=API_PREFIX=/here4help/backend/api \
  --dart-define=IMAGE_BASE_URL=http://localhost:8888/here4help \
  --dart-define=SOCKET_URL=http://localhost:3001 \
  --dart-define=GOOGLE_CLIENT_ID=102744926949-bhrnm2970bgt3dfm2nmdbqt03mrvdh3i.apps.googleusercontent.com \
  --dart-define=GOOGLE_REDIRECT_URI=http://localhost:8888/here4help/backend/api/auth/google-callback.php \
  --dart-define=FACEBOOK_APP_ID=1037019294991326 \
  --dart-define=FACEBOOK_REDIRECT_URI=http://localhost:8888/here4help/backend/api/auth/facebook-callback.php \
  --dart-define=APPLE_SERVICE_ID=com.nccu.here4help.login \
  --dart-define=APPLE_REDIRECT_URI=http://localhost:8888/here4help/backend/api/auth/apple-callback.php

echo "✅ 開發服務器已啟動"
echo "🌐 本機環境使用與 cPanel 一致的 dart-define 配置方式"
