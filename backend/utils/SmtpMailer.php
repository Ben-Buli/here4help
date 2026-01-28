<?php
class SmtpMailer
{
    public static function send(string $to, string $subject, string $htmlBody, string $fromEmail, string $fromName = '', string $replyTo = ''): array
    {
        $host = EnvLoader::get('MAIL_HOST', '');
        $port = (int) EnvLoader::get('MAIL_PORT', '25');
        $username = EnvLoader::get('MAIL_USERNAME', '');
        $password = EnvLoader::get('MAIL_PASSWORD', '');
        $encryption = strtolower((string) EnvLoader::get('MAIL_ENCRYPTION', ''));
        $fallbackIp = EnvLoader::get('MAIL_HOST_IP', ''); // 備選 IP 地址

        self::log('Send requested', [
            'to' => $to,
            'subject' => $subject,
            'host' => $host,
            'port' => $port,
            'encryption' => $encryption,
            'from' => $fromEmail,
            'reply_to_set' => $replyTo !== '',
        ]);

        if ($host === '' || $username === '' || $password === '') {
            self::log('SMTP not configured');
            return ['success' => false, 'error' => 'SMTP not configured'];
        }

        // 嘗試連接，如果失敗則使用 IP 地址
        $socket = self::connect($host, $port, $encryption, $fallbackIp);
        if (!$socket) {
            return ['success' => false, 'error' => 'Failed to connect to SMTP server'];
        }

        try {
            // 提取主機名用於 EHLO（從 email 或 host 提取域名）
            $ehloHost = self::getEhloHostname($host);
            
            self::expect($socket, [220]);
            self::command($socket, 'EHLO ' . $ehloHost);
            self::expect($socket, [250]);

            if ($encryption === 'tls') {
                self::command($socket, 'STARTTLS');
                self::expect($socket, [220]);
                if (!stream_socket_enable_crypto($socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
                    throw new Exception('STARTTLS failed');
                }
                self::command($socket, 'EHLO ' . $ehloHost);
                self::expect($socket, [250]);
            }

            self::command($socket, 'AUTH LOGIN');
            self::expect($socket, [334]);
            self::command($socket, base64_encode($username));
            self::expect($socket, [334]);
            self::command($socket, base64_encode($password));
            self::expect($socket, [235]);

            self::command($socket, 'MAIL FROM:<' . $fromEmail . '>');
            self::expect($socket, [250]);
            self::command($socket, 'RCPT TO:<' . $to . '>');
            self::expect($socket, [250, 251]);
            self::command($socket, 'DATA');
            self::expect($socket, [354]);

            $headers = [];
            $headers[] = 'MIME-Version: 1.0';
            $headers[] = 'Content-Type: text/html; charset=UTF-8';
            $headers[] = 'From: ' . self::formatFrom($fromEmail, $fromName);
            if ($replyTo !== '') {
                $headers[] = 'Reply-To: ' . $replyTo;
            }
            $headers[] = 'To: ' . $to;
            $headers[] = 'Subject: ' . $subject;

            $data = implode("\r\n", $headers) . "\r\n\r\n" . $htmlBody;
            $data = str_replace("\r\n.", "\r\n..", $data);
            self::command($socket, $data . "\r\n.");
            self::expect($socket, [250]);
            self::command($socket, 'QUIT');
            fclose($socket);
            self::log('SMTP send success', ['to' => $to]);
            return ['success' => true, 'error' => null];
        } catch (Exception $e) {
            if (isset($socket) && is_resource($socket)) {
                fclose($socket);
            }
            self::log('SMTP send failed', ['error' => $e->getMessage()]);
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    /**
     * 建立 SMTP 連接，支援 SSL 和 IP 備選
     */
    private static function connect(string $host, int $port, string $encryption, string $fallbackIp = '')
    {
        $timeout = 30;
        $context = null;
        
        if ($encryption === 'ssl') {
            $context = stream_context_create([
                'ssl' => [
                    'verify_peer' => false,
                    'verify_peer_name' => false,
                    'allow_self_signed' => true,
                ]
            ]);
        }

        // 嘗試使用域名連接
        $address = $encryption === 'ssl' ? "ssl://{$host}" : $host;
        $socket = @stream_socket_client(
            "{$address}:{$port}",
            $errno,
            $errstr,
            $timeout,
            STREAM_CLIENT_CONNECT,
            $context
        );

        if ($socket) {
            self::log('SMTP connected via hostname', ['host' => $host]);
            return $socket;
        }

        // 如果域名連接失敗且有備選 IP，嘗試使用 IP
        if ($fallbackIp && $fallbackIp !== $host) {
            self::log('Hostname connection failed, trying IP', [
                'host' => $host,
                'ip' => $fallbackIp,
                'error' => $errstr,
                'errno' => $errno
            ]);
            
            $address = $encryption === 'ssl' ? "ssl://{$fallbackIp}" : $fallbackIp;
            $socket = @stream_socket_client(
                "{$address}:{$port}",
                $errno,
                $errstr,
                $timeout,
                STREAM_CLIENT_CONNECT,
                $context
            );

            if ($socket) {
                self::log('SMTP connected via IP', ['ip' => $fallbackIp]);
                return $socket;
            }
        }

        self::log('SMTP connect failed', [
            'host' => $host,
            'ip' => $fallbackIp,
            'error' => $errstr,
            'errno' => $errno
        ]);
        return null;
    }

    /**
     * 獲取用於 EHLO 的主機名（從 host 提取域名）
     */
    private static function getEhloHostname(string $host): string
    {
        // 如果是 IP 地址，使用原始 host 配置
        if (filter_var($host, FILTER_VALIDATE_IP)) {
            // 嘗試從 MAIL_USERNAME 提取域名
            $username = EnvLoader::get('MAIL_USERNAME', '');
            if ($username && strpos($username, '@') !== false) {
                $domain = substr($username, strpos($username, '@') + 1);
                return $domain;
            }
            return $host;
        }
        
        // 移除協議前綴（如果有）
        $host = preg_replace('/^https?:\/\//', '', $host);
        // 移除端口（如果有）
        $host = preg_replace('/:\d+$/', '', $host);
        
        return $host;
    }

    private static function formatFrom(string $email, string $name): string
    {
        if ($name === '') {
            return $email;
        }
        return sprintf('"%s" <%s>', addslashes($name), $email);
    }

    private static function command($socket, string $command): void
    {
        fwrite($socket, $command . "\r\n");
    }

    private static function expect($socket, array $codes): void
    {
        $response = '';
        while ($line = fgets($socket, 512)) {
            $response .= $line;
            if (preg_match('/^\d{3} /', $line)) {
                break;
            }
        }
        $code = (int) substr($response, 0, 3);
        if (!in_array($code, $codes, true)) {
            throw new Exception("SMTP error: {$response}");
        }
    }

    private static function log(string $message, array $context = []): void
    {
        if (!function_exists('error_log')) {
            return;
        }
        $safeContext = [];
        foreach ($context as $key => $value) {
            if ($key === 'htmlBody' || $key === 'password') {
                continue;
            }
            $safeContext[$key] = $value;
        }
        $suffix = $safeContext ? ' ' . json_encode($safeContext, JSON_UNESCAPED_UNICODE) : '';
        error_log('[SmtpMailer] ' . $message . $suffix);
    }
}