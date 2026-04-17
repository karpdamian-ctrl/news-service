<?php

declare(strict_types=1);

namespace App\Components\Category;

use App\Components\Home\ApiArticleComponent;

final class CategoryArticlesListingComponent extends ApiArticleComponent
{
    /**
     * @return array{
     *   category: array<string,mixed>|null,
     *   items: list<array<string,mixed>>,
     *   errors: list<string>,
     *   not_found: bool
     * }
     */
    public function data(string $slug): array
    {
        $errors = [];
        $category = $this->fetchCategoryBySlug($slug, $errors);

        if ($category === null) {
            return [
                'category' => null,
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
                'category_ids' => [(int) $category['id']],
            ],
        ], $errors);

        return [
            'category' => $category,
            'items' => array_map(fn (array $doc): array => $this->normalizeArticle($doc, $mediaMap), $docs),
            'errors' => array_values(array_unique($errors)),
            'not_found' => false,
        ];
    }

    /**
     * @param list<string> $errors
     * @return array<string,mixed>|null
     */
    private function fetchCategoryBySlug(string $slug, array &$errors): ?array
    {
        $response = $this->apiClient->list('categories', [
            'per_page' => 1,
            'filter' => ['slug' => $slug],
        ]);

        if ($response['status'] < 200 || $response['status'] >= 300) {
            $this->appendApiError($response, $errors, 'Nie udało się pobrać kategorii.');
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
