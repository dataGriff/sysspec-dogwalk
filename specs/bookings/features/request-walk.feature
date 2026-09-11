Feature: Requesting a walk
  As a dog owner
  I want to request a walk for my dog at a time that suits me, and know the price up front
  So that a walker can pick it up

  These scenarios are acceptance criteria, not suggestions. An
  implementation that fails any of them is wrong. If a scenario is
  itself wrong, that is a versioned change to this file.

  Background:
    Given the owner "o-1001" exists
    And the owner has registered "Biscuit", a "medium" dog

  Scenario: A valid request is accepted and priced up front
    When the owner requests a 60 minute walk for "Biscuit" at 2026-09-14T09:00:00Z from pickup_postcode "CF10 1AA" via requestBooking
    Then the response status is 201
    And the booking status is "requested"
    And the booking price_pence is 2400, 40 pence per minute of duration_minutes
    And the booking carries the booking_id, owner_id, dog_id, scheduled_for, duration_minutes and pickup_postcode
    And a "BookingRequested" event is guaranteed to be published for the booking

  Scenario: The booking and its event succeed or fail together
    Given event publication is unavailable
    When the owner requests a 30 minute walk for "Biscuit"
    Then the response status is 201
    And the "BookingRequested" event is published once publication recovers
    And no booking ever exists without its "BookingRequested" event

  Scenario: Booking events are CloudEvents envelopes a walker can act on alone
    When the owner requests a 60 minute walk for "Biscuit" with instructions "Scared of bikes, keep to the park"
    Then a "BookingRequested" event is published on "bookings.requested.v1"
    And the envelope carries specversion "1.0", a unique id and a time
    And the envelope source is /bookings and its type is com.hungovercoders.bookings.requested.v1
    And the envelope subject is the booking_id, with datacontenttype "application/json"
    And the data carries the booking_id, owner_id, dog_id, scheduled_for, duration_minutes, pickup_postcode, price_pence and requested_at
    And the data carries the dog_name, dog_size and instructions so the walker needs no lookup
    And handlers dedupe on the envelope id, not the natural key

  Scenario: Replaying an idempotency key returns the original booking
    Given the owner requested a walk with "Idempotency-Key" header "idem-42"
    When the same request is retried with "Idempotency-Key" header "idem-42"
    Then the response status is 201
    And the same booking_id is returned
    And no second "BookingRequested" event is published

  Scenario: A conflicting body on a used idempotency key is rejected
    Given the owner requested a walk with "Idempotency-Key" header "idem-42"
    When a different booking body is sent with "Idempotency-Key" header "idem-42"
    Then the response status is 409
    And the problem body carries an error_code and message

  Scenario: A booking can be fetched by its id
    Given the owner requested a walk via requestBooking
    When the booking is fetched by booking_id via getBooking
    Then the response status is 200
    And the booking carries the booking_id, owner_id, dog_id, status, scheduled_for, duration_minutes, pickup_postcode, instructions and price_pence

  Scenario: Fetching an unknown booking returns 404
    When an unknown booking_id is fetched via getBooking
    Then the response status is 404
    And the problem body carries an error_code and message

  Scenario: An owner sees all their bookings
    Given the owner requested a 30 minute walk and a 60 minute walk
    When the owner's bookings are listed by owner_id via listOwnerBookings
    Then the response status is 200
    And the bookings list carries both bookings, newest scheduled_for first

  Scenario: An owner can filter their bookings by status
    Given the owner requested a walk and cancelled another
    When the owner's bookings are listed via listOwnerBookings with status "cancelled"
    Then the response status is 200
    And the bookings list carries only the cancelled booking

  Scenario Outline: A request must be for the owner's dog, in the future, of a bookable length
    When the owner requests a walk with <problem>
    Then the response status is 400
    And the problem body carries an error_code and message

    Examples:
      | problem                         |
      | a scheduled_for in the past     |
      | a duration_minutes of 15        |
      | a duration_minutes of 150       |
      | a dog_id the owner does not own |
      | an empty pickup_postcode        |
