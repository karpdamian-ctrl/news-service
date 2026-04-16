<?php

declare(strict_types=1);

namespace App\Domain\Admin;

interface ResourceCatalogProvider
{
    /**
     * @return array<string, array<string, mixed>>
     */
    public function resources(): array;

    /**
     * @return array<string, array{index:string,new:?string,edit:?string,delete:?string,show:?string}>
     */
    public function routes(): array;
}
