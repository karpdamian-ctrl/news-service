<?php

declare(strict_types=1);

namespace App\Controller\Admin;

use App\Domain\Admin\ResourceCatalog;
use Symfony\Component\HttpFoundation\RedirectResponse;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/admin')]
final class DashboardController extends AbstractAdminController
{
    public function __construct(ResourceCatalog $catalog)
    {
        parent::__construct($catalog);
    }

    #[Route('', name: 'admin', methods: ['GET'])]
    public function index(): RedirectResponse
    {
        return $this->redirectToRoute('admin_articles_index');
    }
}
