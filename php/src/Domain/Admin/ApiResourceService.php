<?php

declare(strict_types=1);

namespace App\Domain\Admin;

use App\Api\NewsApiClient;
use App\Entity\User;

final class ApiResourceService
{
    public function __construct(private readonly NewsApiClient $apiClient)
    {
    }

    /**
     * @param array<string, mixed> $resourceConfig
     * @return array{items:array<int,array<string,mixed>>,meta:mixed,errors:array<int,string>}
     */
    public function list(
        array $resourceConfig,
        int $page = 1,
        ?string $sort = null,
        ?string $order = null,
        ?string $query = null
    ): array
    {
        $allowedSortFields = array_values(array_filter(
            (array) ($resourceConfig['sortable_fields'] ?? $resourceConfig['list_fields'] ?? []),
            static fn ($field) => is_string($field) && $field !== ''
        ));

        $normalizedSort = $this->normalizeSort($sort, $allowedSortFields);
        $normalizedOrder = $this->normalizeOrder($order);

        $params = [
            'page' => max(1, $page),
            'per_page' => 50,
            'sort' => $normalizedSort,
            'order' => $normalizedOrder,
        ];

        $query = is_string($query) ? trim($query) : '';
        if ($query !== '') {
            $params['q'] = $query;
        }

        $response = $this->apiClient->list($this->endpoint($resourceConfig), $params);

        if ($response['status'] >= 200 && $response['status'] < 300) {
            return [
                'items' => (array) ($response['data']['data'] ?? []),
                'meta' => $response['data']['meta'] ?? null,
                'errors' => [],
            ];
        }

        return ['items' => [], 'meta' => null, 'errors' => $this->extractErrors($response['data'])];
    }

    /**
     * @param array<string, mixed> $resourceConfig
     * @return array<string, mixed>|null
     */
    public function get(array $resourceConfig, int $id): ?array
    {
        $response = $this->apiClient->get($this->endpoint($resourceConfig), $id);
        if ($response['status'] < 200 || $response['status'] >= 300) {
            return null;
        }

        return (array) ($response['data']['data'] ?? []);
    }

    /**
     * @param array<string, mixed> $resourceConfig
     * @param array<string, mixed> $payload
     * @return array{ok:bool,errors:array<int,string>}
     */
    public function create(array $resourceConfig, array $payload): array
    {
        $response = $this->apiClient->create($this->endpoint($resourceConfig), $payload);

        if ($response['status'] >= 200 && $response['status'] < 300) {
            return ['ok' => true, 'errors' => []];
        }

        return ['ok' => false, 'errors' => $this->extractErrors($response['data'])];
    }

    /**
     * @param array<string, mixed> $resourceConfig
     * @param array<string, mixed> $payload
     * @return array{ok:bool,errors:array<int,string>}
     */
    public function update(array $resourceConfig, int $id, array $payload): array
    {
        $response = $this->apiClient->update($this->endpoint($resourceConfig), $id, $payload);

        if ($response['status'] >= 200 && $response['status'] < 300) {
            return ['ok' => true, 'errors' => []];
        }

        return ['ok' => false, 'errors' => $this->extractErrors($response['data'])];
    }

    /**
     * @param array<string, mixed> $resourceConfig
     */
    public function delete(array $resourceConfig, int $id): bool
    {
        $response = $this->apiClient->delete($this->endpoint($resourceConfig), $id);
        return $response['status'] >= 200 && $response['status'] < 300;
    }

    /**
     * @param array<string, mixed> $resourceConfig
     * @return array<int, array<string, mixed>>
     */
    public function resolveFormFields(string $resourceKey, array $resourceConfig, array $currentValues = []): array
    {
        $preloadedChoices = [];
        if ($resourceKey === 'articles') {
            $preloadedChoices = $this->articleEditorChoices($currentValues);
        }

        $resolved = [];

        foreach ((array) ($resourceConfig['form_fields'] ?? []) as $field) {
            if (!is_array($field)) {
                continue;
            }

            $choicesFrom = $field['choices_from'] ?? null;
            if (is_string($choicesFrom)) {
                $field['choices'] = $preloadedChoices[$choicesFrom] ?? $this->fetchAllChoiceItemsByResourceKey($choicesFrom);
            }

            $resolved[] = $field;
        }

        return $resolved;
    }

