<?php

declare(strict_types=1);

namespace App\Components\Home;

use App\Api\NewsApiClient;

abstract class ApiArticleComponent
{
    public function __construct(
        protected readonly NewsApiClient $apiClient,
        protected readonly string $publicMediaBaseUrl,
    ) {
    }

    /**
     * @param array<string,mixed> $params
     * @param list<string> $errors
     * @return list<array<string,mixed>>
     */
    protected function searchArticles(array $params, array &$errors): array
    {
        $response = $this->apiClient->list('articles/search', $params);
        if ($response['status'] < 200 || $response['status'] >= 300) {
            $this->appendApiError($response, $errors, 'Nie udało się pobrać artykułów z wyszukiwarki.');
            return [];
        }

        $data = $response['data']['data'] ?? [];
        if (!is_array($data)) {
            return [];
        }

        /** @var list<array<string,mixed>> $rows */
        $rows = array_values(array_filter($data, static fn (mixed $row): bool => is_array($row)));
        return $rows;
    }

    /**
     * @param list<string> $errors
     * @return array<int,array{path:string,alt:?string}>
     */
    protected function fetchMediaMap(array &$errors): array
    {
        $response = $this->apiClient->list('media/search', ['per_page' => 100, 'sort' => 'id', 'order' => 'desc']);
        if ($response['status'] < 200 || $response['status'] >= 300) {
            $this->appendApiError($response, $errors, 'Nie udało się pobrać mediów.');
            return [];
        }

        $data = $response['data']['data'] ?? [];
        if (!is_array($data)) {
            return [];
        }

        $map = [];
        foreach ($data as $row) {
            if (!is_array($row)) {
                continue;
            }

            $id = $this->toInt($row['id'] ?? null);
            $path = $this->toString($row['path'] ?? null);
            if ($id === null || $path === null) {
                continue;
            }

            $map[$id] = [
                'path' => $path,
                'alt' => $this->toString($row['alt_text'] ?? null),
            ];
        }

        return $map;
    }

    /**
     * @param array<string,mixed> $doc
     * @param array<int,array{path:string,alt:?string}> $mediaMap
     * @return array<string,mixed>
     */
    protected function normalizeArticle(
        array $doc,
        array $mediaMap = [],
        array $categoryMap = [],
        array $tagMap = [],
    ): array
    {
        $featuredImageId = $this->toInt($doc['featured_image_id'] ?? null);
        $media = $featuredImageId !== null ? ($mediaMap[$featuredImageId] ?? null) : null;
        $categoryRefs = $this->resolveRefs($doc, 'category_refs', 'category_ids', $categoryMap);
        $tagRefs = $this->resolveRefs($doc, 'tag_refs', 'tag_ids', $tagMap);
        $categoryLinks = $this->parseCategoryLinks($categoryRefs);
        $tagLinks = $this->parseTagLinks($tagRefs);
        $categoryNames = array_values(array_map(static fn (array $item): string => $item['name'], $categoryLinks));
        $tagNames = array_values(array_map(static fn (array $item): string => $item['name'], $tagLinks));

        return [
            'id' => $this->toInt($doc['id'] ?? null),
            'title' => $this->toString($doc['title'] ?? null) ?? 'Untitled',
            'slug' => $this->toString($doc['slug'] ?? null) ?? '',
            'url' => '/article/' . rawurlencode($this->toString($doc['slug'] ?? null) ?? ''),
            'description' => $this->toString($doc['description'] ?? null) ?? '',
            'content' => $this->toString($doc['content'] ?? null) ?? '',
            'content_html' => $this->toString($doc['content_html'] ?? null) ?? '',
            'author' => $this->toString($doc['author'] ?? null) ?? 'Redakcja',
            'published_at' => $this->formatDate($this->toString($doc['published_at'] ?? null)),
            'view_count' => $this->toInt($doc['view_count'] ?? null) ?? 0,
            'tags' => $tagNames,
            'tag_links' => $tagLinks,
            'categories' => $categoryNames,
            'category_links' => $categoryLinks,
            'image_url' => $this->resolvePublicMediaUrl($media['path'] ?? null),
            'image_alt' => $media['alt'] ?? null,
        ];
    }

    /**
     * @param mixed $value
     * @return list<array{name:string,slug:string,url:string}>
     */
    protected function parseCategoryLinks(mixed $value): array
    {
        if (!is_array($value)) {
            return [];
        }

        $links = [];
        foreach ($value as $rawRef) {
            if (!is_string($rawRef) || $rawRef === '') {
                continue;
            }

            $parts = explode('|', $rawRef, 3);
            if (count($parts) !== 3) {
                continue;
            }

            [, $slug, $name] = $parts;
            $slug = trim($slug);
            $name = trim($name);

            if ($slug === '' || $name === '') {
                continue;
            }

            $links[] = [
                'name' => $name,
                'slug' => $slug,
                'url' => '/category/' . rawurlencode($slug),
            ];
        }

        return $links;
    }

    /**
     * @param mixed $value
     * @return list<array{name:string,slug:string,url:string}>
     */
    protected function parseTagLinks(mixed $value): array
    {
        if (!is_array($value)) {
            return [];
        }

        $links = [];
        foreach ($value as $rawRef) {
            if (!is_string($rawRef) || $rawRef === '') {
                continue;
            }

            $parts = explode('|', $rawRef, 3);
            if (count($parts) !== 3) {
                continue;
            }

            [, $slug, $name] = $parts;
            $slug = trim($slug);
            $name = trim($name);

            if ($slug === '' || $name === '') {
                continue;
            }

            $links[] = [
                'name' => $name,
                'slug' => $slug,
                'url' => '/tag/' . rawurlencode($slug),
            ];
        }

        return $links;
    }

