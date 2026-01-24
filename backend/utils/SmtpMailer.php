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

        $transport = $encryption === 'ssl' ? "ssl://{$host}" : $host;
        $socket = fsockopen($transport, $port, $errno, $errstr, 15);
        if (!$socket) {
            self::log('SMTP connect failed', ['error' => $errstr, 'errno' => $errno]);
            return ['success' => false, 'error' => "SMTP connect failed: {$errstr} ({$errno})"];
        }

        try {
            self::expect($socket, [220]);
            self::command($socket, 'EHLO ' . self::getHostname());
            self::expect($socket, [250]);

            if ($encryption === 'tls') {
                self::command($socket, 'STARTTLS');
                self::expect($socket, [220]);
                if (!stream_socket_enable_crypto($socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
                    throw new Exception('STARTTLS failed');
                }
                self::command($socket, 'EHLO ' . self::getHostname());
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
            fclose($socket);
            self::log('SMTP send failed', ['error' => $e->getMessage()]);
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    private static function getHostname(): string
    {
        $host = gethostname();
        return $host ? $host : 'localhost';
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
