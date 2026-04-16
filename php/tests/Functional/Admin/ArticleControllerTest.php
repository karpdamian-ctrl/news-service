<?php

declare(strict_types=1);

namespace App\Tests\Functional\Admin;

use App\Api\NewsApiClient;
use App\Entity\User;
use App\Tests\Functional\DatabaseWebTestCase;
use Symfony\Component\HttpClient\MockHttpClient;
use Symfony\Component\HttpClient\Response\MockResponse;

final class ArticleControllerTest extends DatabaseWebTestCase
{
    public function testCreateFormShowsCategoryTagAndMediaChoicesFromApi(): void
    {
        $client = static::createClient();
        $client->disableReboot();
        $admin = $this->createUser('admin@news.local', [User::ROLE_ADMIN], 'Adam', 'Admin');
        $client->loginUser($admin);

        $this->setMockedNewsApiClient();

        $client->request('GET', '/admin/articles/new');

        self::assertResponseIsSuccessful();
        self::assertSelectorTextContains('select[name="featured_image_id"]', 'hero.jpg');
        self::assertSelectorTextContains('select[name="category_ids[]"]', 'Technology');
        self::assertSelectorTextContains('select[name="category_ids[]"]', 'Politics');
        self::assertSelectorTextContains('select[name="tag_ids[]"]', 'DevOps');
        self::assertSelectorTextContains('select[name="tag_ids[]"]', 'AI');
    }

    public function testEditFormShowsCategoryTagAndMediaChoicesFromApi(): void
    {
        $client = static::createClient();
        $client->disableReboot();
        $admin = $this->createUser('admin@news.local', [User::ROLE_ADMIN], 'Adam', 'Admin');
        $client->loginUser($admin);

        $this->setMockedNewsApiClient();

        $client->request('GET', '/admin/articles/123/edit');

        self::assertResponseIsSuccessful();
        self::assertSelectorTextContains('select[name="featured_image_id"]', 'hero.jpg');
        self::assertSelectorTextContains('select[name="category_ids[]"]', 'Technology');
        self::assertSelectorTextContains('select[name="category_ids[]"]', 'Politics');
        self::assertSelectorTextContains('select[name="tag_ids[]"]', 'DevOps');
        self::assertSelectorTextContains('select[name="tag_ids[]"]', 'AI');
        self::assertSelectorExists('select[name="featured_image_id"] option[value="7"][selected]');
        self::assertSelectorExists('select[name="category_ids[]"] option[value="10"][selected]');
        self::assertSelectorExists('select[name="tag_ids[]"] option[value="20"][selected]');
    }

    public function testEditSendsSelectedRelationsAndChangedBy(): void
    {
        $client = static::createClient();
        $client->disableReboot();
        $admin = $this->createUser('admin@news.local', [User::ROLE_ADMIN], 'Adam', 'Admin');
        $client->loginUser($admin);

        $this->setMockedNewsApiClient();

        $client->request('POST', '/admin/articles/123/edit', [
            'title' => 'Updated title',
            'slug' => 'updated-title',
            'description' => 'Updated description',
            'content' => 'Updated article content long enough for validation in API.',
            'status' => 'review',
            'author' => 'Editorial Team',
            'featured_image_id' => '7',
            'category_ids' => ['10', '11'],
            'tag_ids' => ['21'],
            'view_count' => '101',
            'is_breaking' => '1',
        ]);

        self::assertResponseRedirects('/admin/articles');
    }

    public function testIndexSearchUsesQueryAgainstApiResults(): void
    {
        $client = static::createClient();
        $client->disableReboot();
        $admin = $this->createUser('admin-search@news.local', [User::ROLE_ADMIN], 'Adam', 'Admin');
        $client->loginUser($admin);

        $this->setMockedNewsApiClient();
        $client->request('GET', '/admin/articles?q=AI');

        self::assertResponseIsSuccessful();
        self::assertSelectorTextContains('table tbody', 'AI Weekly');
        self::assertSelectorTextNotContains('table tbody', 'Sports Bulletin');
    }

