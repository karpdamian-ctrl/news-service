<?php

declare(strict_types=1);

namespace App\Domain\Admin;

use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Doctrine\ORM\QueryBuilder;
use Psr\Log\LoggerInterface;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

final class UserDomainService
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly UserPasswordHasherInterface $passwordHasher,
        private readonly LoggerInterface $logger,
    ) {
    }

    /**
     * @return array{
     *   items: array<int, array<string, mixed>>,
     *   meta: array{
     *     page:int,
     *     per_page:int,
     *     total_count:int,
     *     total_pages:int,
     *     has_prev_page:bool,
     *     has_next_page:bool
     *   }
     * }
     */
    public function listItems(
        int $page = 1,
        int $perPage = 50,
        ?string $sort = null,
        ?string $order = null,
        ?string $query = null
    ): array
    {
        $page = max(1, $page);
        $perPage = max(1, min(100, $perPage));
        $sort = $this->normalizeSort($sort);
        $order = $this->normalizeOrder($order);
        $query = is_string($query) ? trim($query) : '';

        $repo = $this->entityManager->getRepository(User::class);
        $countQb = $repo->createQueryBuilder('u')->select('COUNT(u.id)');
        $this->applySearch($countQb, $query);
        $totalCount = (int) $countQb->getQuery()->getSingleScalarResult();
        $totalPages = max(1, (int) ceil($totalCount / $perPage));
        $page = min($page, $totalPages);
        $offset = ($page - 1) * $perPage;

        $qb = $repo->createQueryBuilder('u');
        $this->applySearch($qb, $query);
        $qb
            ->orderBy(sprintf('u.%s', $sort), strtoupper($order))
            ->setFirstResult($offset)
            ->setMaxResults($perPage);

        /** @var list<User> $users */
        $users = $qb->getQuery()->getResult();
        $items = [];

        foreach ($users as $user) {
            if ($user instanceof User) {
                $items[] = $this->toListItem($user);
            }
        }

        return [
            'items' => $items,
            'meta' => [
                'page' => $page,
                'per_page' => $perPage,
                'total_count' => $totalCount,
                'total_pages' => $totalPages,
                'sort' => $sort,
                'order' => $order,
                'q' => $query,
                'has_prev_page' => $page > 1,
                'has_next_page' => $page < $totalPages,
            ],
        ];
    }

    public function find(int $id): ?User
    {
        $candidate = $this->entityManager->getRepository(User::class)->find($id);
        return $candidate instanceof User ? $candidate : null;
    }

    /**
     * @return array<string, mixed>
     */
    public function toListItem(User $user): array
    {
        return [
            'id' => $user->getId(),
            'email' => $user->getEmail(),
            'firstName' => $user->getFirstName(),
            'lastName' => $user->getLastName(),
            'roles' => $this->businessRoles($user),
            'isActive' => $user->isActive(),
            'updatedAt' => $user->getUpdatedAt()->format(\DateTimeInterface::ATOM),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function toFormValues(User $user): array
    {
        return [
            'email' => $user->getEmail(),
            'firstName' => $user->getFirstName(),
            'lastName' => $user->getLastName(),
            'roles' => $this->businessRoles($user),
            'isActive' => $user->isActive(),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function toDetailItem(User $user): array
    {
        return [
            'id' => $user->getId(),
            'email' => $user->getEmail(),
            'firstName' => $user->getFirstName(),
            'lastName' => $user->getLastName(),
            'roles' => $this->businessRoles($user),
            'isActive' => $user->isActive(),
            'createdAt' => $user->getCreatedAt()->format(\DateTimeInterface::ATOM),
            'updatedAt' => $user->getUpdatedAt()->format(\DateTimeInterface::ATOM),
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<int, string>
     */
    public function create(array $payload): array
    {
        $email = isset($payload['email']) && is_string($payload['email']) ? trim(mb_strtolower($payload['email'])) : '';
        $firstName = isset($payload['firstName']) && is_string($payload['firstName']) ? trim($payload['firstName']) : '';
        $lastName = isset($payload['lastName']) && is_string($payload['lastName']) ? trim($payload['lastName']) : '';
        $password = isset($payload['password']) && is_string($payload['password']) ? $payload['password'] : '';
        $roles = isset($payload['roles']) && is_array($payload['roles']) ? $payload['roles'] : [];
        $isActive = array_key_exists('isActive', $payload) ? (bool) $payload['isActive'] : true;

        $errors = [];
        if ($email === '') {
            $errors[] = 'email: is required';
        }
        if ($firstName === '') {
            $errors[] = 'firstName: is required';
        }
        if ($lastName === '') {
            $errors[] = 'lastName: is required';
        }
        if ($password === '') {
            $errors[] = 'password: is required';
        }
        if ($this->entityManager->getRepository(User::class)->findOneBy(['email' => $email]) instanceof User) {
            $errors[] = 'email: already exists';
        }
        if ($errors !== []) {
            return $errors;
        }

        $user = (new User())
            ->setEmail($email)
            ->setFirstName($firstName)
            ->setLastName($lastName)
            ->setDisplayName($this->buildDisplayName($firstName, $lastName))
            ->setRoles($this->sanitizeRoles($roles))
            ->setIsActive($isActive)
            ->setCreatedAt(new \DateTimeImmutable())
            ->setUpdatedAt(new \DateTimeImmutable());

        $user->setPassword($this->passwordHasher->hashPassword($user, $password));

        $this->entityManager->persist($user);
        $this->entityManager->flush();

        return [];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<int, string>
     */
    public function update(User $user, array $payload, ?User $actor): array
    {
        $before = $this->auditSnapshot($user);

        $email = isset($payload['email']) && is_string($payload['email']) ? trim(mb_strtolower($payload['email'])) : $user->getEmail();
        $firstName = isset($payload['firstName']) && is_string($payload['firstName']) ? trim($payload['firstName']) : $user->getFirstName();
        $lastName = isset($payload['lastName']) && is_string($payload['lastName']) ? trim($payload['lastName']) : $user->getLastName();
        $password = isset($payload['password']) && is_string($payload['password']) ? $payload['password'] : '';
        $roles = isset($payload['roles']) && is_array($payload['roles']) ? $payload['roles'] : $user->getRoles();
        $isActive = array_key_exists('isActive', $payload) ? (bool) $payload['isActive'] : $user->isActive();

        $errors = [];
        if ($email === '') {
            $errors[] = 'email: is required';
        }
        if ($firstName === '') {
            $errors[] = 'firstName: is required';
        }
        if ($lastName === '') {
            $errors[] = 'lastName: is required';
        }

        $existing = $this->entityManager->getRepository(User::class)->findOneBy(['email' => $email]);
        if ($existing instanceof User && $existing->getId() !== $user->getId()) {
            $errors[] = 'email: already exists';
        }
        if ($errors !== []) {
            return $errors;
        }

        $user
            ->setEmail($email)
            ->setFirstName($firstName)
            ->setLastName($lastName)
            ->setDisplayName($this->buildDisplayName($firstName, $lastName))
            ->setRoles($this->sanitizeRoles($roles))
            ->setIsActive($isActive)
            ->setUpdatedAt(new \DateTimeImmutable());

        if ($password !== '') {
            $user->setPassword($this->passwordHasher->hashPassword($user, $password));
        }

        $this->entityManager->flush();
        $this->logUpdatedAudit($user, $before, $actor);

        return [];
    }

    public function delete(User $target, ?User $actor): ?string
    {
        if ($actor instanceof User && $actor->getId() === $target->getId()) {
            return 'You cannot delete your own account.';
        }

        $this->entityManager->remove($target);
        $this->entityManager->flush();

        return null;
    }

    /**
     * @return array<string, mixed>
     */
    private function auditSnapshot(User $user): array
    {
        return [
            'id' => $user->getId(),
            'email' => $user->getEmail(),
            'first_name' => $user->getFirstName(),
            'last_name' => $user->getLastName(),
            'display_name' => $user->getDisplayName(),
            'roles' => $this->businessRoles($user),
            'is_active' => $user->isActive(),
        ];
    }

    /**
     * @param array<string, mixed> $before
     */
    private function logUpdatedAudit(User $user, array $before, ?User $actor): void
    {
        $after = $this->auditSnapshot($user);
        $changes = [];

        foreach (['email', 'first_name', 'last_name', 'display_name', 'roles', 'is_active'] as $field) {
            $beforeValue = $before[$field] ?? null;
            $afterValue = $after[$field] ?? null;
            if ($beforeValue !== $afterValue) {
                $changes[$field] = ['from' => $beforeValue, 'to' => $afterValue];
            }
        }

        $actorIdentity = 'anonymous';
        if ($actor instanceof User) {
            $actorIdentity = trim(sprintf('%s %s', $actor->getFirstName(), $actor->getLastName()));
            if ($actorIdentity === '') {
                $actorIdentity = $actor->getEmail();
            }
        }

        $payload = [
            'event' => 'admin.user.updated',
            'resource' => 'users',
            'operation' => 'update',
            'actor' => $actorIdentity,
            'target_user_id' => $user->getId(),
            'changes' => $changes,
            'updated_at' => (new \DateTimeImmutable())->format(\DateTimeInterface::ATOM),
        ];

        $this->logger->info(sprintf('USER_AUDIT %s', (string) json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)));
    }

    private function normalizeSort(?string $sort): string
    {
        return match ($sort) {
            'id' => 'id',
            'email' => 'email',
            'firstName' => 'firstName',
            'lastName' => 'lastName',
            'isActive' => 'isActive',
            'updatedAt' => 'updatedAt',
            default => 'id',
        };
    }

    private function normalizeOrder(?string $order): string
    {
        return strtolower((string) $order) === 'asc' ? 'asc' : 'desc';
    }

    private function applySearch(QueryBuilder $qb, string $query): void
    {
        if ($query === '') {
            return;
        }

        $needle = '%' . mb_strtolower($query) . '%';
        $qb
            ->andWhere(
                $qb->expr()->orX(
                    'LOWER(u.email) LIKE :q',
                    'LOWER(u.firstName) LIKE :q',
                    'LOWER(u.lastName) LIKE :q',
                    'LOWER(u.displayName) LIKE :q'
                )
            )
            ->setParameter('q', $needle);
    }

    /**
     * @param array<int, mixed> $roles
     * @return array<int, string>
     */
    private function sanitizeRoles(array $roles): array
    {
        $allowed = [User::ROLE_ADMIN, User::ROLE_REDACTOR];
        $normalized = array_values(array_filter(array_map(static fn ($role) => is_string($role) ? $role : '', $roles)));
        $normalized = array_values(array_intersect($normalized, $allowed));

        if (in_array(User::ROLE_ADMIN, $normalized, true)) {
            return [User::ROLE_ADMIN];
        }
        if (in_array(User::ROLE_REDACTOR, $normalized, true)) {
            return [User::ROLE_REDACTOR];
        }
        if ($normalized === []) {
            return [User::ROLE_REDACTOR];
        }

        return $normalized;
    }

    private function buildDisplayName(string $firstName, string $lastName): string
    {
        $displayName = trim(sprintf('%s %s', trim($firstName), trim($lastName)));
        return $displayName !== '' ? $displayName : 'Unknown User';
    }

    /**
     * @return list<string>
     */
    private function businessRoles(User $user): array
    {
        return array_values(array_filter(
            $user->getRoles(),
            static fn (string $role): bool => $role !== 'ROLE_USER',
        ));
    }
}
