<?php

declare(strict_types=1);

namespace App\Components\Home;

use App\Api\NewsApiClient;

final class HeaderComponent
{
    public function __construct(private readonly NewsApiClient $apiClient)
    {
    }

    /**
     * @return array{site_name:string,menu:list<array{label:string,href:string}>}
     */
    public function data(): array
    {
        $menu = $this->topCategoryMenu();

        return [
            'site_name' => 'Horyzont News',
            'menu' => $menu,
        ];
    }

    /**
     * @return list<array{label:string,href:string}>
     */
    private function topCategoryMenu(): array
    {
        $categoriesResponse = $this->apiClient->list('categories/popular', ['limit' => 5]);

        if ($categoriesResponse['status'] < 200 || $categoriesResponse['status'] >= 300) {
            $categoriesResponse = $this->apiClient->list('categories', [
                'per_page' => 5,
                'sort' => 'name',
                'order' => 'asc',
            ]);
        }

        if ($categoriesResponse['status'] < 200 || $categoriesResponse['status'] >= 300) {
            return [];
        }

        $categories = $categoriesResponse['data']['data'] ?? [];
        if (!is_array($categories)) {
            return [];
        }

        $menu = [];
        foreach ($categories as $category) {
            if (!is_array($category)) {
                continue;
            }

            $name = $category['name'] ?? null;
            $slug = $category['slug'] ?? null;
            if (is_string($name) && $name !== '' && is_string($slug) && $slug !== '') {
                $menu[] = ['label' => $name, 'href' => '/category/' . rawurlencode($slug)];
            }
        }

        return $menu;
    }
}
