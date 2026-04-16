<?php

declare(strict_types=1);

namespace App\Api;

use Symfony\Contracts\HttpClient\Exception\TransportExceptionInterface;
use Symfony\Contracts\HttpClient\HttpClientInterface;

final class NewsApiClient
{
    public function __construct(
        private readonly HttpClientInterface $httpClient,
        private readonly string $baseUrl,
        private readonly string $token,
    ) {
    }

    /**
     * @param array<string, mixed> $query
     * @return array{status:int,data:array<string, mixed>}
     */
    public function list(string $endpoint, array $query = []): array
    {
        return $this->request('GET', $endpoint, ['query' => $query]);
    }

    /**
     * @return array{status:int,data:array<string, mixed>}
     */
    public function get(string $endpoint, int $id): array
    {
        return $this->request('GET', sprintf('%s/%d', $endpoint, $id));
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{status:int,data:array<string, mixed>}
     */
    public function create(string $endpoint, array $payload): array
    {
        return $this->request('POST', $endpoint, ['json' => $payload]);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{status:int,data:array<string, mixed>}
     */
    public function update(string $endpoint, int $id, array $payload): array
    {
        return $this->request('PUT', sprintf('%s/%d', $endpoint, $id), ['json' => $payload]);
    }

    /**
     * @return array{status:int,data:array<string, mixed>}
     */
    public function delete(string $endpoint, int $id): array
    {
        return $this->request('DELETE', sprintf('%s/%d', $endpoint, $id));
    }

    /**
     * @param array<string, mixed> $options
     * @return array{status:int,data:array<string, mixed>}
     */
    private function request(string $method, string $endpoint, array $options = []): array
    {
        $url = sprintf('%s/%s', rtrim($this->baseUrl, '/'), ltrim($endpoint, '/'));

        $options['headers'] = [
            'Accept' => 'application/json',
            'Authorization' => sprintf('Bearer %s', $this->token),
        ];

        try {
            $response = $this->httpClient->request($method, $url, $options);
            $status = $response->getStatusCode();
            $raw = $response->getContent(false);
        } catch (TransportExceptionInterface $exception) {
            return [
                'status' => 503,
                'data' => ['error' => 'api_unreachable', 'message' => $exception->getMessage()],
            ];
        }

        if ($raw === '') {
            return ['status' => $status, 'data' => []];
        }

        try {
            /** @var array<string, mixed> $decoded */
            $decoded = json_decode($raw, true, 512, JSON_THROW_ON_ERROR);
        } catch (\JsonException) {
            $decoded = ['error' => 'invalid_api_response', 'raw' => $raw];
        }

        return ['status' => $status, 'data' => $decoded];
    }
}
