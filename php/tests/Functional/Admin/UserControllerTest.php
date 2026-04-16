<?php

declare(strict_types=1);

namespace App\Tests\Functional\Admin;

use App\Entity\User;
use App\Tests\Functional\DatabaseWebTestCase;

final class UserControllerTest extends DatabaseWebTestCase
{
    public function testAnonymousUserIsRedirectedToLoginWhenOpeningUsersAdmin(): void
    {
        $client = static::createClient();
        $client->request('GET', '/admin/users');

        self::assertResponseRedirects('/login');
    }

    public function testRedactorCannotAccessUsersAdmin(): void
    {
        $client = static::createClient();
        $redactor = $this->createUser('redactor@news.local', [User::ROLE_REDACTOR], 'Jan', 'Redaktor');

        $client->loginUser($redactor);
        $client->request('GET', '/admin/users');

        self::assertResponseStatusCodeSame(403);
    }

    public function testAdminCanSeeUsersWithoutTechnicalRoleInList(): void
    {
        $client = static::createClient();
        $admin = $this->createUser('admin@news.local', [User::ROLE_ADMIN], 'Adam', 'Admin');
        $this->createUser('editor@news.local', [User::ROLE_REDACTOR], 'Ewa', 'Editor');

        $client->loginUser($admin);
        $crawler = $client->request('GET', '/admin/users');

        self::assertResponseIsSuccessful();
        self::assertSame(2, $crawler->filter('table tbody tr')->count());
        self::assertSelectorTextContains('body', 'Adam');
        self::assertSelectorTextContains('body', 'Ewa');
        self::assertSelectorTextNotContains('body', 'ROLE_USER');
    }

    public function testAdminCanSearchUsersByQuery(): void
    {
        $client = static::createClient();
        $admin = $this->createUser('admin@news.local', [User::ROLE_ADMIN], 'Adam', 'Admin');
        $this->createUser('john@news.local', [User::ROLE_REDACTOR], 'John', 'Writer');
        $this->createUser('maria@news.local', [User::ROLE_REDACTOR], 'Maria', 'Editor');

        $client->loginUser($admin);
        $crawler = $client->request('GET', '/admin/users?q=john');

        self::assertResponseIsSuccessful();
        self::assertSame(1, $crawler->filter('table tbody tr')->count());
        self::assertSelectorTextContains('table tbody', 'john@news.local');
        self::assertSelectorTextNotContains('table tbody', 'maria@news.local');
    }

    public function testAdminCanUpdateUserToSingleBusinessRole(): void
    {
        $client = static::createClient();
        $admin = $this->createUser('admin@news.local', [User::ROLE_ADMIN], 'Adam', 'Admin');
        $target = $this->createUser('target@news.local', [User::ROLE_ADMIN], 'Target', 'User');

        $client->loginUser($admin);
        $client->request('POST', sprintf('/admin/users/%d/edit', (int) $target->getId()), [
            'email' => 'target@news.local',
            'firstName' => 'Target',
            'lastName' => 'Reporter',
            'roles' => [User::ROLE_REDACTOR],
            'isActive' => '1',
        ]);

        self::assertResponseRedirects('/admin/users');

        /** @var User|null $updated */
        $updated = self::entityManager()->getRepository(User::class)->find($target->getId());
        self::assertInstanceOf(User::class, $updated);
        self::assertSame('Target', $updated->getFirstName());
        self::assertSame('Reporter', $updated->getLastName());

        $businessRoles = array_values(array_filter(
            $updated->getRoles(),
            static fn (string $role): bool => $role !== 'ROLE_USER',
        ));

        self::assertSame([User::ROLE_REDACTOR], $businessRoles);
    }

    /**
     * @param list<string> $roles
     */
    private function createUser(string $email, array $roles, string $firstName, string $lastName): User
    {
        $user = (new User())
            ->setEmail($email)
            ->setFirstName($firstName)
            ->setLastName($lastName)
            ->setDisplayName(trim(sprintf('%s %s', $firstName, $lastName)))
            ->setRoles($roles)
            ->setIsActive(true)
            ->setCreatedAt(new \DateTimeImmutable())
            ->setUpdatedAt(new \DateTimeImmutable());

        $user->setPassword((string) password_hash('secret123', PASSWORD_BCRYPT));

        self::entityManager()->persist($user);
        self::entityManager()->flush();

        return $user;
    }
}
