<?php

use Symfony\Component\Dotenv\Dotenv;

require dirname(__DIR__).'/vendor/autoload.php';

$_SERVER['APP_ENV'] = $_ENV['APP_ENV'] ?? 'test';
$_SERVER['APP_DEBUG'] = $_ENV['APP_DEBUG'] ?? '1';
$_SERVER['KERNEL_CLASS'] = $_ENV['KERNEL_CLASS'] ?? 'App\\Kernel';

if (method_exists(Dotenv::class, 'bootEnv')) {
    (new Dotenv())->bootEnv(dirname(__DIR__).'/.env');
}

$_SERVER['APP_ENV'] = 'test';
$_ENV['APP_ENV'] = 'test';
$_SERVER['APP_DEBUG'] = '1';
$_ENV['APP_DEBUG'] = '1';
$_SERVER['KERNEL_CLASS'] = 'App\\Kernel';
$_ENV['KERNEL_CLASS'] = 'App\\Kernel';

if ($_SERVER['APP_DEBUG']) {
    umask(0000);
}
