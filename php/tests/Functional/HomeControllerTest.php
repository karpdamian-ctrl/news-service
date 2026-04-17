<?php

declare(strict_types=1);

namespace App\Tests\Functional;

use App\Api\NewsApiClient;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpClient\MockHttpClient;
use Symfony\Component\HttpClient\Response\MockResponse;

final class HomeControllerTest extends WebTestCase
{
    public function testHomepageRendersDataFetchedThroughPhpService(): void
    {
        $client = static::createClient();
        $client->disableReboot();

        $this->setMockedNewsApiClient();

        $client->request('GET', '/');

        self::assertResponseIsSuccessful();
        self::assertSelectorTextContains('body', 'Horyzont News');
        self::assertSelectorTextContains('body', 'Alpha Story');
        self::assertSelectorTextContains('body', 'Beta Story');
        self::assertSelectorTextContains('body', 'Gamma Story');
        self::assertSelectorTextContains('body', '#AI');
        self::assertSelectorExists('a.meta-chip[href="/category/tech"]');
        self::assertSelectorExists('a.meta-chip[href="/tag/ai"]');
    }

    private function setMockedNewsApiClient(): void
    {
        $httpClient = new MockHttpClient(function (string $method, string $url): MockResponse {
            $path = (string) parse_url($url, PHP_URL_PATH);
            parse_str((string) parse_url($url, PHP_URL_QUERY), $query);

            if ($method === 'GET' && $path === '/api/v1/media/search') {
                return $this->jsonResponse([
                    'data' => [
                        ['id' => 7, 'path' => '/uploads/news/alpha.jpg', 'alt_text' => 'Alpha'],
                    ],
                ]);
            }

            if ($method === 'GET' && $path === '/api/v1/categories/popular') {
                return $this->jsonResponse([
                    'data' => [
                        ['name' => 'Tech', 'slug' => 'tech', 'count' => 30],
                        ['name' => 'Ekonomia', 'slug' => 'ekonomia', 'count' => 20],
                        ['name' => 'Świat', 'slug' => 'swiat', 'count' => 10],
                    ],
                ]);
            }

            if ($method === 'GET' && $path === '/api/v1/categories') {
                return $this->jsonResponse([
                    'data' => [
                        ['id' => 1, 'name' => 'Tech', 'slug' => 'tech'],
                        ['id' => 2, 'name' => 'Ekonomia', 'slug' => 'ekonomia'],
                        ['id' => 3, 'name' => 'Świat', 'slug' => 'swiat'],
                    ],
                ]);
            }

            if ($method === 'GET' && $path === '/api/v1/articles/search') {
                $sort = is_string($query['sort'] ?? null) ? $query['sort'] : '';
                $rows = match ($sort) {
                    'view_count' => [
                        ['id' => 12, 'title' => 'Gamma Story', 'description' => 'Top viewed', 'author' => 'Desk', 'view_count' => 990, 'tag_names' => ['AI'], 'tag_refs' => ['1|ai|AI'], 'category_names' => ['Tech'], 'category_refs' => ['1|tech|Tech']],
                    ],
                    default => [
                        ['id' => 10, 'title' => 'Alpha Story', 'description' => 'Hero story', 'author' => 'Desk', 'featured_image_id' => 7, 'view_count' => 123, 'tag_names' => ['AI'], 'tag_refs' => ['1|ai|AI'], 'category_names' => ['Tech'], 'category_refs' => ['1|tech|Tech']],
                        ['id' => 11, 'title' => 'Beta Story', 'description' => 'Latest story', 'author' => 'Desk', 'view_count' => 45, 'tag_names' => ['Biznes'], 'tag_refs' => ['2|biznes|Biznes'], 'category_names' => ['Ekonomia'], 'category_refs' => ['2|ekonomia|Ekonomia']],
                    ],
                };

                return $this->jsonResponse(['data' => $rows]);
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
