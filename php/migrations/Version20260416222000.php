<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20260416222000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Add first_name and last_name columns to users table';
    }

    public function up(Schema $schema): void
    {
        $this->addSql("ALTER TABLE users ADD first_name VARCHAR(80) DEFAULT '' NOT NULL");
        $this->addSql("ALTER TABLE users ADD last_name VARCHAR(120) DEFAULT '' NOT NULL");

        $this->addSql("
            UPDATE users
            SET first_name = CASE
                WHEN POSITION(' ' IN TRIM(display_name)) > 0 THEN SPLIT_PART(TRIM(display_name), ' ', 1)
                WHEN TRIM(display_name) = '' THEN 'Unknown'
                ELSE TRIM(display_name)
            END
        ");

        $this->addSql("
            UPDATE users
            SET last_name = CASE
                WHEN POSITION(' ' IN TRIM(display_name)) > 0 THEN SUBSTRING(TRIM(display_name) FROM POSITION(' ' IN TRIM(display_name)) + 1)
                WHEN TRIM(display_name) = '' THEN 'User'
                ELSE 'User'
            END
        ");
    }

    public function down(Schema $schema): void
    {
        $this->addSql('ALTER TABLE users DROP first_name');
        $this->addSql('ALTER TABLE users DROP last_name');
    }
}
