# sysspec-dogwalk

The spec of record for a dog walking service, written from both sides of
the lead. Built on [sysspec](https://github.com/hungovercoders/sysspec):
AsyncAPI, OpenAPI, ODCS data contracts and Gherkin acceptance criteria as
enforceable system intent - versioned, gated, mocked and served over MCP.

## Two perspectives, two services

| Service | Perspective | Owns | Produces | Consumes |
| --- | --- | --- | --- | --- |
| [`bookings`](specs/bookings/) | The **owner** | Dog, Booking | `bookings.requested.v1`, `bookings.cancelled.v1` | `walks.accepted.v1`, `walks.started.v1`, `walks.completed.v1` |
| [`walks`](specs/walks/) | The **walker** | Walk | `walks.accepted.v1`, `walks.started.v1`, `walks.completed.v1` | `bookings.requested.v1`, `bookings.cancelled.v1` |

An owner registers a dog and requests a walk at a fixed price (40 pence a
minute). That `BookingRequested` event opens a walk carrying everything the
walker needs; a walker accepts it, starts it at pickup and completes it
with a report. Each of those steps comes back to the owner as an event, so
the booking always shows who has the dog and, at the end, how the walk
went. The walker's fee (80% of the price) rides on `WalkCompleted`, which
is what the daily payout data product is built from.

Each service carries an ungated `docs/` note explaining why its side is
modelled the way it is and what it deliberately leaves to the other.

```
specs/
├── bookings/                    the owner's perspective
│   ├── service.yaml             manifest: version, artifacts, produces, consumes
│   ├── openapi/                 registerDog, getDog, requestBooking, getBooking,
│   │                            cancelBooking, listOwnerBookings
│   ├── asyncapi/                BookingRequested, BookingCancelled
│   ├── features/                register-dog, request-walk, follow-booking
│   ├── data-contracts/          booking events history
│   └── docs/owner-perspective.md
└── walks/                       the walker's perspective
    ├── service.yaml
    ├── openapi/                 listWalks, getWalk, acceptWalk, startWalk, completeWalk
    ├── asyncapi/                WalkAccepted, WalkStarted, WalkCompleted
    ├── features/                pick-up-a-walk, walk-the-dog
    ├── data-contracts/          walk events history, daily walker payouts
    └── docs/walker-perspective.md
mocks/                           Microcks fixtures: <service>.rest|events.examples.yaml
```

## Working here

- `task ci` is the definition of green - the same gates run locally, in
  the pre-commit hook and in CI. `mise install` covers the toolchain; the
  mock cycle (`contract:test`, `mocks:test`) additionally needs a running
  Docker daemon. `task lint` and `task check` run everything else.
- Gated artifacts (contracts, data contracts, feature files) are never
  edited to make an implementation pass. Bump the artifact and service
  versions in `service.yaml` with every change; every schema element you
  add must be named in that service's features (`check:intent`); merges
  to main publish each changed service as a `<service>/v<version>` git
  tag that implementation and consumer repos pin.
- `task mocks:load` stands up Microcks mocks of both services so an
  owner app or a walker app can be built before either implementation
  exists.
- The machinery arrives by reference and stays current via Renovate: the
  `sysspec@` pin in `Taskfile.yml`, the `sysspec-mcp@` pin in
  `.mcp.json` (both npm), and the reusable workflows under
  `.github/workflows/`.
- Agents get the same specs over MCP (`.mcp.json`) and the deeper
  processes via the sysspec plugin's skills - install with
  `/plugin marketplace add hungovercoders/sysspec` then `/plugin install`,
  and ask to implement or consume a service. The `implement-service` and
  `consume-service` skills carry the whole loop, from contract pin to
  verified definition of done.

## Conventions

- Every event is a CloudEvents 1.0 structured envelope; `type` is
  `com.hungovercoders.<service>.<event>.v<major>` and the major lives in
  the channel address. Handlers dedupe on the envelope `id`.
- Attributes and enumerated values are `lower_snake_case`; money is an
  integer in pence (`price_pence`, `fee_pence`); ids are UUIDs; times are
  UTC `date-time`.
- Delivery is at-least-once and ordering holds only per aggregate id, so
  the owner's booking and the walker's walk each tolerate replays.
