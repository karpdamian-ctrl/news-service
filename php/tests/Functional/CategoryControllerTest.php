<?php

declare(strict_types=1);

namespace App\Tests\Functional;

use App\Api\NewsApiClient;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpClient\MockHttpClient;
use Symfony\Component\HttpClient\Response\MockResponse;

final class CategoryControllerTest extends WebTestCase
{
    public function testCategoryPageRendersArticlesForSlugAndHeaderLinks(): void
    {
        $client = static::createClient();
        $client->disableReboot();

        $this->setMockedNewsApiClient();

        $client->request('GET', '/category/technology');

        self::assertResponseIsSuccessful();
        self::assertSelectorTextContains('body', 'Kategoria: Technology');
        self::assertSelectorTextContains('body', 'Tech Story');
        self::assertSelectorTextContains('body', 'Horyzont News');
        self::assertSelectorExists('a.top-nav-link[href="/category/technology"]');
    }

    private function setMockedNewsApiClient(): void
    {
        $httpClient = new MockHttpClient(function (string $method, string $url): MockResponse {
            $path = (string) parse_url($url, PHP_URL_PATH);
            parse_str((string) parse_url($url, PHP_URL_QUERY), $query);

            if ($method === 'GET' && $path === '/api/v1/categories/popular') {
                return $this->jsonResponse([
                    'data' => [
                        ['id' => 1, 'name' => 'Technology', 'slug' => 'technology', 'count' => 25],
                        ['id' => 2, 'name' => 'Economy', 'slug' => 'economy', 'count' => 20],
                    ],
                ]);
            }

            if ($method === 'GET' && $path === '/api/v1/categories') {
                $slug = is_array($query['filter'] ?? null) ? ($query['filter']['slug'] ?? null) : null;

                if ($slug === 'technology') {
                    return $this->jsonResponse([
                        'data' => [
                            ['id' => 1, 'name' => 'Technology', 'slug' => 'technology'],
                        ],
                    ]);
                }

                return $this->jsonResponse([
                    'data' => [
                        ['id' => 1, 'name' => 'Technology', 'slug' => 'technology'],
                        ['id' => 2, 'name' => 'Economy', 'slug' => 'economy'],
                    ],
                ]);
            }

            if ($method === 'GET' && $path === '/api/v1/media/search') {
                return $this->jsonResponse([
                    'data' => [
                        ['id' => 9, 'path' => '/uploads/news/tech.jpg', 'alt_text' => 'Tech'],
                    ],
                ]);
            }

            if ($method === 'GET' && $path === '/api/v1/articles/search') {
                return $this->jsonResponse([
                    'data' => [
                        [
                            'id' => 77,
                            'title' => 'Tech Story',
                            'slug' => 'tech-story',
                            'description' => 'Story from technology category.',
                            'author' => 'Desk',
                            'published_at' => '2026-04-16T12:00:00Z',
                            'view_count' => 120,
                            'featured_image_id' => 9,
                            'tag_names' => ['AI'],
                            'tag_refs' => ['1|ai|AI'],
                            'category_names' => ['Technology'],
                            'category_refs' => ['1|technology|Technology'],
                        ],
                    ],
                ]);
            }

            return $this->jsonResponse(['error' => 'unexpected_api_call', 'path' => $path], 500);
        });

        $newsApi = new NewsApiClient($httpClient, 'http://phoenix:4000/api/v1', 'test-token');
        static::getContainer()->set(NewsApiClient::class, $newsApi);
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
