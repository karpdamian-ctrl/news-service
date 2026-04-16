<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20260416203000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Drop all legacy PHP news tables because admin now uses Elixir API as source of truth';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('DROP TABLE IF EXISTS article_revisions CASCADE');
        $this->addSql('DROP TABLE IF EXISTS article_tags CASCADE');
        $this->addSql('DROP TABLE IF EXISTS article_categories CASCADE');
        $this->addSql('DROP TABLE IF EXISTS articles CASCADE');
        $this->addSql('DROP TABLE IF EXISTS media CASCADE');
        $this->addSql('DROP TABLE IF EXISTS tags CASCADE');
        $this->addSql('DROP TABLE IF EXISTS categories CASCADE');
        $this->addSql('DROP TABLE IF EXISTS users CASCADE');
        $this->addSql('DROP TABLE IF EXISTS article CASCADE');
    }

    public function down(Schema $schema): void
    {
        // Intentionally left empty. Legacy tables should not be restored automatically.
    }
}
