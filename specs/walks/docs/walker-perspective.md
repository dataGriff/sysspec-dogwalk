# The walker's perspective

A walker wants to find a dog to walk near them, claim it before someone
else does, and get paid when the walk is done. The `walks` service is that
perspective and nothing more.

## Why walks, not bookings

The walker never sees a "booking" - they see a **Walk**: something open to
be claimed, then theirs, then in progress, then done. One walk opens for
every `BookingRequested` event; it carries everything the walker needs
(dog name and size, the owner's instructions, pickup postcode, time,
length, and their fee) so nothing calls back into the bookings service.
The two services share no database.

## The fee

The walker's fee is 80% of the booking's `price_pence`, rounded down to
the penny, fixed when the walk opens. It is surfaced on the walk (so the
walker can see it before accepting) and carried on `WalkCompleted`, which
is the only event that earns it - accepted and started walks pay nothing.
The daily payout data product sums those completion events.

## What the walker never sees

- **Who else looked at the walk.** Acceptance is first-come, first-served
  at the API: the second `acceptWalk` is a 409. There is no offer or
  bidding round.
- **The owner's price.** The walk shows the fee, not the split.
- **A cancelled walk's reason.** `BookingCancelled` closes the walk
  whatever the reason; `walker_no_show` is recorded on the owner's side
  for future dispute handling, not enforced here.

## Ownership of the walk

Only the walker who accepted a walk can start it, and only the walker who
started it can complete it. A walker who is not the holder gets a 409, not
a 403, because the walk's state is the reason, not the caller's identity -
there is no authentication model in these contracts.
