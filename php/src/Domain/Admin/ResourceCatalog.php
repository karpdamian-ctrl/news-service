<?php

declare(strict_types=1);

namespace App\Domain\Admin;

use App\Entity\User;

final class ResourceCatalog
{
    /**
     * @var array<string, array<string, mixed>>
     */
    private array $resources;

    /**
     * @var array<string, array{index:string,new:?string,edit:?string,delete:?string,show:?string}>
     */
    private array $routes;

    public function __construct(private readonly ResourceCatalogProvider $provider)
    {
        $this->resources = $this->provider->resources();
        $this->routes = $this->provider->routes();
    }

    /**
     * @return array<string, mixed>|null
     */
    public function get(string $resourceKey): ?array
    {
        return $this->resources[$resourceKey] ?? null;
    }

    /**
     * @return array<int, array{key:string,label:string,route:string}>
     */
    public function menuItems(?User $currentUser): array
    {
        $items = [];

        foreach ($this->resources as $key => $config) {
            if ($key === 'users' && !($currentUser instanceof User && in_array(User::ROLE_ADMIN, $currentUser->getRoles(), true))) {
                continue;
            }

            $items[] = [
                'key' => $key,
                'label' => (string) $config['label'],
                'route' => $this->routes($key)['index'],
            ];
        }

        return $items;
    }

    /**
     * @return array{index:string,new:?string,edit:?string,delete:?string,show:?string}
     */
    public function routes(string $resourceKey): array
    {
        if (!isset($this->routes[$resourceKey])) {
            throw new \InvalidArgumentException(sprintf('Unknown resource key "%s"', $resourceKey));
        }

        return $this->routes[$resourceKey];
    }
}
