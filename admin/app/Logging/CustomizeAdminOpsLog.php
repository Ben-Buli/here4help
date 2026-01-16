<?php

namespace App\Logging;

use Monolog\Handler\RotatingFileHandler;

class CustomizeAdminOpsLog
{
    /**
     * Customize the admin_ops log filename format.
     *
     * @param  array  $config
     * @return void
     */
    public function __invoke(array $config): void
    {
        foreach ($config['handlers'] ?? [] as $handler) {
            if ($handler instanceof RotatingFileHandler) {
                $handler->setFilenameFormat('{filename}_{date}', 'Y_m_d');
            }
        }
    }
}
