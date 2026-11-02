# Skeleton Loading in Delta POS

This implementation is deliberately scoped to asynchronous content rather than
adding a global fake loading screen.

## Components

Use `Ui::SkeletonComponent.new(variant:, rows:, columns:)` to represent
an unpopulated asynchronous region. Available variants: `table`, `card`,
`dashboard`, `form`, `detail` and `list`. The component is decorative
(`aria-hidden`) and contains no focusable elements.

The CSS includes a subtle shimmer, dark-theme placeholders and a
`prefers-reduced-motion` fallback.

## Integration

`skeleton-loading` is a Stimulus controller on a stable wrapper around an
existing Turbo Frame. The wrapper supplies a content target, a hidden
placeholder target and optional localized status and error targets. It
listens for Turbo fetch/frame events and preserves existing rows during refresh.

For custom fetch clients, dispatch `skeleton:begin` and `skeleton:end`
on `document`, with matching `region` and `requestId` values. Only the
most recently started request can end the loading state.

Currently integrated in seven asynchronous catalogs: suppliers, products,
categories, languages, branches, users and clients. Supplier contact and
address pages also use card-shaped skeletons on cold pagination and preserve
previous records during filter requests.

## When NOT to add one

Do not use a skeleton for immediately rendered server-side pages (including
the current dashboard), for synchronous forms, or for CRUD submissions.
Continue using button-level progress and the existing confirmed-action loader.
Do not introduce delays to make a skeleton visible.

## Testing

Component specs cover the six layouts, placeholders and parameter limits.
Browser feature specs cover preservation of existing results, an empty-region
placeholder, out-of-order requests and Turbo Frame targeting. Run the
project's regular asset build, RSpec, RuboCop, I18n and security checks.
