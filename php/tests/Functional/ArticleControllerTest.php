<?php

declare(strict_types=1);

namespace App\Tests\Functional;

use App\Api\NewsApiClient;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpClient\MockHttpClient;
use Symfony\Component\HttpClient\Response\MockResponse;

final class ArticleControllerTest extends WebTestCase
{
    public function testArticlePageLoadsFromDatabaseEndpoint(): void
    {
        $client = static::createClient();
        $client->disableReboot();

        $this->setMockedNewsApiClient();

        $client->request('GET', '/article/test-article');

        self::assertResponseIsSuccessful();
        self::assertSelectorTextContains('h1', 'Test Article');
        self::assertSelectorTextContains('body', 'Treść testowego artykułu.');
        self::assertSelectorTextContains('body', '322 wyświetleń');
        self::assertSelectorExists('a.meta-chip[href="/category/technology"]');
        self::assertSelectorExists('a.meta-chip[href="/tag/ai"]');
    }

    private function setMockedNewsApiClient(): void
    {
        $httpClient = new MockHttpClient(function (string $method, string $url): MockResponse {
            $path = (string) parse_url($url, PHP_URL_PATH);
            parse_str((string) parse_url($url, PHP_URL_QUERY), $query);

            if ($method === 'GET' && $path === '/api/v1/categories/popular') {
                return $this->jsonResponse([
                    'data' => [
                        ['id' => 1, 'name' => 'Technology', 'slug' => 'technology', 'count' => 12],
                    ],
                ]);
            }

            if ($method === 'GET' && $path === '/api/v1/media/search') {
                return $this->jsonResponse([
                    'data' => [
                        ['id' => 9, 'path' => '/uploads/news/test.jpg', 'alt_text' => 'Test'],
                    ],
                ]);
            }

            if ($method === 'GET' && $path === '/api/v1/articles') {
                $filter = is_array($query['filter'] ?? null) ? $query['filter'] : [];
                if (($filter['slug'] ?? null) !== 'test-article') {
                    return $this->jsonResponse(['data' => []]);
                }

                return $this->jsonResponse([
                    'data' => [
                        [
                            'id' => 123,
                            'title' => 'Test Article',
                            'slug' => 'test-article',
                            'description' => 'Opis testowego artykułu.',
                            'content' => 'Treść testowego artykułu.',
                            'author' => 'Desk',
                            'published_at' => '2026-04-16T18:00:00Z',
                            'view_count' => 321,
                            'featured_image_id' => 9,
                            'category_ids' => [1],
                            'tag_ids' => [5],
                        ],
                    ],
                ]);
            }

            if ($method === 'GET' && $path === '/api/v1/articles/search') {
                return $this->jsonResponse([
                    'data' => [
                        [
                            'id' => 123,
                            'slug' => 'test-article',
                            'category_refs' => ['1|technology|Technology'],
                            'tag_refs' => ['5|ai|AI'],
                        ],
                    ],
                ]);
            }

            if ($method === 'POST' && $path === '/api/v1/articles/123/view') {
                return $this->jsonResponse([
                    'data' => [
                        'id' => 123,
                        'view_count' => 322,
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
