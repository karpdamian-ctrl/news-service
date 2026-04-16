<?php

declare(strict_types=1);

namespace App\Command;

use App\Entity\Article;
use App\Entity\Category;
use App\Entity\Tag;
use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

#[AsCommand(name: 'app:seed-news', description: 'Seeds default users and starter news data')]
class SeedNewsCommand extends Command
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly UserPasswordHasherInterface $passwordHasher,
    ) {
        parent::__construct();
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $admin = $this->upsertUser(
            'admin@news.local',
            'admin123',
            'Admin',
            [User::ROLE_ADMIN]
        );

        $this->upsertUser(
            'redactor@news.local',
            'redactor123',
            'Redactor',
            [User::ROLE_REDACTOR]
        );

        $category = $this->upsertCategory('World');
        $tag = $this->upsertTag('Breaking');

        $article = $this->entityManager->getRepository(Article::class)->findOneBy(['slug' => 'welcome-news']);
        if (!$article instanceof Article) {
            $article = (new Article())
                ->setTitle('Welcome to the News Platform')
                ->setSlug('welcome-news')
                ->setDescription('Starter article generated from seed command')
                ->setContent('This is the first article created by the seed process.')
                ->setStatus(Article::STATUS_PUBLISHED)
                ->setAuthor($admin)
                ->setPublishedAt(new \DateTimeImmutable())
                ->setIsBreaking(true)
                ->setViewCount(0)
                ->addCategory($category)
                ->addTag($tag);

            $this->entityManager->persist($article);
        }

        $this->entityManager->flush();

        $output->writeln('Seed completed.');

        return Command::SUCCESS;
    }

    /**
     * @param list<string> $roles
     */
    private function upsertUser(string $email, string $password, string $displayName, array $roles): User
    {
        $user = $this->entityManager->getRepository(User::class)->findOneBy(['email' => $email]);

        if (!$user instanceof User) {
            $user = (new User())
                ->setEmail($email)
                ->setDisplayName($displayName)
                ->setRoles($roles)
                ->setIsActive(true);

            $user->setPassword($this->passwordHasher->hashPassword($user, $password));
            $this->entityManager->persist($user);

            return $user;
        }

        if ($user->getDisplayName() === '') {
            $user->setDisplayName($displayName);
        }

        if ($user->getPassword() === '') {
            $user->setPassword($this->passwordHasher->hashPassword($user, $password));
        }

        $user->setRoles($roles);

        return $user;
    }

    private function upsertCategory(string $name): Category
    {
        $slug = $this->slugify($name);

        $category = $this->entityManager->getRepository(Category::class)->findOneBy(['slug' => $slug]);
        if ($category instanceof Category) {
            return $category;
        }

        $category = (new Category())
            ->setName($name)
            ->setSlug($slug);

        $this->entityManager->persist($category);

        return $category;
    }

    private function upsertTag(string $name): Tag
    {
        $slug = $this->slugify($name);

        $tag = $this->entityManager->getRepository(Tag::class)->findOneBy(['slug' => $slug]);
        if ($tag instanceof Tag) {
            return $tag;
        }

        $tag = (new Tag())
            ->setName($name)
            ->setSlug($slug);

        $this->entityManager->persist($tag);

        return $tag;
    }

    private function slugify(string $text): string
    {
        $text = mb_strtolower(trim($text));
        $text = preg_replace('/[^a-z0-9]+/', '-', $text) ?? '';

        return trim($text, '-');
    }
}
