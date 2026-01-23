<?php

namespace App\Mail;

use Carbon\Carbon;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Queue\SerializesModels;

class PasswordResetMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public string $userName,
        public string $resetLink,
        public Carbon $expiresAt
    ) {
    }

    public function build()
    {
        return $this->subject('Password Reset Request - Here4Help')
            ->view('emails.password_reset')
            ->with([
                'userName' => $this->userName,
                'resetLink' => $this->resetLink,
                'expiresAt' => $this->expiresAt,
            ]);
    }
}