    /**
     * @param array<string, mixed> $currentValues
     * @return array<string, array<int, array{id:int,label:string}>>
     */
    private function articleEditorChoices(array $currentValues): array
    {
        $mediaChoices = $this->fetchAllChoiceItemsByResourceKey('media');
        $categoryChoices = $this->fetchAllChoiceItemsByResourceKey('categories');
        $tagChoices = $this->fetchAllChoiceItemsByResourceKey('tags');

        $selectedMediaId = $this->normalizeNullableInt($currentValues['featured_image_id'] ?? null);
        $selectedCategoryIds = $this->normalizeIdList($currentValues['category_ids'] ?? []);
        $selectedTagIds = $this->normalizeIdList($currentValues['tag_ids'] ?? []);

        $mediaChoices = $this->ensureSelectedChoices('media', $mediaChoices, $selectedMediaId !== null ? [$selectedMediaId] : []);
        $categoryChoices = $this->ensureSelectedChoices('categories', $categoryChoices, $selectedCategoryIds);
        $tagChoices = $this->ensureSelectedChoices('tags', $tagChoices, $selectedTagIds);

        return [
            'media' => $mediaChoices,
            'categories' => $categoryChoices,
            'tags' => $tagChoices,
        ];
    }

    /**
     * @param array<int, array{id:int,label:string}> $choices
     * @param array<int, int> $selectedIds
     * @return array<int, array{id:int,label:string}>
     */
    private function ensureSelectedChoices(string $resourceKey, array $choices, array $selectedIds): array
    {
        $existing = [];
        foreach ($choices as $choice) {
            $existing[$choice['id']] = true;
        }

        foreach ($selectedIds as $id) {
            if (!isset($existing[$id])) {
                $choices[] = $this->fetchChoiceByResourceKeyAndId($resourceKey, $id) ?? ['id' => $id, 'label' => sprintf('#%d', $id)];
                $existing[$id] = true;
            }
        }

        return $choices;
    }

    /**
     * @param mixed $value
     */
    private function normalizeNullableInt(mixed $value): ?int
    {
        if (is_array($value) && isset($value['id'])) {
            $value = $value['id'];
        }

        if (is_int($value) && $value > 0) {
            return $value;
        }
        if (is_string($value) && is_numeric($value) && (int) $value > 0) {
            return (int) $value;
        }

        return null;
    }

    /**
     * @param mixed $value
     * @return array<int, int>
     */
    private function normalizeIdList(mixed $value): array
    {
        if (!is_array($value)) {
            return [];
        }

        $ids = [];
        foreach ($value as $item) {
            if (is_array($item) && isset($item['id']) && is_numeric($item['id']) && (int) $item['id'] > 0) {
                $ids[] = (int) $item['id'];
                continue;
            }
            if (is_int($item) && $item > 0) {
                $ids[] = $item;
                continue;
            }
            if (is_string($item) && is_numeric($item) && (int) $item > 0) {
                $ids[] = (int) $item;
            }
        }

        return array_values(array_unique($ids));
    }

    /**
     * @param array<string, mixed> $payload
     * @param array<string, mixed> $resourceConfig
     * @return array<string, mixed>
     */
    public function enrichPayload(string $resourceKey, array $payload, array $resourceConfig, ?User $actor): array
    {
        if (($resourceConfig['source'] ?? null) === 'local') {
            return $payload;
        }

        if ($resourceKey === 'articles') {
            $payload['changed_by'] = $this->actorIdentity($actor);
        }

        return $payload;
    }

    /**
     * @param array<string, mixed> $resourceConfig
     */
    private function endpoint(array $resourceConfig): string
    {
        $endpoint = $resourceConfig['endpoint'] ?? null;
        if (!is_string($endpoint) || $endpoint === '') {
            throw new \RuntimeException('Invalid resource endpoint configuration.');
        }

        return $endpoint;
    }

