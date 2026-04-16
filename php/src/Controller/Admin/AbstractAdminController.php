<?php

declare(strict_types=1);

namespace App\Controller\Admin;

use App\Domain\Admin\ResourceCatalog;
use App\Entity\User;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

abstract class AbstractAdminController extends AbstractController
{
    public function __construct(protected readonly ResourceCatalog $catalog)
    {
    }

    /**
     * @param array<string, mixed> $config
     * @param array<int, array<string, mixed>> $items
     * @param array<int, string> $errors
     */
    protected function renderIndex(
        string $resourceKey,
        array $config,
        array $items,
        mixed $meta,
        array $errors
    ): Response {
        return $this->render('admin/index.html.twig', [
            'menu_items' => $this->catalog->menuItems($this->getUser() instanceof User ? $this->getUser() : null),
            'resource_key' => $resourceKey,
            'resource_label' => (string) $config['label'],
            'routes' => $this->catalog->routes($resourceKey),
            'items' => $items,
            'list_fields' => $this->resourceListFields($config),
            'sortable_fields' => $this->resourceSortableFields($config),
            'meta' => $meta,
            'errors' => $errors,
            'can_create' => !$this->isReadOnly($config),
            'can_show' => $this->canShow($config),
            'can_edit' => !$this->isReadOnly($config),
            'can_delete' => !$this->isReadOnly($config),
        ]);
    }

    /**
     * @param array<string, mixed> $config
     * @param array<int, array<string, mixed>> $fields
     * @param array<string, mixed> $values
     * @param array<int, string> $errors
     */
    protected function renderForm(
        string $resourceKey,
        array $config,
        bool $isEdit,
        ?int $entityId,
        array $fields,
        array $values,
        array $errors
    ): Response {
        return $this->render('admin/form.html.twig', [
            'menu_items' => $this->catalog->menuItems($this->getUser() instanceof User ? $this->getUser() : null),
            'resource_key' => $resourceKey,
            'resource_label' => (string) $config['label'],
            'routes' => $this->catalog->routes($resourceKey),
            'is_edit' => $isEdit,
            'entity_id' => $entityId,
            'fields' => $fields,
            'values' => $values,
            'errors' => $errors,
        ]);
    }

    /**
     * @param array<string, mixed> $config
     * @param array<string, mixed> $item
     */
    protected function renderShow(string $resourceKey, array $config, array $item): Response
    {
        return $this->render('admin/show.html.twig', [
            'menu_items' => $this->catalog->menuItems($this->getUser() instanceof User ? $this->getUser() : null),
            'resource_key' => $resourceKey,
            'resource_label' => (string) $config['label'],
            'routes' => $this->catalog->routes($resourceKey),
            'item' => $item,
            'detail_fields' => $this->resourceDetailFields($config),
        ]);
    }

    /**
     * @param array<int, array<string, mixed>> $fields
     * @param array<string, mixed> $resourceConfig
     * @return array<string, mixed>
     */
    protected function buildPayload(array $fields, Request $request, array $resourceConfig): array
    {
        $payload = [];
        $isLocal = ($resourceConfig['source'] ?? null) === 'local';

        foreach ($fields as $field) {
            $name = isset($field['name']) && is_string($field['name']) ? $field['name'] : '';
            if ($name === '') {
                continue;
            }

            $type = isset($field['type']) && is_string($field['type']) ? $field['type'] : 'text';

            if ($type === 'multiselect') {
                $raw = $request->request->all($name);
                if (!is_array($raw)) {
                    $single = $request->request->get($name);
                    if (is_array($single)) {
                        $raw = $single;
                    } elseif (is_scalar($single) && $single !== '') {
                        $raw = [(string) $single];
                    } else {
                        $raw = [];
                    }
                }

                if ($isLocal) {
                    $values = array_values(array_filter(
                        array_map(static fn ($value) => is_scalar($value) ? (string) $value : '', $raw),
                        static fn (string $value): bool => $value !== ''
                    ));
                    $payload[$name] = array_values(array_unique($values));
                } else {
                    $ids = array_values(array_filter(array_map(static fn ($value) => is_numeric($value) ? (int) $value : null, $raw)));
                    $payload[$name] = $ids !== [] ? $ids : [];
                }
                continue;
            }

            if ($type === 'checkbox') {
                $payload[$name] = $request->request->has($name) || (string) $request->request->get($name, '') === '1';
                continue;
            }

            $value = $request->request->get($name);
            if ($value === null || $value === '') {
                continue;
            }

            if ($type === 'number') {
                if (is_numeric($value)) {
                    $payload[$name] = (int) $value;
                }
                continue;
            }

            if ($type === 'select' && is_numeric($value)) {
                $payload[$name] = (int) $value;
                continue;
            }

            $payload[$name] = (string) $value;
        }

        return $payload;
    }

    /**
     * @param array<string, mixed> $config
     */
    protected function assertResourceWritable(string $resourceKey, array $config): void
    {
        if ($this->isReadOnly($config)) {
            throw $this->createAccessDeniedException(sprintf('Resource "%s" is read-only.', $resourceKey));
        }
    }

    /**
     * @param array<string, mixed> $config
     * @return array<int, string>
     */
    private function resourceListFields(array $config): array
    {
        $fields = $config['list_fields'] ?? [];
        if (!is_array($fields)) {
            return [];
        }

        return array_values(array_filter($fields, static fn ($field) => is_string($field) && $field !== ''));
    }

    /**
     * @param array<string, mixed> $config
     * @return array<int, string>
     */
    private function resourceDetailFields(array $config): array
    {
        $fields = $config['detail_fields'] ?? $this->resourceListFields($config);
        if (!is_array($fields)) {
            return [];
        }

        return array_values(array_filter($fields, static fn ($field) => is_string($field) && $field !== ''));
    }

    /**
     * @param array<string, mixed> $config
     * @return array<int, string>
     */
    private function resourceSortableFields(array $config): array
    {
        $fields = $config['sortable_fields'] ?? $this->resourceListFields($config);
        if (!is_array($fields)) {
            return [];
        }

        return array_values(array_filter($fields, static fn ($field) => is_string($field) && $field !== ''));
    }

    /**
     * @param array<string, mixed> $config
     */
    private function canShow(array $config): bool
    {
        return $this->isReadOnly($config) || (($config['allow_show'] ?? false) === true);
    }

    /**
     * @param array<string, mixed> $config
     */
    private function isReadOnly(array $config): bool
    {
        return ($config['read_only'] ?? false) === true;
    }
}
