<?php

declare(strict_types=1);

namespace App\Tests\Unit\Infrastructure\Admin;

use App\Infrastructure\Admin\YamlResourceCatalogProvider;
use PHPUnit\Framework\TestCase;

final class YamlResourceCatalogProviderTest extends TestCase
{
    /**
     * @var list<string>
     */
    private array $tempFiles = [];

    public function testThrowsWhenResourcesAndRoutesKeysDoNotMatch(): void
    {
        $resourcesPath = $this->createYamlFile(<<<'YAML'
resources:
  articles:
    label: Articles
    endpoint: articles
    list_fields: [id]
YAML);
        $routesPath = $this->createYamlFile(<<<'YAML'
routes:
  users:
    index: admin_users_index
    new: null
    edit: null
    delete: null
    show: null
YAML);

        $provider = new YamlResourceCatalogProvider($resourcesPath, $routesPath);

        $this->expectException(\RuntimeException::class);
        $this->expectExceptionMessage('Resource keys and route keys do not match');
        $provider->resources();
    }

    public function testThrowsWhenRouteConfigIsMissingRequiredKey(): void
    {
        $resourcesPath = $this->createYamlFile(<<<'YAML'
resources:
  articles:
    label: Articles
    endpoint: articles
    list_fields: [id]
YAML);
        $routesPath = $this->createYamlFile(<<<'YAML'
routes:
  articles:
    index: admin_articles_index
    new: null
    edit: null
    delete: null
YAML);

        $provider = new YamlResourceCatalogProvider($resourcesPath, $routesPath);

        $this->expectException(\RuntimeException::class);
        $this->expectExceptionMessage('must define "show"');
        $provider->routes();
    }

    public function testLoadsValidConfigs(): void
    {
        $resourcesPath = $this->createYamlFile(<<<'YAML'
resources:
  articles:
    label: Articles
    endpoint: articles
    list_fields: [id, title]
    sortable_fields: [id, title]
YAML);
        $routesPath = $this->createYamlFile(<<<'YAML'
routes:
  articles:
    index: admin_articles_index
    new: admin_articles_new
    edit: admin_articles_edit
    delete: admin_articles_delete
    show: null
YAML);

        $provider = new YamlResourceCatalogProvider($resourcesPath, $routesPath);

        $resources = $provider->resources();
        $routes = $provider->routes();

        self::assertSame('Articles', $resources['articles']['label']);
        self::assertSame('admin_articles_index', $routes['articles']['index']);
    }

    private function createYamlFile(string $content): string
    {
        $path = tempnam(sys_get_temp_dir(), 'news_yaml_');
        self::assertIsString($path);

        $written = file_put_contents($path, $content);
        self::assertNotFalse($written);

        $this->tempFiles[] = $path;
        return $path;
    }

    protected function tearDown(): void
    {
        foreach ($this->tempFiles as $path) {
            if (file_exists($path)) {
                @unlink($path);
            }
        }

        $this->tempFiles = [];
        parent::tearDown();
    }
}
