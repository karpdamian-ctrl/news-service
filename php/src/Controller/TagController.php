<?php

declare(strict_types=1);

namespace App\Controller;

use App\Components\Home\FooterComponent;
use App\Components\Home\HeaderComponent;
use App\Components\Tag\TagArticlesListingComponent;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

final class TagController extends AbstractController
{
    public function __construct(
        private readonly HeaderComponent $headerComponent,
        private readonly FooterComponent $footerComponent,
        private readonly TagArticlesListingComponent $listingComponent,
    ) {
    }

    #[Route('/tag/{slug}', name: 'app_tag_show', methods: ['GET'])]
    public function show(string $slug): Response
    {
        $header = $this->headerComponent->data();
        $footer = $this->footerComponent->data();
        $listing = $this->listingComponent->data($slug);

        $status = $listing['not_found'] ? Response::HTTP_NOT_FOUND : Response::HTTP_OK;

        return $this->render('tag/show.html.twig', [
            'components' => [
                'header' => $header,
                'footer' => $footer,
                'listing' => $listing,
            ],
            'errors' => $listing['errors'] ?? [],
        ], new Response(status: $status));
    }
}
