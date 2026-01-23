<!DOCTYPE html>
<html lang="zh-TW">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Terms of Use - Here4Help</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 860px;
            margin: 0 auto;
            padding: 24px;
            line-height: 1.7;
            color: #1f2937;
            background: #ffffff;
        }
        h1 {
            font-size: 28px;
            margin-bottom: 6px;
        }
        .meta {
            color: #6b7280;
            font-size: 14px;
            margin-bottom: 16px;
        }
        .error {
            padding: 12px 16px;
            border: 1px solid #fecaca;
            background: #fef2f2;
            color: #b91c1c;
            border-radius: 8px;
        }
    </style>
</head>
<body>
    <h1 id="terms-title">Terms of Use</h1>
    <div class="meta" id="terms-meta">Loading...</div>
    <div id="terms-content"></div>

    <script>
        (function () {
            const titleEl = document.getElementById('terms-title');
            const metaEl = document.getElementById('terms-meta');
            const contentEl = document.getElementById('terms-content');

            const formatDate = (value) => {
                if (!value) return '';
                const date = new Date(value);
                if (Number.isNaN(date.getTime())) return '';
                return date.toLocaleString();
            };

            const showError = (message) => {
                metaEl.textContent = '';
                contentEl.innerHTML = `<div class="error">${message}</div>`;
            };

            fetch('/backend/api/content/app_terms_active.php', { method: 'GET' })
                .then((response) => response.json())
                .then((payload) => {
                    if (!payload || payload.success !== true) {
                        throw new Error(payload?.message || 'Failed to load terms');
                    }
                    const terms = payload?.data?.terms;
                    if (!terms) {
                        showError('No active terms found.');
                        return;
                    }
                    titleEl.textContent = terms.title || 'Terms of Use';
                    const updatedAt = formatDate(terms.updated_at);
                    const versionText = terms.version ? `Version ${terms.version}` : '';
                    metaEl.textContent = [versionText, updatedAt ? `Updated ${updatedAt}` : '']
                        .filter(Boolean)
                        .join(' · ');
                    contentEl.innerHTML = terms.content || '';
                })
                .catch((error) => {
                    showError(error?.message || 'Failed to load terms.');
                });
        })();
    </script>
</body>
</html>
