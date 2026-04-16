<?php

declare(strict_types=1);

namespace App\Controller\Admin;

use App\Domain\Admin\ApiResourceService;
use App\Domain\Admin\ResourceCatalog;
use App\Entity\User;
use Symfony\Component\HttpFoundation\RedirectResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/admin/articles')]
final class ArticleController extends AbstractAdminController
{
    private const RESOURCE_KEY = 'articles';

    public function __construct(
        ResourceCatalog $catalog,
        private readonly ApiResourceService $apiService,
    ) {
        parent::__construct($catalog);
    }

    #[Route('', name: 'admin_articles_index', methods: ['GET'])]
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

    #[Route('/new', name: 'admin_articles_new', methods: ['GET', 'POST'])]
    public function create(Request $request): Response
    {
        $config = $this->catalog->get(self::RESOURCE_KEY) ?? throw $this->createNotFoundException();
        $this->assertResourceWritable(self::RESOURCE_KEY, $config);

        $values = [];
        $formFields = $this->apiService->resolveFormFields(self::RESOURCE_KEY, $config, $values);
        $errors = [];

        if ($request->isMethod('POST')) {
            $payload = $this->buildPayload($formFields, $request, $config);
            $payload = $this->apiService->enrichPayload(self::RESOURCE_KEY, $payload, $config, $this->getUser() instanceof User ? $this->getUser() : null);
            $values = $payload;
            $formFields = $this->apiService->resolveFormFields(self::RESOURCE_KEY, $config, $values);

            $result = $this->apiService->create($config, $payload);
            if ($result['ok']) {
                $this->addFlash('success', 'Articles created.');
                return $this->redirectToRoute('admin_articles_index');
            }

            $errors = $result['errors'];
        }

        return $this->renderForm(self::RESOURCE_KEY, $config, false, null, $formFields, $values, $errors);
    }

    #[Route('/{id}/edit', name: 'admin_articles_edit', requirements: ['id' => '\d+'], methods: ['GET', 'POST'])]
    public function edit(int $id, Request $request): Response
    {
        $config = $this->catalog->get(self::RESOURCE_KEY) ?? throw $this->createNotFoundException();
        $this->assertResourceWritable(self::RESOURCE_KEY, $config);

        $entity = $this->apiService->get($config, $id);
        if (!is_array($entity)) {
            throw $this->createNotFoundException();
        }

        $values = $entity;
        $formFields = $this->apiService->resolveFormFields(self::RESOURCE_KEY, $config, $values);
        $errors = [];

        if ($request->isMethod('POST')) {
            $payload = $this->buildPayload($formFields, $request, $config);
            $payload = $this->apiService->enrichPayload(self::RESOURCE_KEY, $payload, $config, $this->getUser() instanceof User ? $this->getUser() : null);
            $values = array_merge($values, $payload);
            $formFields = $this->apiService->resolveFormFields(self::RESOURCE_KEY, $config, $values);

            $result = $this->apiService->update($config, $id, $payload);
            if ($result['ok']) {
                $this->addFlash('success', 'Articles updated.');
                return $this->redirectToRoute('admin_articles_index');
            }

            $errors = $result['errors'];
        }

        return $this->renderForm(self::RESOURCE_KEY, $config, true, $id, $formFields, $values, $errors);
    }

    #[Route('/{id}/delete', name: 'admin_articles_delete', requirements: ['id' => '\d+'], methods: ['POST'])]
    public function delete(int $id, Request $request): RedirectResponse
    {
        $config = $this->catalog->get(self::RESOURCE_KEY) ?? throw $this->createNotFoundException();
        $this->assertResourceWritable(self::RESOURCE_KEY, $config);

        if (!$this->isCsrfTokenValid(sprintf('delete_%s_%d', self::RESOURCE_KEY, $id), (string) $request->request->get('_token'))) {
            $this->addFlash('error', 'Invalid CSRF token.');
            return $this->redirectToRoute('admin_articles_index');
        }

        if ($this->apiService->delete($config, $id)) {
            $this->addFlash('success', 'Articles deleted.');
        } else {
            $this->addFlash('error', 'Delete failed.');
        }

        return $this->redirectToRoute('admin_articles_index');
    }
}