    protected function resolvePublicMediaUrl(?string $path): ?string
    {
        if ($path === null || $path === '') {
            return null;
        }

        if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
            return $path;
        }

        return rtrim($this->publicMediaBaseUrl, '/') . '/' . ltrim($path, '/');
    }

    protected function formatDate(?string $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }

        try {
            return (new \DateTimeImmutable($value))->format('d.m.Y H:i');
        } catch (\Exception) {
            return $value;
        }
    }

    /**
     * @return list<string>
     */
    protected function toStringList(mixed $value): array
    {
        if (!is_array($value)) {
            return [];
        }

        $items = [];
        foreach ($value as $item) {
            $asString = $this->toString($item);
            if ($asString !== null && $asString !== '') {
                $items[] = $asString;
            }
        }

        return array_values(array_unique($items));
    }

    protected function toString(mixed $value): ?string
    {
        if (is_string($value)) {
            return $value;
        }
        if (is_int($value) || is_float($value) || is_bool($value)) {
            return (string) $value;
        }
        return null;
    }

    protected function toInt(mixed $value): ?int
    {
        if (is_int($value)) {
            return $value;
        }
        if (is_string($value) && is_numeric($value)) {
            return (int) $value;
        }
        return null;
    }

    /**
     * @param list<string> $errors
     * @return array<int,array{slug:string,name:string}>
     */
    protected function fetchCategoryMap(array &$errors): array
    {
        $response = $this->apiClient->list('categories', ['per_page' => 500, 'sort' => 'name', 'order' => 'asc']);

        if ($response['status'] < 200 || $response['status'] >= 300) {
            $this->appendApiError($response, $errors, 'Nie udało się pobrać kategorii.');
            return [];
        }

        $rows = $response['data']['data'] ?? [];
        if (!is_array($rows)) {
            return [];
        }

        $map = [];
        foreach ($rows as $row) {
            if (!is_array($row)) {
                continue;
            }

            $id = $this->toInt($row['id'] ?? null);
            $slug = $this->toString($row['slug'] ?? null);
            $name = $this->toString($row['name'] ?? null);
            if ($id === null || $slug === null || $slug === '' || $name === null || $name === '') {
                continue;
            }

            $map[$id] = ['slug' => $slug, 'name' => $name];
        }

        return $map;
    }

    /**
     * @param list<string> $errors
     * @return array<int,array{slug:string,name:string}>
     */
    protected function fetchTagMap(array &$errors): array
    {
        $response = $this->apiClient->list('tags', ['per_page' => 500, 'sort' => 'name', 'order' => 'asc']);

        if ($response['status'] < 200 || $response['status'] >= 300) {
            $this->appendApiError($response, $errors, 'Nie udało się pobrać tagów.');
            return [];
        }

        $rows = $response['data']['data'] ?? [];
        if (!is_array($rows)) {
            return [];
        }

        $map = [];
        foreach ($rows as $row) {
            if (!is_array($row)) {
                continue;
            }

            $id = $this->toInt($row['id'] ?? null);
            $slug = $this->toString($row['slug'] ?? null);
            $name = $this->toString($row['name'] ?? null);
            if ($id === null || $slug === null || $slug === '' || $name === null || $name === '') {
                continue;
            }

            $map[$id] = ['slug' => $slug, 'name' => $name];
        }

        return $map;
    }

    /**
     * @param array<string,mixed> $doc
     * @param array<int,array{slug:string,name:string}> $lookup
     * @return list<string>
     */
    private function resolveRefs(array $doc, string $refsKey, string $idsKey, array $lookup): array
    {
        $refs = $doc[$refsKey] ?? [];
        if (is_array($refs)) {
            $normalizedRefs = array_values(array_filter($refs, static fn (mixed $item): bool => is_string($item) && $item !== ''));
            if ($normalizedRefs !== []) {
                return $normalizedRefs;
            }
        }

        $ids = $doc[$idsKey] ?? [];
        if (!is_array($ids)) {
            return [];
        }

        $refsFromIds = [];
        foreach ($ids as $idValue) {
            $id = $this->toInt($idValue);
            if ($id === null || !isset($lookup[$id])) {
                continue;
            }

            $meta = $lookup[$id];
            $refsFromIds[] = sprintf('%d|%s|%s', $id, $meta['slug'], $meta['name']);
        }

        return $refsFromIds;
    }

    /**
     * @param array{status:int,data:array<string,mixed>} $response
     * @param list<string> $errors
     */
    protected function appendApiError(array $response, array &$errors, string $fallback): void
    {
        $data = $response['data'] ?? [];

        $message = null;
        if (isset($data['message']) && is_string($data['message']) && trim($data['message']) !== '') {
            $message = trim($data['message']);
        } elseif (($data['error'] ?? null) === 'rate_limited') {
            $message = 'Przekroczono limit zapytań do API. Spróbuj ponownie za chwilę.';
        } elseif (isset($data['error']) && is_string($data['error']) && trim($data['error']) !== '') {
            $message = trim($data['error']);
        }

        $errors[] = $message ?? $fallback;
    }
}
