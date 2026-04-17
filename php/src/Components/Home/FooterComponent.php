<?php

declare(strict_types=1);

namespace App\Components\Home;

final class FooterComponent
{
    /**
     * @return array{site_name:string,author:string,year:int}
     */
    public function data(): array
    {
        return [
            'site_name' => 'Horyzont News',
            'author' => 'Damian Karpinski',
            'year' => (int) date('Y'),
        ];
    }
}
