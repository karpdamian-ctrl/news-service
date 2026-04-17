<?php

declare(strict_types=1);

namespace App\Controller;

use App\Components\Article\ArticleDetailsComponent;
use App\Components\Home\FooterComponent;
use App\Components\Home\HeaderComponent;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

final class ArticleController extends AbstractController
{
    public function __construct(
        private readonly HeaderComponent $headerComponent,
        private readonly FooterComponent $footerComponent,
        private readonly ArticleDetailsComponent $detailsComponent,
    ) {
    }

    #[Route('/article/{slug}', name: 'app_article_show', methods: ['GET'])]
    public function show(string $slug): Response
    {
        $header = $this->headerComponent->data();
        $footer = $this->footerComponent->data();
        $details = $this->detailsComponent->data($slug);

        $status = $details['not_found'] ? Response::HTTP_NOT_FOUND : Response::HTTP_OK;

        return $this->render('article/show.html.twig', [
            'components' => [
                'header' => $header,
                'footer' => $footer,
                'article' => $details['article'],
            ],
            'errors' => $details['errors'] ?? [],
        ], new Response(status: $status));
    }
}
