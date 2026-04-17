<?php

declare(strict_types=1);

namespace App\Tests\Functional;

use App\Api\NewsApiClient;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpClient\MockHttpClient;
use Symfony\Component\HttpClient\Response\MockResponse;

final class TagControllerTest extends WebTestCase
{
    public function testTagPageRendersArticlesForSlugAndTagLinks(): void
    {
        $client = static::createClient();
        $client->disableReboot();

        $this->setMockedNewsApiClient();

        $client->request('GET', '/tag/ai');

        self::assertResponseIsSuccessful();
        self::assertSelectorTextContains('body', 'Tag: #AI');
        self::assertSelectorTextContains('body', 'AI Story');
        self::assertSelectorExists('a.meta-chip[href="/tag/ai"]');
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
                    ],
                ]);
            }

            if ($method === 'GET' && $path === '/api/v1/tags') {
                $slug = is_array($query['filter'] ?? null) ? ($query['filter']['slug'] ?? null) : null;

                if ($slug === 'ai') {
                    return $this->jsonResponse([
                        'data' => [
                            ['id' => 1, 'name' => 'AI', 'slug' => 'ai'],
                        ],
                    ]);
                }

                return $this->jsonResponse(['data' => []]);
            }

            if ($method === 'GET' && $path === '/api/v1/media/search') {
                return $this->jsonResponse([
                    'data' => [
                        ['id' => 11, 'path' => '/uploads/news/ai.jpg', 'alt_text' => 'AI'],
                    ],
                ]);
            }

            if ($method === 'GET' && $path === '/api/v1/articles/search') {
                return $this->jsonResponse([
                    'data' => [
                        [
                            'id' => 90,
                            'title' => 'AI Story',
                            'slug' => 'ai-story',
                            'description' => 'Story from AI tag.',
                            'author' => 'Desk',
                            'published_at' => '2026-04-16T14:00:00Z',
                            'view_count' => 180,
                            'featured_image_id' => 11,
                            'category_refs' => ['1|technology|Technology'],
                            'tag_refs' => ['1|ai|AI'],
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
