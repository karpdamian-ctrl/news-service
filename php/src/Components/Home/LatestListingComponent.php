<?php

declare(strict_types=1);

namespace App\Components\Home;

final class LatestListingComponent extends ApiArticleComponent
{
    /**
     * @return array{title:string,items:list<array<string,mixed>>,errors:list<string>}
     */
    public function data(): array
    {
        $errors = [];
        $mediaMap = $this->fetchMediaMap($errors);
        $docs = $this->searchArticles(
            ['per_page' => 6, 'sort' => 'published_at', 'order' => 'desc', 'filter' => ['status' => 'published']],
            $errors
        );

        return [
            'title' => 'Ostatnio dodane',
            'items' => array_map(fn (array $doc): array => $this->normalizeArticle($doc, $mediaMap), $docs),
            'errors' => array_values(array_unique($errors)),
        ];
    }
}
