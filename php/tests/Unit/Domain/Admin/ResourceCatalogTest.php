<?php

declare(strict_types=1);

namespace App\Tests\Unit\Domain\Admin;

use App\Domain\Admin\ResourceCatalog;
use App\Domain\Admin\ResourceCatalogProvider;
use App\Entity\User;
use PHPUnit\Framework\TestCase;

final class ResourceCatalogTest extends TestCase
{
    public function testMenuHidesUsersForRedactor(): void
    {
        $catalog = new ResourceCatalog(new InMemoryResourceCatalogProvider(
            resources: [
                'articles' => ['label' => 'Articles'],
                'users' => ['label' => 'Users'],
            ],
            routes: [
                'articles' => ['index' => 'admin_articles_index', 'new' => null, 'edit' => null, 'delete' => null, 'show' => null],
                'users' => ['index' => 'admin_users_index', 'new' => null, 'edit' => null, 'delete' => null, 'show' => null],
            ],
        ));

        $redactor = (new User())->setRoles([User::ROLE_REDACTOR]);
        $items = $catalog->menuItems($redactor);

        self::assertCount(1, $items);
        self::assertSame('articles', $items[0]['key']);
    }

    public function testMenuShowsUsersForAdmin(): void
    {
        $catalog = new ResourceCatalog(new InMemoryResourceCatalogProvider(
            resources: [
                'articles' => ['label' => 'Articles'],
                'users' => ['label' => 'Users'],
            ],
            routes: [
                'articles' => ['index' => 'admin_articles_index', 'new' => null, 'edit' => null, 'delete' => null, 'show' => null],
                'users' => ['index' => 'admin_users_index', 'new' => null, 'edit' => null, 'delete' => null, 'show' => null],
            ],
        ));

        $admin = (new User())->setRoles([User::ROLE_ADMIN]);
        $items = $catalog->menuItems($admin);

        self::assertCount(2, $items);
        self::assertSame('users', $items[1]['key']);
        self::assertSame('admin_users_index', $items[1]['route']);
    }

    public function testRoutesThrowsForUnknownResource(): void
    {
        $catalog = new ResourceCatalog(new InMemoryResourceCatalogProvider(
            resources: ['articles' => ['label' => 'Articles']],
            routes: ['articles' => ['index' => 'admin_articles_index', 'new' => null, 'edit' => null, 'delete' => null, 'show' => null]],
        ));

        $this->expectException(\InvalidArgumentException::class);
        $this->expectExceptionMessage('Unknown resource key "users"');
        $catalog->routes('users');
    }
}

final class InMemoryResourceCatalogProvider implements ResourceCatalogProvider
{
    /**
     * @param array<string, array<string, mixed>> $resources
     * @param array<string, array{index:string,new:?string,edit:?string,delete:?string,show:?string}> $routes
     */
    public function __construct(
        private readonly array $resources,
        private readonly array $routes,
    ) {
    }

    public function resources(): array
    {
        return $this->resources;
    }

    public function routes(): array
    {
        return $this->routes;
    }
}

