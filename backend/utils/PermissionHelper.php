<?php

class PermissionHelper {
    public const DELETED_PERMISSIONS = [-2, -4];
    public const SUSPENDED_PERMISSIONS = [-1, -3];
    public const ADMIN_SUSPENDED_PERMISSIONS = [-1];
    public const SELF_SUSPENDED_PERMISSIONS = [-3];

    public static function isDeleted($permission): bool {
        return in_array((int)$permission, self::DELETED_PERMISSIONS, true);
    }

    public static function isSuspended($permission): bool {
        return in_array((int)$permission, self::SUSPENDED_PERMISSIONS, true);
    }

    public static function isAdminSuspended($permission): bool {
        return in_array((int)$permission, self::ADMIN_SUSPENDED_PERMISSIONS, true);
    }

    public static function isSelfSuspended($permission): bool {
        return in_array((int)$permission, self::SELF_SUSPENDED_PERMISSIONS, true);
    }

    public static function isVerified($permission): bool {
        return (int)$permission >= 1;
    }
}
