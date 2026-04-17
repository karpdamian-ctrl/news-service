<?php

namespace App\Controller;

use App\Components\Home\FooterComponent;
use App\Components\Home\HeaderComponent;
use App\Components\Home\HeroComponent;
use App\Components\Home\LatestListingComponent;
use App\Components\Home\MostViewedListingComponent;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

final class HomeController extends AbstractController
{
    public function __construct(
        private readonly HeaderComponent $headerComponent,
        private readonly HeroComponent $heroComponent,
        private readonly LatestListingComponent $latestListingComponent,
        private readonly MostViewedListingComponent $mostViewedListingComponent,
        private readonly FooterComponent $footerComponent,
    ) {}

    #[Route('/', name: 'app_home', methods: ['GET'])]
    public function __invoke(): Response
    {
        $header = $this->headerComponent->data();
        $hero = $this->heroComponent->data();
        $latest = $this->latestListingComponent->data();
        $mostViewed = $this->mostViewedListingComponent->data();
        $footer = $this->footerComponent->data();

        return $this->render('home/index.html.twig', [
            'components' => [
                'header' => $header,
                'hero' => $hero,
                'latest' => $latest,
                'most_viewed' => $mostViewed,
                'footer' => $footer,
            ],
            'errors' => array_values(array_unique(array_merge(
                $hero['errors'] ?? [],
                $latest['errors'] ?? [],
                $mostViewed['errors'] ?? []
            ))),
        ]);
    }
}