    /**
     * @param list<string> $roles
     */
    private function createUser(string $email, array $roles, string $firstName, string $lastName): User
    {
        $user = (new User())
            ->setEmail($email)
            ->setFirstName($firstName)
            ->setLastName($lastName)
            ->setDisplayName(trim(sprintf('%s %s', $firstName, $lastName)))
            ->setRoles($roles)
            ->setIsActive(true)
            ->setCreatedAt(new \DateTimeImmutable())
            ->setUpdatedAt(new \DateTimeImmutable());

        $user->setPassword((string) password_hash('secret123', PASSWORD_BCRYPT));

        self::entityManager()->persist($user);
        self::entityManager()->flush();

        return $user;
    }

    private function setMockedNewsApiClient(): void
    {
        $httpClient = new MockHttpClient(function (string $method, string $url): MockResponse {
            $path = (string) parse_url($url, PHP_URL_PATH);
            parse_str((string) parse_url($url, PHP_URL_QUERY), $query);

            if ($method === 'GET' && $path === '/api/v1/articles') {
                $q = isset($query['q']) && is_string($query['q']) ? $query['q'] : null;
                $rows = [
                    ['id' => 201, 'title' => 'AI Weekly', 'slug' => 'ai-weekly', 'status' => 'published', 'author' => 'Desk', 'published_at' => '2026-04-16T10:00:00Z'],
                    ['id' => 202, 'title' => 'Sports Bulletin', 'slug' => 'sports-bulletin', 'status' => 'draft', 'author' => 'Desk', 'published_at' => null],
                ];

                if ($q !== null && stripos($q, 'ai') !== false) {
                    $rows = [$rows[0]];
                }

                return $this->jsonResponse([
                    'data' => $rows,
                    'meta' => ['page' => 1, 'per_page' => 50, 'total_pages' => 1, 'total_count' => count($rows), 'sort' => 'id', 'order' => 'desc'],
                ]);
            }

            if ($method === 'GET' && $path === '/api/v1/media') {
                return $this->jsonResponse([
                    'data' => [
                        ['id' => 7, 'type' => 'image', 'path' => '/uploads/news/hero.jpg'],
                    ],
                    'meta' => ['page' => 1, 'total_pages' => 1, 'total_count' => 1],
                ]);
            }

            if ($method === 'GET' && $path === '/api/v1/categories') {
                return $this->jsonResponse([
                    'data' => [
                        ['id' => 10, 'name' => 'Technology'],
                        ['id' => 11, 'name' => 'Politics'],
                    ],
                    'meta' => ['page' => 1, 'total_pages' => 1, 'total_count' => 2],
                ]);
            }

            if ($method === 'GET' && $path === '/api/v1/tags') {
                return $this->jsonResponse([
                    'data' => [
                        ['id' => 20, 'name' => 'DevOps'],
                        ['id' => 21, 'name' => 'AI'],
                    ],
                    'meta' => ['page' => 1, 'total_pages' => 1, 'total_count' => 2],
                ]);
            }

            if ($method === 'GET' && $path === '/api/v1/articles/123') {
                return $this->jsonResponse([
                    'data' => [
                        'id' => 123,
                        'title' => 'Sample Article',
                        'slug' => 'sample-article',
                        'description' => 'Sample description',
                        'content' => 'Sample article content long enough for editor form.',
                        'status' => 'draft',
                        'author' => 'Editorial Team',
                        'featured_image_id' => 7,
                        'category_ids' => [10],
                        'tag_ids' => [20],
                        'view_count' => 100,
                        'is_breaking' => false,
                    ],
                ]);
            }

            if (($method === 'PUT' || $method === 'PATCH') && str_starts_with($path, '/api/v1/articles/123')) {
                return $this->jsonResponse(['data' => ['id' => 123]], 200);
            }

            return $this->jsonResponse(['error' => 'unexpected_api_call', 'method' => $method, 'path' => $path], 500);
        });

        $client = new NewsApiClient($httpClient, 'http://phoenix:4000/api/v1', 'test-token');
        static::getContainer()->set(NewsApiClient::class, $client);
    }

    /**
     * @param array<string, mixed> $data
     */
    private function jsonResponse(array $data, int $status = 200): MockResponse
    {
        return new MockResponse((string) json_encode($data, JSON_THROW_ON_ERROR), [
            'http_code' => $status,
            'response_headers' => ['content-type' => 'application/json'],
        ]);
    }
}
