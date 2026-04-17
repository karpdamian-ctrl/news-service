<?php

declare(strict_types=1);

namespace App\Components\Tag;

use App\Components\Home\ApiArticleComponent;

final class TagArticlesListingComponent extends ApiArticleComponent
{
    /**
     * @return array{
     *   tag: array<string,mixed>|null,
     *   items: list<array<string,mixed>>,
     *   errors: list<string>,
     *   not_found: bool
     * }
     */
    public function data(string $slug): array
    {
        $errors = [];
        $tag = $this->fetchTagBySlug($slug, $errors);

        if ($tag === null) {
            return [
                'tag' => null,
                'items' => [],
                'errors' => $errors,
                'not_found' => true,
            ];
        }

        $mediaMap = $this->fetchMediaMap($errors);
        $docs = $this->searchArticles([
            'per_page' => 50,
            'sort' => 'published_at',
            'order' => 'desc',
            'filter' => [
                'status' => 'published',
                'tag_ids' => [(int) $tag['id']],
            ],
        ], $errors);

        return [
            'tag' => $tag,
            'items' => array_map(fn (array $doc): array => $this->normalizeArticle($doc, $mediaMap), $docs),
            'errors' => array_values(array_unique($errors)),
            'not_found' => false,
        ];
    }

    /**
     * @param list<string> $errors
     * @return array<string,mixed>|null
     */
    private function fetchTagBySlug(string $slug, array &$errors): ?array
    {
        $response = $this->apiClient->list('tags', [
            'per_page' => 1,
            'filter' => ['slug' => $slug],
        ]);

        if ($response['status'] < 200 || $response['status'] >= 300) {
            $errors[] = 'Nie udało się pobrać tagu.';
            return null;
        }

        $items = $response['data']['data'] ?? [];
        if (!is_array($items) || !isset($items[0]) || !is_array($items[0])) {
            return null;
        }

        $id = $items[0]['id'] ?? null;
        $name = $items[0]['name'] ?? null;
        $resolvedSlug = $items[0]['slug'] ?? null;

        if (!is_int($id) || !is_string($name) || !is_string($resolvedSlug)) {
            return null;
        }

        return [
            'id' => $id,
            'name' => $name,
            'slug' => $resolvedSlug,
        ];
    }
}
