<?php
// backend/utils/UserActiveLogEvent.php
declare(strict_types=1);

namespace App\UserActiveLog;

enum UserActiveLogEvent: string
{
    case LOGIN             = 'login';
    case LOGOUT            = 'logout';
    case UPDATE_PROFILE    = 'update_profile';
    case UPDATE_PASSWORD   = 'update_password';
    case UPDATE_PHONE      = 'update_phone';
    case UPDATE_ADDRESS    = 'update_address';
    case UPDATE_BIRTHDAY   = 'update_birthday';
    case CHARGE_REQUEST    = 'charge_request'; // 充值審核請求
    case TASK_PAYMENT       = 'task_payment';       // 付任務款（paid for task）
    case TASK_PAYOUT        = 'task_payout';        // 任務收入（task payout）
    case REFERRAL_REWARD    = 'referral_reward_income';    // 推薦獎勵收入（referral reward income）
    case ADJUSTMENT_CREDIT  = 'adjustment_credit';  // 系統加點（adjustment credit）
    case ADJUSTMENT_DEBIT   = 'adjustment_debit';   // 系統扣點
    case WITHDRAWAL_FEE     = 'withdrawal_fee';     // 提款手續費（withdrawal fee）
    case POINTS_PURCHASE    = 'points_purchase';    // 點數購買（points purchase）
}

enum UserActiveLogRole: string
{
    case ADMIN = 'admin';
    case USER = 'user';
    case AGENT = 'agent';
    case SUPER_ADMIN = 'super_admin';
    case SUPER_AGENT = 'super_agent';
    case SUPER_USER = 'super_user';
}