-- 完整的語言資料庫更新腳本
-- 適用於 languages 表格

-- 1. 清空現有資料（可選）
-- DELETE FROM `languages`;

-- 2. 重置 AUTO_INCREMENT（可選）
-- ALTER TABLE `languages` AUTO_INCREMENT = 1;

-- 3. 插入語言資料
INSERT INTO `languages` (`code`, `name`, `native`) VALUES
('en', 'English', 'English'),
('zh', 'Chinese', '中文'),
('es', 'Spanish', 'Español'),
('fr', 'French', 'Français'),
('de', 'German', 'Deutsch'),
('ja', 'Japanese', '日本語'),
('ko', 'Korean', '한국어'),
('pt', 'Portuguese', 'Português'),
('ru', 'Russian', 'Русский'),
('ar', 'Arabic', 'العربية'),
('hi', 'Hindi', 'हिन्दी'),
('it', 'Italian', 'Italiano'),
('nl', 'Dutch', 'Nederlands'),
('sv', 'Swedish', 'Svenska'),
('da', 'Danish', 'Dansk'),
('no', 'Norwegian', 'Norsk'),
('fi', 'Finnish', 'Suomi'),
('pl', 'Polish', 'Polski'),
('tr', 'Turkish', 'Türkçe'),
('th', 'Thai', 'ไทย'),
('vi', 'Vietnamese', 'Tiếng Việt'),
('id', 'Indonesian', 'Bahasa Indonesia'),
('ms', 'Malay', 'Bahasa Melayu'),
('he', 'Hebrew', 'עברית'),
('el', 'Greek', 'Ελληνικά'),
('cs', 'Czech', 'Čeština'),
('hu', 'Hungarian', 'Magyar'),
('ro', 'Romanian', 'Română'),
('sk', 'Slovak', 'Slovenčina'),
('hr', 'Croatian', 'Hrvatski'),
('sl', 'Slovenian', 'Slovenščina'),
('et', 'Estonian', 'Eesti'),
('lv', 'Latvian', 'Latviešu'),
('lt', 'Lithuanian', 'Lietuvių'),
('bg', 'Bulgarian', 'Български'),
('mk', 'Macedonian', 'Македонски'),
('sr', 'Serbian', 'Српски'),
('uk', 'Ukrainian', 'Українська'),
('be', 'Belarusian', 'Беларуская'),
('ka', 'Georgian', 'ქართული'),
('hy', 'Armenian', 'Հայերեն'),
('az', 'Azerbaijani', 'Azərbaycan'),
('kk', 'Kazakh', 'Қазақ'),
('ky', 'Kyrgyz', 'Кыргызча'),
('uz', 'Uzbek', 'Oʻzbekcha'),
('tg', 'Tajik', 'Тоҷикӣ'),
('fa', 'Persian', 'فارسی'),
('ur', 'Urdu', 'اردو'),
('bn', 'Bengali', 'বাংলা'),
('ta', 'Tamil', 'தமிழ்'),
('te', 'Telugu', 'తెలుగు'),
('kn', 'Kannada', 'ಕನ್ನಡ'),
('ml', 'Malayalam', 'മലയാളം'),
('gu', 'Gujarati', 'ગુજરાતી'),
('pa', 'Punjabi', 'ਪੰਜਾਬੀ'),
('mr', 'Marathi', 'मराठी'),
('ne', 'Nepali', 'नेपाली'),
('si', 'Sinhala', 'සිංහල'),
('my', 'Burmese', 'မြန်မာ'),
('km', 'Khmer', 'ខ្មែរ'),
('lo', 'Lao', 'ລາວ'),
('mn', 'Mongolian', 'Монгол'),
('bo', 'Tibetan', 'བོད་ཡིག'),
('am', 'Amharic', 'አማርኛ'),
('sw', 'Swahili', 'Kiswahili'),
('zu', 'Zulu', 'isiZulu'),
('af', 'Afrikaans', 'Afrikaans'),
('is', 'Icelandic', 'Íslenska'),
('mt', 'Maltese', 'Malti'),
('cy', 'Welsh', 'Cymraeg'),
('ga', 'Irish', 'Gaeilge'),
('eu', 'Basque', 'Euskara'),
('ca', 'Catalan', 'Català'),
('gl', 'Galician', 'Galego'),
('br', 'Breton', 'Brezhoneg'),
('fy', 'Frisian', 'Frysk'),
('lb', 'Luxembourgish', 'Lëtzebuergesch'),
('rm', 'Romansh', 'Rumantsch'),
('sq', 'Albanian', 'Shqip'),
('bs', 'Bosnian', 'Bosanski'),
('me', 'Montenegrin', 'Crnogorski');

-- 4. 驗證插入結果
SELECT COUNT(*) as total_languages FROM `languages`;

-- 5. 查看前10筆資料作為範例
SELECT * FROM `languages` LIMIT 10;

-- 注意事項：
-- - created_at 和 updated_at 欄位會自動設置為 CURRENT_TIMESTAMP
-- - id 欄位會自動遞增
-- - 總共插入 75 種語言
-- - 所有語言代碼都是 ISO 639-1 標準 