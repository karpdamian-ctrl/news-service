<?php

declare(strict_types=1);

namespace App\Controller\Admin;

use App\Domain\Admin\ApiResourceService;
use App\Domain\Admin\ResourceCatalog;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/admin/revisions')]
final class RevisionController extends AbstractAdminController
{
    private const RESOURCE_KEY = 'article-revisions';

    public function __construct(
        ResourceCatalog $catalog,
        private readonly ApiResourceService $apiService,
    ) {
        parent::__construct($catalog);
    }

    #[Route('', name: 'admin_revisions_index', methods: ['GET'])]
    public function index(Request $request): Response
    {
        $config = $this->catalog->get(self::RESOURCE_KEY) ?? throw $this->createNotFoundException();
        $result = $this->apiService->list(
            $config,
            (int) $request->query->get('page', 1),
            is_scalar($request->query->get('sort')) ? (string) $request->query->get('sort') : null,
            is_scalar($request->query->get('order')) ? (string) $request->query->get('order') : null,
            is_scalar($request->query->get('q')) ? (string) $request->query->get('q') : null
        );
        return $this->renderIndex(self::RESOURCE_KEY, $config, $result['items'], $result['meta'], $result['errors']);
    }

    #[Route('/{id}', name: 'admin_revisions_show', requirements: ['id' => '\d+'], methods: ['GET'])]
    public function show(int $id): Response
    {
        $config = $this->catalog->get(self::RESOURCE_KEY) ?? throw $this->createNotFoundException();
        $item = $this->apiService->get($config, $id);
        if (!is_array($item)) {
            throw $this->createNotFoundException();
        }

        return $this->renderShow(self::RESOURCE_KEY, $config, $item);
    }
}
