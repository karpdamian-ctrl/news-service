<?php

declare(strict_types=1);

namespace App\Infrastructure\Admin;

use App\Domain\Admin\ResourceCatalogProvider;
use Symfony\Component\Yaml\Yaml;

final class YamlResourceCatalogProvider implements ResourceCatalogProvider
{
    /**
     * @var array<string, array<string, mixed>>|null
     */
    private ?array $resources = null;

    /**
     * @var array<string, array{index:string,new:?string,edit:?string,delete:?string,show:?string}>|null
     */
    private ?array $routes = null;

    public function __construct(
        private readonly ?string $resourcesPath = null,
        private readonly ?string $routesPath = null,
    ) {
    }

    public function resources(): array
    {
        $this->boot();
        return $this->resources ?? [];
    }

    public function routes(): array
    {
        $this->boot();
        return $this->routes ?? [];
    }

    private function boot(): void
    {
        if ($this->resources !== null && $this->routes !== null) {
            return;
        }

        $resourcesPath = $this->resourcesPath ?? $this->defaultResourcesPath();
        $routesPath = $this->routesPath ?? $this->defaultRoutesPath();

        $resources = $this->loadResources($resourcesPath);
        $routes = $this->loadRoutes($routesPath);

        $this->validateResourceRouteConsistency($resources, $routes);

        $this->resources = $resources;
        $this->routes = $routes;
    }

    private function defaultResourcesPath(): string
    {
        return dirname(__DIR__, 3) . '/config/admin/resources.yaml';
    }

    private function defaultRoutesPath(): string
    {
        return dirname(__DIR__, 3) . '/config/admin/resource_routes.yaml';
    }

    /**
     * @return array<string, array<string, mixed>>
     */
    private function loadResources(string $path): array
    {
        $raw = Yaml::parseFile($path);
        if (!is_array($raw) || !isset($raw['resources']) || !is_array($raw['resources'])) {
            throw new \RuntimeException(sprintf('Invalid resources config in "%s".', $path));
        }

        /** @var array<string, array<string, mixed>> $resources */
        $resources = $raw['resources'];
        foreach ($resources as $key => $config) {
            $this->validateResource((string) $key, $config, $path);
        }

        return $resources;
    }

    /**
     * @return array<string, array{index:string,new:?string,edit:?string,delete:?string,show:?string}>
     */
    private function loadRoutes(string $path): array
    {
        $raw = Yaml::parseFile($path);
        if (!is_array($raw) || !isset($raw['routes']) || !is_array($raw['routes'])) {
            throw new \RuntimeException(sprintf('Invalid routes config in "%s".', $path));
        }

        /** @var array<string, array{index:string,new:?string,edit:?string,delete:?string,show:?string}> $routes */
        $routes = $raw['routes'];
        foreach ($routes as $resourceKey => $config) {
            $this->validateRouteConfig((string) $resourceKey, $config, $path);
        }

        return $routes;
    }

    /**
     * @param array<string, mixed> $config
     */
    private function validateResource(string $resourceKey, array $config, string $path): void
    {
        if (!$this->isNonEmptyString($config['label'] ?? null)) {
            throw new \RuntimeException(sprintf('Resource "%s" in "%s" must define non-empty "label".', $resourceKey, $path));
        }

        $source = $config['source'] ?? null;
        if ($source !== 'local' && !$this->isNonEmptyString($config['endpoint'] ?? null)) {
            throw new \RuntimeException(sprintf('Resource "%s" in "%s" must define non-empty "endpoint".', $resourceKey, $path));
        }

        $this->assertStringList($resourceKey, $path, 'list_fields', $config['list_fields'] ?? null, true);
        $this->assertStringList($resourceKey, $path, 'sortable_fields', $config['sortable_fields'] ?? null, false);
        $this->assertStringList($resourceKey, $path, 'detail_fields', $config['detail_fields'] ?? null, false);

        $formFields = $config['form_fields'] ?? null;
        if ($formFields !== null) {
            if (!is_array($formFields)) {
                throw new \RuntimeException(sprintf('Resource "%s" in "%s": "form_fields" must be an array.', $resourceKey, $path));
            }

            foreach ($formFields as $index => $field) {
                if (!is_array($field)) {
                    throw new \RuntimeException(sprintf('Resource "%s" in "%s": form_fields[%d] must be an array.', $resourceKey, $path, $index));
                }
                if (!$this->isNonEmptyString($field['name'] ?? null) || !$this->isNonEmptyString($field['type'] ?? null)) {
                    throw new \RuntimeException(sprintf('Resource "%s" in "%s": each form field must define non-empty "name" and "type".', $resourceKey, $path));
                }
            }
        }
    }

    /**
     * @param array<string, mixed> $config
     */
    private function validateRouteConfig(string $resourceKey, array $config, string $path): void
    {
        foreach (['index', 'new', 'edit', 'delete', 'show'] as $key) {
            if (!array_key_exists($key, $config)) {
                throw new \RuntimeException(sprintf('Route config for "%s" in "%s" must define "%s".', $resourceKey, $path, $key));
            }
        }

        if (!$this->isNonEmptyString($config['index'] ?? null)) {
            throw new \RuntimeException(sprintf('Route config for "%s" in "%s" must define non-empty "index".', $resourceKey, $path));
        }

        foreach (['new', 'edit', 'delete', 'show'] as $key) {
            $value = $config[$key];
            if ($value !== null && !$this->isNonEmptyString($value)) {
                throw new \RuntimeException(sprintf('Route config for "%s" in "%s": "%s" must be string|null.', $resourceKey, $path, $key));
            }
        }
    }

    /**
     * @param array<string, array<string, mixed>> $resources
     * @param array<string, array{index:string,new:?string,edit:?string,delete:?string,show:?string}> $routes
     */
    private function validateResourceRouteConsistency(array $resources, array $routes): void
    {
        $resourceKeys = array_keys($resources);
        $routeKeys = array_keys($routes);

        sort($resourceKeys);
        sort($routeKeys);

        if ($resourceKeys !== $routeKeys) {
            throw new \RuntimeException('Resource keys and route keys do not match between resources.yaml and resource_routes.yaml.');
        }
    }

    /**
     * @param mixed $value
     */
    private function isNonEmptyString(mixed $value): bool
    {
        return is_string($value) && trim($value) !== '';
    }

    /**
     * @param mixed $value
     */
    private function assertStringList(string $resourceKey, string $path, string $field, mixed $value, bool $required): void
    {
        if ($value === null && !$required) {
            return;
        }
        if (!is_array($value)) {
            throw new \RuntimeException(sprintf('Resource "%s" in "%s": "%s" must be an array.', $resourceKey, $path, $field));
        }

        foreach ($value as $item) {
            if (!$this->isNonEmptyString($item)) {
                throw new \RuntimeException(sprintf('Resource "%s" in "%s": "%s" must contain only non-empty strings.', $resourceKey, $path, $field));
            }
        }
    }
}
