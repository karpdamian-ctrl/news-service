<?php

declare(strict_types=1);

namespace App\Tests\Functional;

use Doctrine\ORM\EntityManagerInterface;
use Doctrine\ORM\Tools\SchemaTool;
use Doctrine\Persistence\ManagerRegistry;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;

abstract class DatabaseWebTestCase extends WebTestCase
{
    private static ?EntityManagerInterface $entityManager = null;

    public static function setUpBeforeClass(): void
    {
        parent::setUpBeforeClass();
        self::ensureTestDatabaseExists();

        self::bootKernel();
        /** @var ManagerRegistry $registry */
        $registry = self::$kernel->getContainer()->get('doctrine');
        /** @var EntityManagerInterface $entityManager */
        $entityManager = $registry->getManager();
        self::$entityManager = $entityManager;

        $schemaTool = new SchemaTool($entityManager);
        $metadata = $entityManager->getMetadataFactory()->getAllMetadata();

        $schemaTool->dropDatabase();

        if ($metadata !== []) {
            $schemaTool->createSchema($metadata);
        }

        self::ensureKernelShutdown();
    }

    protected function setUp(): void
    {
        parent::setUp();
        self::truncateUsersTable();
    }

    protected function tearDown(): void
    {
        if (self::$entityManager !== null && self::$entityManager->isOpen()) {
            self::$entityManager->clear();
        }

        parent::tearDown();
    }

    protected static function entityManager(): EntityManagerInterface
    {
        if (self::$entityManager === null) {
            self::bootKernel();
            /** @var ManagerRegistry $registry */
            $registry = self::$kernel->getContainer()->get('doctrine');
            /** @var EntityManagerInterface $entityManager */
            $entityManager = $registry->getManager();
            self::$entityManager = $entityManager;
            self::ensureKernelShutdown();
        }

        return self::$entityManager;
    }

    private static function truncateUsersTable(): void
    {
        $connection = self::entityManager()->getConnection();

        try {
            $connection->executeStatement('TRUNCATE TABLE users RESTART IDENTITY CASCADE');
        } catch (\Throwable) {
            $connection->executeStatement('DELETE FROM users');
        }
    }

    private static function ensureTestDatabaseExists(): void
    {
        $databaseUrl = (string) ($_SERVER['DATABASE_URL'] ?? $_ENV['DATABASE_URL'] ?? '');
        if ($databaseUrl === '') {
            return;
        }

        $parts = parse_url($databaseUrl);
        if (!is_array($parts)) {
            return;
        }

        $host = isset($parts['host']) ? (string) $parts['host'] : '127.0.0.1';
        $port = isset($parts['port']) ? (int) $parts['port'] : 5432;
        $user = isset($parts['user']) ? (string) $parts['user'] : '';
        $pass = isset($parts['pass']) ? (string) $parts['pass'] : '';
        $dbName = isset($parts['path']) ? ltrim((string) $parts['path'], '/') : '';

        if ($dbName === '') {
            return;
        }

        $dsn = sprintf('pgsql:host=%s;port=%d;dbname=postgres', $host, $port);
        $pdo = new \PDO($dsn, $user, $pass, [\PDO::ATTR_ERRMODE => \PDO::ERRMODE_EXCEPTION]);

        $stmt = $pdo->prepare('SELECT 1 FROM pg_database WHERE datname = :dbname');
        $stmt->execute(['dbname' => $dbName]);
        $exists = $stmt->fetchColumn();

        if ($exists !== false) {
            return;
        }

        $quotedDbName = str_replace('"', '""', $dbName);
        $pdo->exec(sprintf('CREATE DATABASE "%s"', $quotedDbName));
    }
}
