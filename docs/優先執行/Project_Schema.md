.
├── analysis_options.yaml
├── assets
│   ├── app_env
│   │   ├── development.example.json
│   │   ├── development.json
│   │   ├── facebook_config.json
│   │   ├── production.example.json
│   │   └── production.json
│   ├── icon
│   │   ├── app_icon_2.png
│   │   ├── app_icon_bordered.png
│   │   ├── AppIcon-no-bg.png
│   │   ├── AppIcon-no-bg.svg
│   │   └── AppIcon.png
│   └── images
│       └── avatar
│           ├── avatar-1.png
│           ├── avatar-2.png
│           ├── avatar-3.png
│           ├── avatar-4.png
│           ├── avatar-5.png
│           └── avatar-1.png
├── backend
│   ├── api
│   │   ├── auth
│   │   │   ├── get-uploaded-images.php
│   │   │   ├── google-callback.php
│   │   │   ├── google-login.php
│   │   │   ├── login.php
│   │   │   ├── oauth-signup.php
│   │   │   ├── profile.php
│   │   │   ├── register-oauth.php
│   │   │   ├── register-with-student-id.php
│   │   │   ├── register.php
│   │   │   ├── update-profile.php
│   │   │   ├── upload-student-id.php
│   │   │   └── verify-referral-code.php
│   │   ├── chat
│   │   │   ├── block_user.php
│   │   │   ├── ensure_room.php
│   │   │   ├── get_chat_detail_data.php
│   │   │   ├── get_messages.php
│   │   │   ├── get_rooms.php
│   │   │   ├── mark_read.php
│   │   │   ├── read_room_v2.php
│   │   │   ├── report.php
│   │   │   ├── rooms.php
│   │   │   ├── send_message.php
│   │   │   ├── total_unread.php
│   │   │   ├── unread_by_tasks.php
│   │   │   ├── unread_for_ui.php
│   │   │   ├── unreads.php
│   │   │   └── upload_attachment.php
│   │   ├── languages
│   │   │   └── list.php
│   │   ├── points
│   │   │   └── request_topup.php
│   │   ├── referral
│   │   │   ├── get-referral-code.php
│   │   │   ├── list-referral-codes.php
│   │   │   └── use-referral-code.php
│   │   ├── tasks
│   │   │   ├── applications
│   │   │   ├── confirm_completion.php
│   │   │   ├── create.php
│   │   │   ├── disagree_completion.php
│   │   │   ├── generate-sample-data.php
│   │   │   ├── list.php
│   │   │   ├── migrate_salary_to_reward_point.php
│   │   │   ├── pay_and_review.php
│   │   │   ├── reviews_get.php
│   │   │   ├── reviews_submit.php
│   │   │   ├── statuses.php
│   │   │   ├── task_edit_data.php
│   │   │   └── update.php
│   │   ├── test_auth_debug.php
│   │   ├── test_simple.php
│   │   └── universities
│   │       └── list.php
│   ├── api_wrapper.php
│   ├── auth_helper.php
│   ├── auth_test_query_param.php
│   ├── auth_test_with_helper.php
│   ├── basic_test.php
│   ├── check_data_status.php
│   ├── check_database_schema.php
│   ├── check_database_structure.php
│   ├── check_environment.php
│   ├── check_table_structure.php
│   ├── config
│   │   ├── database.example.php
│   │   ├── database.php
│   │   ├── env_loader.php
│   │   ├── env_test.php
│   │   ├── env.development
│   │   ├── env.example
│   │   ├── README_ENV_SETUP.md
│   │   └── test_env.php
│   ├── database
│   │   ├── database_manager.php
│   │   ├── fix_structure.php
│   │   ├── generate_report.php
│   │   ├── migrations
│   │   │   ├── 2025_08_08_000001_create_task_statuses.sql
│   │   │   ├── 2025_08_08_000002_add_status_id_and_creator_acceptor_to_tasks.sql
│   │   │   ├── 2025_08_08_000003_backfill_creator_id.sql
│   │   │   ├── 2025_08_08_000004_enforce_creator_id_drop_creator_name.sql
│   │   │   ├── 2025_08_09_000010_create_chat_tables.sql
│   │   │   ├── 2025_08_10_000001_standardize_chat_room_ids.sql
│   │   │   ├── 2025_08_10_000002_cleanup_chat_reads.sql
│   │   │   ├── 2025_08_10_000003_fix_chat_messages_columns.sql
│   │   │   ├── 2025_08_11_000010_create_user_blocks.sql
│   │   │   └── 2025_08_16_000001_add_id_to_chat_reads.sql
│   │   ├── quick_validate.php
│   │   ├── README.md
│   │   ├── test_connection.php
│   │   └── validate_structure.php
│   ├── debug_get_messages.php
│   ├── debug_task_applications.php
│   ├── fill_view_resume_messages.php
│   ├── generate_test_data.php
│   ├── scripts
│   │   ├── clean_jwt_migration.php
│   │   ├── migrate_to_jwt.php
│   │   └── verify_jwt_migration.php
│   ├── simple_auth_test.php
│   ├── socket
│   │   ├── package-lock.json
│   │   ├── package.json
│   │   ├── server.js
│   │   ├── server.log
│   │   ├── server.out.log
│   │   └── test_jwt.js
│   ├── test_api_debug.php
│   ├── test_api_wrapper.php
│   ├── test_auth_debug.php
│   ├── test_authorization.php
│   ├── test_google_oauth_config.php
│   ├── test_google_oauth_simple.php
│   ├── test_google_oauth.php
│   ├── test_jwt_fix.php
│   ├── test_jwt_simple.php
│   ├── test_jwt.php
│   ├── update_chat_messages_kind.sql
│   ├── uploads
│   └── utils
│       ├── ChatSecurity.php
│       ├── JWTManager.php
│       ├── Response.php
│       └── TokenValidator.php
├── Chat System — 結構化規格文件.md
├── debug_checklist.md
├── devtools_options.yaml
├── docs
│   ├── 優先執行
│   │   ├── 聊天室模組_整合規格.md
│   │   ├── 權限設置開發追蹤表.md
│   │   ├── 環境配置整合說明.md
│   │   ├── 登入註冊＿規格整合文件.md
│   │   ├── 登入註冊＿部署檢查清單.md
│   │   ├── 登入註冊＿階段性任務追蹤表.md
│   │   ├── 第三方登入整合執行步驟.md
│   │   ├── 除錯完成報告.md
│   │   ├── ACTION_BAR_FULL.md
│   │   ├── Facebook_密鑰雜湊配置指南.md
│   │   ├── Facebook_登入配置指南.md
│   │   ├── Facebook_Android_SDK_配置檢查清單.md
│   │   ├── GOOGLE_OAUTH_CALLBACK_IMPLEMENTATION.md
│   │   ├── ngrok_Facebook_登入配置指南.md
│   │   ├── Project_Schema.md
│   │   ├── README_專案整合規格文件.md
│   │   └── ReadME_Here4Help專案＿變更記錄追蹤表.md
│   ├── 版本回溯要點.json
│   ├── 登入註冊模組檔案架構統整報告.md
│   ├── admin
│   │   └── database-validation-tools.md
│   ├── analysis
│   │   ├── FILE_INTEGRITY_CHECK.md
│   │   ├── PROJECT_DATA_FLOW.md
│   │   └── TASK_STATUS_OPTIMIZATION_ANALYSIS.md
│   ├── archive
│   │   ├── DUPLICATE_FILES_CLEANUP_REPORT.md
│   │   ├── PROJECT_CLEANUP_ANALYSIS.md
│   │   ├── PROJECT_ORGANIZATION_SUMMARY.md
│   │   ├── PROJECT_STRUCTURE.md
│   │   └── ROOT_DIRECTORY_CLEANUP_REPORT.md
│   ├── bug-fixes
│   │   ├── AVATAR_IMAGE_TROUBLESHOOTING.md
│   │   ├── BUG_FIXES_SUMMARY.md
│   │   ├── CHAT_LIST_LAYOUT_FIX.md
│   │   ├── CHAT_LIST_LOADING_FIX.md
│   │   ├── CIRCLE_AVATAR_FIX.md
│   │   ├── COLORS_BLUE_TO_THEME_SUMMARY.md
│   │   ├── DROPDOWN_ERROR_FIX.md
│   │   ├── HEXAGON_ACHIEVEMENTS_UPDATE.md
│   │   ├── INFINITE_REFRESH_PREVENTION.md
│   │   ├── TASK_LIST_PAGE_BACKGROUND_FIX.md
│   │   ├── TASK_PAGE_EDIT_ICON_ADDITION.md
│   │   └── TASK_STATUS_FIX_SUMMARY.md
│   ├── chat
│   │   ├── CHAT_COMPLETION_SUMMARY.md
│   │   ├── CHAT_LIST_REFACTOR.md
│   │   ├── CHAT_PROTOCOL.md
│   │   └── chat-system-improvements.md
│   ├── CLEANUP_SUMMARY_2025_08_17.md
│   ├── cursor_.md
│   ├── cursor_execute_task_for_action_bar.md
│   ├── cursor_my_works.md
│   ├── CURSOR_TODO_OPTIMIZED.md
│   ├── CURSOR_TODO.md
│   ├── DATABASE_SCHEMA.md
│   ├── deployment
│   │   └── CPANEL_DEPLOYMENT_GUIDE.md
│   ├── development-logs
│   │   ├── CHAT_PERSISTENCE_IMPLEMENTATION.md
│   │   ├── CHAT_SYNC_LOADING_REFACTOR.md
│   │   ├── DATABASE_SYNC_ANALYSIS_2025_01_11.md
│   │   ├── FLUTTER_APP_DEVELOPMENT_LOG.md
│   │   ├── MIGRATION_COMPLETE.md
│   │   ├── MIGRATION_GUIDE.md
│   │   ├── NAVIGATION_DEBUG_GUIDE.md
│   │   ├── PATH_MAPPING_GUIDE.md
│   │   ├── PROFILE_PAGE_UPDATE_SUMMARY.md
│   │   ├── project_structure_suggestion.md
│   │   ├── ROUTING_NAVIGATION_FIX.md
│   │   ├── structure.txt
│   │   └── UI_STYLE_GUIDE.md
│   ├── ENVIRONMENT_CONFIGURATION_GUIDE.md
│   ├── EXECUTION_GUIDE_CHAT_READ_AND_UI.md
│   ├── GITIGNORE_EXAMPLE.md
│   ├── GOOGLE_AUTH_SETUP.md
│   ├── GOOGLE_OAUTH_FIX_GUIDE.md
│   ├── GOOGLE_OAUTH_SETUP_CHECKLIST.md
│   ├── guides
│   │   ├── CURSOR_EXECUTE.md
│   │   ├── ENV_SETUP_GUIDE.md
│   │   ├── FLUTTER_APP_GIT_PUSH_COMMANDS.md
│   │   ├── GIT_PUSH_COMMANDS.md
│   │   ├── QUICK_REFERENCE_INDEX.md
│   │   ├── SEVEN_DAY_PLAN.md
│   │   └── TASK_STATUS_DESIGN.md
│   ├── JWT_MIGRATION_GUIDE.md
│   ├── reports
│   │   ├── ENV_SETUP_COMPLETION_REPORT.md
│   │   └── FUNCTION_VERIFICATION_REPORT.md
│   ├── SIGNUP_PAGE_LAYOUT_FIX.md
│   ├── task
│   ├── testing
│   │   ├── flutter-chat-testing-guide.md
│   │   ├── flutter-web-testing-guide.md
│   │   └── web-testing-summary.md
│   ├── THEME_ARCHITECTURE_CURRENT.md
│   ├── THEME_CATEGORY_SYSTEM.md
│   ├── THEME_SYSTEM_ARCHITECTURE.md
│   ├── THEME_USAGE_GUIDE.md
│   ├── theme-updates
│   │   ├── META_BUSINESS_PURPLE_THEME_UPDATE.md
│   │   ├── META_BUSINESS_THEME_UPDATE.md
│   │   ├── THEME_CONFIG_SYSTEM_OPTIMIZATION.md
│   │   ├── THEME_PAGE_ENGLISH_TRANSLATION.md
│   │   ├── THEME_PAGE_SCAFFOLD_FIX.md
│   │   ├── THEME_PROVIDER_FIX_SUMMARY.md
│   │   ├── THEME_SERVICE_FIX_SUMMARY.md
│   │   ├── THEME_STYLE_DEFAULT_TO_STANDARD_FIX.md
│   │   └── THEME_UPDATE_PUSH_COMMANDS.md
│   ├── THIRD_PARTY_AUTH_CONFIG.md
│   ├── THIRD_PARTY_LOGIN_FLOW.md
│   ├── TODO_DASHBOARD.md
│   ├── TODO_INDEX.md
│   ├── TODO_INTEGRATED.md
│   └── WEB_OAUTH_IMPLEMENTATION_GUIDE.md
├── env_config
│   ├── dart-define-dev.example.txt
│   ├── dart-define-dev.txt
│   ├── dart-define-prod.txt
│   ├── dev.example.json
│   └── staging.json
├── final_push_v1.2.4.sh
├── flutter_01.log
├── flutter_logs.txt
├── lib
│   ├── account
│   │   ├── models
│   │   │   └── account_routes.dart
│   │   └── pages
│   │       ├── account_page.dart
│   │       ├── change_password.dart
│   │       ├── contact_us_page.dart
│   │       ├── faq_page.dart
│   │       ├── issue_status_page.dart
│   │       ├── logout_page.dart
│   │       ├── point_policy.dart
│   │       ├── profile_page.dart
│   │       ├── ratings_page.dart
│   │       ├── security_page.dart
│   │       ├── support_page.dart
│   │       ├── task_history_page.dart
│   │       ├── theme_settings_page.dart
│   │       └── wallet_page.dart
│   ├── auth
│   │   ├── models
│   │   │   ├── signup_model.dart
│   │   │   └── user_model.dart
│   │   ├── pages
│   │   │   ├── auth_callback_page.dart
│   │   │   ├── login_page.dart
│   │   │   ├── oauth_signup_page.dart
│   │   │   ├── signup_page.dart
│   │   │   └── student_id_page.dart
│   │   ├── services
│   │   │   ├── auth_guard.dart
│   │   │   ├── auth_service.dart
│   │   │   ├── referral_service.dart
│   │   │   ├── third_party_auth_service.dart
│   │   │   └── user_service.dart
│   │   └── widgets
│   │       └── six_digit_code_field.dart
│   ├── chat
│   │   ├── models
│   │   │   ├── chat_detail_model.dart
│   │   │   └── chat_room_model.dart
│   │   ├── pages
│   │   │   ├── chat_debug_page.dart
│   │   │   ├── chat_detail_page.dart
│   │   │   ├── chat_list_page.dart
│   │   │   └── chat_page_wrapper.dart
│   │   ├── providers
│   │   │   ├── chat_list_provider.dart
│   │   │   └── chat_providers.dart
│   │   ├── README_CACHE_SYSTEM.md
│   │   ├── README_PIN_FEATURE.md
│   │   ├── services
│   │   │   ├── chat_cache_manager.dart
│   │   │   ├── chat_service.dart
│   │   │   ├── chat_session_manager.dart
│   │   │   ├── chat_storage_service.dart
│   │   │   ├── global_chat_room.dart
│   │   │   ├── smart_refresh_strategy.dart
│   │   │   ├── socket_service.dart
│   │   │   ├── unified_chat_api_service.dart
│   │   │   └── unified_persistence_manager.dart
│   │   ├── utils
│   │   │   └── avatar_error_cache.dart
│   │   └── widgets
│   │       ├── chat_detail_wrapper.dart
│   │       ├── chat_list_task_widget.dart
│   │       ├── chat_title_widget.dart
│   │       ├── my_works_widget.dart
│   │       ├── posted_tasks_widget.dart
│   │       ├── search_filter_widget.dart
│   │       ├── shared
│   │       ├── task_appbar_title.dart
│   │       ├── task_card_components.dart
│   │       ├── trackpad_gesture_fix.dart
│   │       └── update_status_indicator.dart
│   ├── config
│   │   ├── app_config.dart
│   │   └── environment_config.dart
│   ├── constants
│   │   ├── app_colors.dart
│   │   ├── app_scaffold_config.dart
│   │   ├── route_permissions.dart
│   │   ├── shell_pages.dart
│   │   ├── task_status.dart
│   │   ├── theme_categories.dart
│   │   ├── theme_schemes_optimized.dart
│   │   └── theme_schemes.dart
│   ├── debug
│   │   ├── unread_api_test_page.dart
│   │   └── unread_timing_test_page.dart
│   ├── examples
│   │   └── test_theme_categories.dart
│   ├── explore
│   │   └── pages
│   │       └── explore_page.dart
│   ├── home
│   │   └── pages
│   │       └── home_page.dart
│   ├── layout
│   │   └── app_scaffold.dart
│   ├── main.dart
│   ├── pay
│   │   └── pages
│   │       └── pay_setting_page.dart
│   ├── providers
│   │   └── permission_provider.dart
│   ├── router
│   │   └── app_router.dart
│   ├── services
│   │   ├── country_service.dart
│   │   ├── data_preload_service.dart
│   │   ├── error_handler_service.dart
│   │   ├── http_client_service.dart
│   │   ├── notification_service.dart
│   │   ├── permission_service.dart
│   │   ├── scroll_event_bus.dart
│   │   ├── theme_config_manager.dart
│   │   ├── theme_management_service.dart
│   │   └── unread_service_v2.dart
│   ├── system
│   │   └── pages
│   │       ├── banned_page.dart
│   │       ├── permission_denied_page.dart
│   │       ├── unauthorized_page.dart
│   │       └── unknown_page.dart
│   ├── task
│   │   ├── controllers
│   │   ├── models
│   │   │   └── task_model.dart
│   │   ├── pages
│   │   │   ├── task_apply_page.dart
│   │   │   ├── task_create_page.dart
│   │   │   ├── task_list_page.dart
│   │   │   └── task_preview_page.dart
│   │   ├── services
│   │   │   ├── application_question_service.dart
│   │   │   ├── global_task_apply_resume.dart
│   │   │   ├── language_service.dart
│   │   │   ├── task_service.dart
│   │   │   └── university_service.dart
│   │   ├── utils
│   │   │   ├── task_form_validators.dart
│   │   │   └── user_avatar_helper.dart
│   │   └── widgets
│   ├── utils
│   │   ├── auth_reset_helper.dart
│   │   ├── debug_auth_helper.dart
│   │   ├── debug_helper.dart
│   │   ├── image_helper.dart
│   │   └── path_mapper.dart
│   └── widgets
│       ├── blurred_dropdown.dart
│       ├── color_selector.dart
│       ├── custom_popup.dart
│       ├── error_page.dart
│       ├── glassmorphism_app_bar.dart
│       ├── multi_select_search_dropdown.dart
│       ├── permission_aware_widget.dart
│       ├── range_slider_widget.dart
│       └── theme_aware_components.dart
├── linux
│   ├── CMakeLists.txt
│   ├── flutter
│   │   ├── CMakeLists.txt
│   │   ├── ephemeral
│   │   ├── generated_plugin_registrant.cc
│   │   ├── generated_plugin_registrant.h
│   │   └── generated_plugins.cmake
│   └── runner
│       ├── CMakeLists.txt
│       ├── main.cc
│       ├── my_application.cc
│       └── my_application.h
├── macos
│   ├── Flutter
│   │   ├── ephemeral
│   │   │   ├── flutter_export_environment.sh
│   │   │   └── Flutter-Generated.xcconfig
│   │   ├── Flutter-Debug.xcconfig
│   │   ├── Flutter-Release.xcconfig
│   │   └── GeneratedPluginRegistrant.swift
│   ├── Podfile
│   ├── Podfile.lock
│   ├── Pods
│   │   ├── AppAuth
│   │   │   ├── LICENSE
│   │   │   ├── README.md
│   │   │   └── Sources
│   │   ├── AppCheckCore
│   │   │   ├── AppCheckCore
│   │   │   ├── LICENSE
│   │   │   └── README.md
│   │   ├── GoogleSignIn
│   │   │   ├── GoogleSignIn
│   │   │   ├── LICENSE
│   │   │   └── README.md
│   │   ├── GoogleUtilities
│   │   │   ├── GoogleUtilities
│   │   │   ├── LICENSE
│   │   │   ├── README.md
│   │   │   └── third_party
│   │   ├── GTMAppAuth
│   │   │   ├── GTMAppAuth
│   │   │   ├── LICENSE
│   │   │   └── README.md
│   │   ├── GTMSessionFetcher
│   │   │   ├── LICENSE
│   │   │   ├── README.md
│   │   │   └── Sources
│   │   ├── Headers
│   │   ├── Local Podspecs
│   │   │   ├── facebook_auth_desktop.podspec.json
│   │   │   ├── file_saver.podspec.json
│   │   │   ├── file_selector_macos.podspec.json
│   │   │   ├── flutter_secure_storage_macos.podspec.json
│   │   │   ├── FlutterMacOS.podspec.json
│   │   │   ├── geolocator_apple.podspec.json
│   │   │   ├── google_sign_in_ios.podspec.json
│   │   │   ├── path_provider_foundation.podspec.json
│   │   │   ├── rive_common.podspec.json
│   │   │   ├── shared_preferences_foundation.podspec.json
│   │   │   ├── sign_in_with_apple.podspec.json
│   │   │   ├── smart_auth.podspec.json
│   │   │   └── url_launcher_macos.podspec.json
│   │   ├── Pods.xcodeproj
│   │   │   ├── project.pbxproj
│   │   │   └── xcuserdata
│   │   ├── PromisesObjC
│   │   │   ├── LICENSE
│   │   │   ├── README.md
│   │   │   └── Sources
│   │   └── Target Support Files
│   │       ├── AppAuth
│   │       ├── AppCheckCore
│   │       ├── facebook_auth_desktop
│   │       ├── file_saver
│   │       ├── file_selector_macos
│   │       ├── flutter_secure_storage_macos
│   │       ├── FlutterMacOS
│   │       ├── geolocator_apple
│   │       ├── google_sign_in_ios
│   │       ├── GoogleSignIn
│   │       ├── GoogleUtilities
│   │       ├── GTMAppAuth
│   │       ├── GTMSessionFetcher
│   │       ├── path_provider_foundation
│   │       ├── Pods-Runner
│   │       ├── Pods-RunnerTests
│   │       ├── PromisesObjC
│   │       ├── rive_common
│   │       ├── shared_preferences_foundation
│   │       ├── sign_in_with_apple
│   │       ├── smart_auth
│   │       └── url_launcher_macos
│   ├── Runner
│   │   ├── AppDelegate.swift
│   │   ├── Assets.xcassets
│   │   │   └── AppIcon.appiconset
│   │   ├── Base.lproj
│   │   │   └── MainMenu.xib
│   │   ├── Configs
│   │   │   ├── AppInfo.xcconfig
│   │   │   ├── Debug.xcconfig
│   │   │   ├── Release.xcconfig
│   │   │   └── Warnings.xcconfig
│   │   ├── DebugProfile.entitlements
│   │   ├── Info.plist
│   │   ├── MainFlutterWindow.swift
│   │   └── Release.entitlements
│   ├── Runner.xcodeproj
│   │   ├── project.pbxproj
│   │   ├── project.xcworkspace
│   │   │   └── xcshareddata
│   │   ├── xcshareddata
│   │   │   └── xcschemes
│   │   └── xcuserdata
│   │       └── eliasscott.xcuserdatad
│   ├── Runner.xcworkspace
│   │   ├── contents.xcworkspacedata
│   │   ├── xcshareddata
│   │   │   ├── IDEWorkspaceChecks.plist
│   │   │   └── swiftpm
│   │   └── xcuserdata
│   │       └── eliasscott.xcuserdatad
│   └── RunnerTests
│       └── RunnerTests.swift
├── package-lock.json
├── package.json
├── prepare_push_v1.2.4.sh
├── pubspec.lock
├── pubspec.yaml
├── push_v1.2.3.sh
├── push_v1.2.4.sh
├── README_ENV_SETUP.md
├── README.md
├── release.sh
├── scripts
│   ├── run_api_local.example.sh
│   ├── run_api_local.sh
│   ├── run_app_dev.sh
│   ├── swap_ngrok.sh
│   └── sync_ngrok_urls.sh
├── start_socket_server.sh
├── test
│   └── widget_test.dart
├── test_signup_fix.dart
├── tests
│   └── archived
│       ├── test_acceptance.sh
│       ├── test_chat_system.sh
│       ├── test_point_system.html
│       ├── test_task_logic.md
│       └── test_web_services.sh
└── windows
    ├── CMakeLists.txt
    ├── flutter
    │   ├── CMakeLists.txt
    │   ├── ephemeral
    │   ├── generated_plugin_registrant.cc
    │   ├── generated_plugin_registrant.h
    │   └── generated_plugins.cmake
    └── runner
        ├── CMakeLists.txt
        ├── flutter_window.cpp
        ├── flutter_window.h
        ├── main.cpp
        ├── resource.h
        ├── resources
        │   └── app_icon.ico
        ├── runner.exe.manifest
        ├── Runner.rc
        ├── utils.cpp
        ├── utils.h
        ├── win32_window.cpp
        └── win32_window.h

157 directories, 459 files
