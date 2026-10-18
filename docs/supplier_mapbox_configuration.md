# Mapbox for supplier locations

The supplier address editor uses the existing `MAPBOX_TOKEN` environment variable on the Rails server to:

- Geocode the **full postal address** and return approximate suggested coordinates.
- Serve static map imagery through the authenticated Rails proxy.
- Let authorized users adjust and confirm the suggested marker.

## Configure a local Docker development environment

Add this entry to the **local, gitignored** `.env.development` file:

```dotenv
MAPBOX_TOKEN=<your Mapbox access token>
```

Do not commit your token, paste it into Rails views or Stimulus, or add it to this
documentation. Both `web` and `sidekiq` receive `.env.development` through
`docker-compose.dev.yml`.

After editing the environment file, **recreate** both containers (a restart alone
does not necessarily reload environment variables):

```sh
docker compose -f docker-compose.dev.yml up -d --force-recreate web sidekiq
docker compose -f docker-compose.dev.yml exec web bin/rails runner 'puts ENV["MAPBOX_TOKEN"].present?'
```

The second command must print `true`, but never prints the token.

A token beginning with `pk.` is a Mapbox **public access token**. Choose a
separate token for Delta POS with least-privilege scopes; configure URL restrictions
only if compatible with requests from your server-side proxy. Requests from the
server have different restriction behavior than browser requests.

## Production considerations

- Mapbox geocoding has temporary-vs-permanent data usage restrictions. **Coordinates
  intended for persistent storage require an eligible Permanent Geocoding setup**.
  Check the account's Mapbox terms/entitlement before using persisted coordinates.
- Geocoding may return an approximate position. A suggested point is not a
  user-confirmed address. If Mapbox is unavailable, postal/address entry stays
  usable without confirmation.
- Limit token scopes and enable Mapbox budget/usage alerts. Rotate the token if
  you believe it has been misused.
