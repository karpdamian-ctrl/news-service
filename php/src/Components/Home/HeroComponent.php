<?php

declare(strict_types=1);

namespace App\Components\Home;

final class HeroComponent extends ApiArticleComponent
{
    /**
     * @return array{article:array<string,mixed>|null,errors:list<string>}
     */
    public function data(): array
    {
        $errors = [];
        $mediaMap = $this->fetchMediaMap($errors);
        $docs = $this->searchArticles(
            ['per_page' => 1, 'sort' => 'published_at', 'order' => 'desc', 'filter' => ['status' => 'published']],
            $errors
        );

        $hero = isset($docs[0]) ? $this->normalizeArticle($docs[0], $mediaMap) : null;

        return ['article' => $hero, 'errors' => array_values(array_unique($errors))];
    }
}
