# The owner's perspective

An owner wants three things: to book a walk for *their* dog at a time that
suits them, to know what it costs before they commit, and - once the dog is
out of the door - to know who has it and how the walk went. The `bookings`
service is that perspective and nothing more.

## Why bookings, not walks

The owner never "does" the walk. They request one, they can change their
mind, and they watch. So the aggregate the owner owns is the **Booking**: a
request with a fixed price, a status, and, later, a walker's name and a
report. Everything the walker does lives in the `walks` service and reaches
the owner as events (`walks.accepted.v1`, `walks.started.v1`,
`walks.completed.v1`). The two services share no database and neither calls
the other synchronously.

## What the request event carries, and why

`BookingRequested` is deliberately fat. It carries the dog's name and size
and the owner's instructions alongside the ids, so a walker can decide on
and do the walk from the event alone. The alternative - the walks service
calling back into bookings for dog details - would couple the walker's
critical path to the owner's service being up. A dog's size is not going to
change between request and pickup; if it does, that is a new booking.

## Pricing

Price is fixed at request time (40 pence per minute) and carried on the
booking and the event. The walker's fee (80% of it) is the walks service's
business, derived from `price_pence` when the walk opens - the owner never
sees the split.

## The cancellation line

An owner can cancel while the booking is `requested` or `accepted`. Once a
`WalkStarted` event has arrived the dog is on the lead and cancellation is
a 409. `walker_no_show` is a cancellation reason the owner can give on an
accepted walk whose walker never turned up; it is recorded on the event
for the walker side to act on, but there is no penalty logic here.
