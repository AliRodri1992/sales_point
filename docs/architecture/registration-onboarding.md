# Registration and onboarding architecture

## Responsibilities

- User: authentication and access identity.
- Employee: the employee/person record associated with an access account.
- Organization: the business organization.
- OrganizationMembership: the relationship between a user and an organization.
- SystemRole: authorization profile.
- Permission: an existing concrete permission in Delta POS.
- Branch: a real business branch.
- Terminal: a real POS terminal.
- OrganizationSetting: regional and operational organization settings.

## Registration

Registration is orchestrated by RegistrationService and runs in one database transaction. The service creates the organization, employee, user, membership, Administrator role assignment, initial branch, terminal configuration, and applicable migration/payment records.

The registering account is an employee. Administrator is a SystemRole, not a User user_type.

AdministratorPermissionProvisioner is idempotent and provisions the active permissions that already exist in the permission catalog. It does not invent future permissions.

## Onboarding

Onboarding is informational and progressive. Its overall percentage never gates access to the application. Individual modules may enforce their own operational prerequisites.

Progress is calculated from actual configuration rather than a stored global completion flag.

## Soft delete

The application uses Paranoia through ApplicationRecord. New recoverable domain records include deleted_at and are tested for deletion/restoration behavior.

## Code quality

Registration uses Service Objects for orchestration/provisioning and keeps the Devise controller thin. Domain rules remain in models and database constraints. The implementation follows the repository RuboCop configuration without disabling cops.
