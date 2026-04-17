<?php

declare(strict_types=1);

namespace App\Components\Article;

use App\Components\Home\ApiArticleComponent;

final class ArticleDetailsComponent extends ApiArticleComponent
{
    /**
     * @return array{
     *   article: array<string,mixed>|null,
     *   errors: list<string>,
     *   not_found: bool
     * }
     */
    public function data(string $slug): array
    {
        $errors = [];
        $mediaMap = $this->fetchMediaMap($errors);

        $response = $this->apiClient->list('articles', [
            'per_page' => 1,
            'sort' => 'published_at',
            'order' => 'desc',
            'filter' => [
                'status' => 'published',
                'slug' => $slug,
            ],
        ]);

        $docs = [];
        if ($response['status'] === 200) {
            $data = $response['data']['data'] ?? [];
            if (is_array($data)) {
                /** @var list<array<string,mixed>> $rows */
                $rows = array_values(array_filter($data, static fn (mixed $row): bool => is_array($row)));
                $docs = $rows;
            }
        } else {
            $errors[] = $response['data']['error'] ?? 'Nie udało się pobrać artykułu.';
        }

        if (!isset($docs[0])) {
            return [
                'article' => null,
                'errors' => $errors,
                'not_found' => true,
            ];
        }

        $articleDoc = $docs[0];
        $elasticRefs = $this->fetchElasticRefs($slug);

        if ($elasticRefs !== null) {
            $articleDoc['category_refs'] = $elasticRefs['category_refs'] ?? [];
            $articleDoc['tag_refs'] = $elasticRefs['tag_refs'] ?? [];
        }

        $article = $this->normalizeArticle($articleDoc, $mediaMap);
        $articleId = $this->toInt($article['id'] ?? null);

        if ($articleId !== null && $this->incrementViewCount($articleId)) {
            $article['view_count'] = (int) ($article['view_count'] ?? 0) + 1;
        }

        return [
            'article' => $article,
            'errors' => array_values(array_unique($errors)),
            'not_found' => false,
        ];
    }

    private function incrementViewCount(int $articleId): bool
    {
        $response = $this->apiClient->create(sprintf('articles/%d/view', $articleId), []);

        return $response['status'] >= 200 && $response['status'] < 300;
    }

    /**
     * @return array{category_refs:list<string>,tag_refs:list<string>}|null
     */
    private function fetchElasticRefs(string $slug): ?array
    {
        $response = $this->apiClient->list('articles/search', [
            'per_page' => 1,
            'sort' => 'published_at',
            'order' => 'desc',
            'filter' => [
                'status' => 'published',
                'slug' => $slug,
            ],
        ]);

        if ($response['status'] < 200 || $response['status'] >= 300) {
            return null;
        }

        $data = $response['data']['data'] ?? [];
        if (!is_array($data) || !is_array($data[0] ?? null)) {
            return null;
        }

        $doc = $data[0];
        $categoryRefs = $this->normalizeRefs($doc['category_refs'] ?? []);
        $tagRefs = $this->normalizeRefs($doc['tag_refs'] ?? []);

        return [
            'category_refs' => $categoryRefs,
            'tag_refs' => $tagRefs,
        ];
    }

    /**
     * @return list<string>
     */
    private function normalizeRefs(mixed $value): array
    {
        if (!is_array($value)) {
            return [];
        }

        return array_values(array_filter($value, static fn (mixed $item): bool => is_string($item) && $item !== ''));
    }
}
