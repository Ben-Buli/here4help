<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Password Reset Request</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6;">
    <h2>Password Reset Request</h2>
    <p>Hello {{ $userName }},</p>
    <p>We received a request to reset your Here4Help account password.</p>
    <p>
        <a href="{{ $resetLink }}"
           style="background-color:#007bff;color:#ffffff;padding:10px 20px;text-decoration:none;border-radius:4px;">
            Reset Password
        </a>
    </p>
    <p>If the button above does not work, copy and paste this link into your browser:</p>
    <p>{{ $resetLink }}</p>
    <p>This link will expire at {{ $expiresAt->toDateTimeString() }}.</p>
    <p>If you did not request this, please ignore this email.</p>
    <p>Best regards,<br>Here4Help Team</p>
</body>
</html>
