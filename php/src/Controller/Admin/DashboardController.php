<?php

declare(strict_types=1);

namespace App\Controller\Admin;

use EasyCorp\Bundle\EasyAdminBundle\Attribute\AdminDashboard;
use EasyCorp\Bundle\EasyAdminBundle\Config\Action;
use EasyCorp\Bundle\EasyAdminBundle\Config\Assets;
use EasyCorp\Bundle\EasyAdminBundle\Config\Dashboard;
use EasyCorp\Bundle\EasyAdminBundle\Config\MenuItem;
use EasyCorp\Bundle\EasyAdminBundle\Controller\AbstractDashboardController;
use EasyCorp\Bundle\EasyAdminBundle\Router\AdminUrlGenerator;
use Symfony\Component\HttpFoundation\Response;

#[AdminDashboard(routePath: '/admin', routeName: 'admin')]
class DashboardController extends AbstractDashboardController
{
    public function __construct(private readonly AdminUrlGenerator $adminUrlGenerator)
    {
    }

    public function index(): Response
    {
        $url = $this->adminUrlGenerator
            ->setController(ArticleCrudController::class)
            ->generateUrl();

        return $this->redirect($url);
    }

    public function configureDashboard(): Dashboard
    {
        return Dashboard::new()->setTitle('News Admin');
    }

    public function configureAssets(): Assets
    {
        return Assets::new()
            ->addCssFile('styles/vendor/bootswatch-flatly.min.css')
            ->addCssFile('styles/admin-theme-overrides.css');
    }

    public function configureMenuItems(): iterable
    {
        yield MenuItem::linkToDashboard('Dashboard', 'fa fa-home');

        yield MenuItem::section('Content');
        yield MenuItem::linkToUrl('Articles', 'fa fa-newspaper', $this->crudIndexUrl(ArticleCrudController::class));
        yield MenuItem::linkToUrl('Categories', 'fa fa-folder', $this->crudIndexUrl(CategoryCrudController::class));
        yield MenuItem::linkToUrl('Tags', 'fa fa-tags', $this->crudIndexUrl(TagCrudController::class));
        yield MenuItem::linkToUrl('Media', 'fa fa-image', $this->crudIndexUrl(MediaCrudController::class));
        yield MenuItem::linkToUrl('Revisions', 'fa fa-clock-rotate-left', $this->crudIndexUrl(ArticleRevisionCrudController::class));

        yield MenuItem::section('Users');
        yield MenuItem::linkToUrl('Users', 'fa fa-user', $this->crudIndexUrl(UserCrudController::class));
        yield MenuItem::linkToRoute('Logout', 'fa fa-sign-out', 'app_logout');
    }

    private function crudIndexUrl(string $crudController): string
    {
        return $this->adminUrlGenerator
            ->unsetAll()
            ->setController($crudController)
            ->setAction(Action::INDEX)
            ->generateUrl();
    }
}
