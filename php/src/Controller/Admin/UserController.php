<?php

declare(strict_types=1);

namespace App\Controller\Admin;

use App\Domain\Admin\ResourceCatalog;
use App\Domain\Admin\UserDomainService;
use App\Entity\User;
use Symfony\Component\HttpFoundation\RedirectResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/admin/users')]
final class UserController extends AbstractAdminController
{
    private const RESOURCE_KEY = 'users';

    public function __construct(
        ResourceCatalog $catalog,
        private readonly UserDomainService $users,
    ) {
        parent::__construct($catalog);
    }

    #[Route('', name: 'admin_users_index', methods: ['GET'])]
    public function index(Request $request): Response
    {
        $this->assertAdmin();
        $config = $this->catalog->get(self::RESOURCE_KEY) ?? throw $this->createNotFoundException();
        $page = max(1, (int) $request->query->get('page', 1));
        $perPage = max(1, min(100, (int) $request->query->get('per_page', 50)));
        $result = $this->users->listItems(
            $page,
            $perPage,
            is_scalar($request->query->get('sort')) ? (string) $request->query->get('sort') : null,
            is_scalar($request->query->get('order')) ? (string) $request->query->get('order') : null,
            is_scalar($request->query->get('q')) ? (string) $request->query->get('q') : null
        );

        return $this->renderIndex(self::RESOURCE_KEY, $config, $result['items'], $result['meta'], []);
    }

    #[Route('/new', name: 'admin_users_new', methods: ['GET', 'POST'])]
    public function create(Request $request): Response
    {
        $this->assertAdmin();
        $config = $this->catalog->get(self::RESOURCE_KEY) ?? throw $this->createNotFoundException();
        $formFields = (array) ($config['form_fields'] ?? []);
        $values = [];
        $errors = [];

        if ($request->isMethod('POST')) {
            $payload = $this->buildPayload($formFields, $request, $config);
            $values = $payload;
            $errors = $this->users->create($payload);

            if ($errors === []) {
                $this->addFlash('success', 'Users created.');
                return $this->redirectToRoute('admin_users_index');
            }
        }

        return $this->renderForm(self::RESOURCE_KEY, $config, false, null, $formFields, $values, $errors);
    }

    #[Route('/{id}/edit', name: 'admin_users_edit', requirements: ['id' => '\d+'], methods: ['GET', 'POST'])]
    public function edit(int $id, Request $request): Response
    {
        $this->assertAdmin();
        $config = $this->catalog->get(self::RESOURCE_KEY) ?? throw $this->createNotFoundException();
        $target = $this->users->find($id);
        if (!$target instanceof User) {
            throw $this->createNotFoundException();
        }

        $formFields = (array) ($config['form_fields'] ?? []);
        $values = $this->users->toFormValues($target);
        $errors = [];

        if ($request->isMethod('POST')) {
            $payload = $this->buildPayload($formFields, $request, $config);
            $values = array_merge($values, $payload);
            $actor = $this->getUser() instanceof User ? $this->getUser() : null;
            $errors = $this->users->update($target, $payload, $actor);

            if ($errors === []) {
                $this->addFlash('success', 'Users updated.');
                return $this->redirectToRoute('admin_users_index');
            }
        }

        return $this->renderForm(self::RESOURCE_KEY, $config, true, $id, $formFields, $values, $errors);
    }

    #[Route('/{id}/delete', name: 'admin_users_delete', requirements: ['id' => '\d+'], methods: ['POST'])]
    public function delete(int $id, Request $request): RedirectResponse
    {
        $this->assertAdmin();
        $target = $this->users->find($id);
        if (!$target instanceof User) {
            $this->addFlash('error', 'User not found.');
            return $this->redirectToRoute('admin_users_index');
        }

        if (!$this->isCsrfTokenValid(sprintf('delete_%s_%d', self::RESOURCE_KEY, $id), (string) $request->request->get('_token'))) {
            $this->addFlash('error', 'Invalid CSRF token.');
            return $this->redirectToRoute('admin_users_index');
        }

        $error = $this->users->delete($target, $this->getUser() instanceof User ? $this->getUser() : null);
        if ($error !== null) {
            $this->addFlash('error', $error);
            return $this->redirectToRoute('admin_users_index');
        }

        $this->addFlash('success', 'Users deleted.');
        return $this->redirectToRoute('admin_users_index');
    }

    private function assertAdmin(): void
    {
        if (!$this->isGranted(User::ROLE_ADMIN)) {
            throw $this->createAccessDeniedException('Only admins can manage users.');
        }
    }
}