    /**
     * @return array<int, array{id:int,label:string}>
     */
    private function fetchAllChoiceItemsByResourceKey(string $resourceKey): array
    {
        $endpoint = $resourceKey;
        $result = [];
        $seen = [];
        $page = 1;

        while (true) {
            $response = $this->apiClient->list($endpoint, [
                'page' => $page,
                'per_page' => 100,
                'sort' => 'id',
                'order' => 'asc',
            ]);

            if ($response['status'] < 200 || $response['status'] >= 300) {
                break;
            }

            $items = (array) ($response['data']['data'] ?? []);
            foreach ($items as $item) {
                if (!is_array($item) || !isset($item['id'])) {
                    continue;
                }

                $id = (int) $item['id'];
                if (isset($seen[$id])) {
                    continue;
                }

                $label = $this->choiceLabel($resourceKey, $item);
                $result[] = ['id' => $id, 'label' => $label];
                $seen[$id] = true;
            }

            $meta = is_array($response['data']['meta'] ?? null) ? $response['data']['meta'] : [];
            $hasNextPage = (bool) ($meta['has_next_page'] ?? false);
            if (!$hasNextPage) {
                break;
            }

            $page++;
            if ($page > 100) {
                break;
            }
        }

        return $result;
    }

    /**
     * @return array{id:int,label:string}|null
     */
    private function fetchChoiceByResourceKeyAndId(string $resourceKey, int $id): ?array
    {
        if ($id <= 0) {
            return null;
        }

        $response = $this->apiClient->get($resourceKey, $id);
        if ($response['status'] < 200 || $response['status'] >= 300) {
            return null;
        }

        $item = $response['data']['data'] ?? null;
        if (!is_array($item) || !isset($item['id'])) {
            return null;
        }

        return [
            'id' => (int) $item['id'],
            'label' => $this->choiceLabel($resourceKey, $item),
        ];
    }

    /**
     * @param array<string, mixed> $item
     */
    private function choiceLabel(string $resourceKey, array $item): string
    {
        if ($resourceKey === 'media') {
            $path = isset($item['path']) && is_string($item['path']) ? trim($item['path']) : '';
            $filename = $path !== '' ? basename($path) : '';

            if ($filename !== '') {
                return $filename;
            }
        }

        return (string) (
            $item['title']
            ?? $item['name']
            ?? $item['slug']
            ?? $item['path']
            ?? $item['caption']
            ?? $item['type']
            ?? ('#' . $item['id'])
        );
    }

    /**
     * @param array<string, mixed> $data
     * @return array<int, string>
     */
    private function extractErrors(array $data): array
    {
        if (isset($data['errors']) && is_array($data['errors'])) {
            $messages = [];
            foreach ($data['errors'] as $field => $messagesForField) {
                if (is_array($messagesForField)) {
                    foreach ($messagesForField as $message) {
                        $messages[] = sprintf('%s: %s', (string) $field, (string) $message);
                    }
                } else {
                    $messages[] = sprintf('%s: %s', (string) $field, (string) $messagesForField);
                }
            }

            return $messages;
        }

        if (isset($data['error'])) {
            return [is_scalar($data['error']) ? (string) $data['error'] : 'api_error'];
        }

        return ['Unexpected API error'];
    }

    private function actorIdentity(?User $actor): string
    {
        if (!$actor instanceof User) {
            return 'System';
        }

        $fullName = trim(sprintf('%s %s', $actor->getFirstName(), $actor->getLastName()));
        if ($fullName !== '') {
            return $fullName;
        }

        $displayName = trim($actor->getDisplayName());
        if ($displayName !== '') {
            return $displayName;
        }

        return $actor->getEmail() !== '' ? $actor->getEmail() : 'System';
    }

    /**
     * @param array<int, string> $allowedFields
     */
    private function normalizeSort(?string $sort, array $allowedFields): string
    {
        if ($sort !== null && in_array($sort, $allowedFields, true)) {
            return $sort;
        }

        if (in_array('id', $allowedFields, true)) {
            return 'id';
        }

        return $allowedFields[0] ?? 'id';
    }

    private function normalizeOrder(?string $order): string
    {
        return strtolower((string) $order) === 'asc' ? 'asc' : 'desc';
    }
}
