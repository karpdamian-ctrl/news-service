<?php

declare(strict_types=1);

namespace App\Command;

use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

#[AsCommand(name: 'app:seed-users', description: 'Seed only admin and redactor users')]
final class SeedUsersCommand extends Command
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly UserPasswordHasherInterface $passwordHasher,
    ) {
        parent::__construct();
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        [$adminFirstName, $adminLastName] = $this->seededName('admin@news.local');
        [$redactorFirstName, $redactorLastName] = $this->seededName('redactor@news.local');

        $this->upsertUser('admin@news.local', 'admin123', $adminFirstName, $adminLastName, [User::ROLE_ADMIN]);
        $this->upsertUser('redactor@news.local', 'redactor123', $redactorFirstName, $redactorLastName, [User::ROLE_REDACTOR]);

        $this->entityManager->flush();
        $output->writeln('<info>Users seeded: admin + redactor</info>');

        return Command::SUCCESS;
    }

    /**
     * @param list<string> $roles
     */
    private function upsertUser(string $email, string $plainPassword, string $firstName, string $lastName, array $roles): void
    {
        $repository = $this->entityManager->getRepository(User::class);
        $user = $repository->findOneBy(['email' => $email]);

        if (!$user instanceof User) {
            $user = (new User())->setEmail($email);
            $this->entityManager->persist($user);
            $user->setCreatedAt(new \DateTimeImmutable());
        }

        $user
            ->setFirstName($firstName)
            ->setLastName($lastName)
            ->setDisplayName(trim(sprintf('%s %s', $firstName, $lastName)))
            ->setRoles($roles)
            ->setIsActive(true)
            ->setPassword($this->passwordHasher->hashPassword($user, $plainPassword))
            ->setUpdatedAt(new \DateTimeImmutable());
    }

    /**
     * @return array{0: string, 1: string}
     */
    private function seededName(string $email): array
    {
        $firstNames = ['Maja', 'Antoni', 'Zofia', 'Igor', 'Aleksandra', 'Marek', 'Klara', 'Jakub'];
        $lastNames = ['Kowalska', 'Nowak', 'Wisniewski', 'Wojcik', 'Kaminska', 'Lewandowski', 'Mazur', 'Dabrowska'];

        $seed = abs((int) crc32($email));
        $firstName = $firstNames[$seed % count($firstNames)];
        $lastName = $lastNames[$seed % count($lastNames)];

        return [$firstName, $lastName];
    }
}
