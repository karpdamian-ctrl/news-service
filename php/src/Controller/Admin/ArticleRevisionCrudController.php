<?php

declare(strict_types=1);

namespace App\Controller\Admin;

use App\Entity\ArticleRevision;
use EasyCorp\Bundle\EasyAdminBundle\Controller\AbstractCrudController;
use EasyCorp\Bundle\EasyAdminBundle\Field\AssociationField;
use EasyCorp\Bundle\EasyAdminBundle\Field\DateTimeField;
use EasyCorp\Bundle\EasyAdminBundle\Field\IdField;
use EasyCorp\Bundle\EasyAdminBundle\Field\TextEditorField;
use EasyCorp\Bundle\EasyAdminBundle\Field\TextField;

/**
 * @extends AbstractCrudController<ArticleRevision>
 */
class ArticleRevisionCrudController extends AbstractCrudController
{
    public static function getEntityFqcn(): string
    {
        return ArticleRevision::class;
    }

    public function configureFields(string $pageName): iterable
    {
        return [
            IdField::new('id')->hideOnForm(),
            AssociationField::new('article'),
            AssociationField::new('changedBy'),
            TextField::new('title'),
            TextEditorField::new('description')->setRequired(false),
            TextEditorField::new('content'),
            TextField::new('changeNote')->setRequired(false),
            DateTimeField::new('createdAt')->hideOnForm(),
        ];
    }
}
