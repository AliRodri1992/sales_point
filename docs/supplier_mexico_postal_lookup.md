# Assisted Mexican postal code entry

Supplier address forms offer optional suggestions for Mexican five-digit postal codes.

- The Rails endpoint queries **only** the postal code against the Sepomex-compatible
  API, not the supplier name, street or full address.
- Default provider: `https://sepomex.kurenn.dev`, a free community service with
  rate limits and no service-level guarantee. Override `SEPOMEX_API_URL` to point
  to a trusted or self-hosted instance in production.
- Lookup requests are bounded by four seconds, cached for one day on success,
  and return HTTP 503 when unavailable. An unavailable service never prevents
  the user from typing state, municipality or colonia manually.
- State and municipality are offered only for Mexico and autofilled only when
  empty or previously autofilled. Colonia choices use the native editable
  `datalist`; the user can always type another value.
- Country flags are **249 locally tracked SVG files**, sourced from flag-icons
  (MIT; see `app/assets/images/flags/LICENSE.flag-icons`). No flag CDN is used
  in the interface.
- Postal suggestions are not evidence of geocoding or geographic verification.
