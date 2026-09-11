Feature: Cancelling and following a booking
  As a dog owner
  I want to cancel a walk I no longer need, and follow a booked walk as it happens
  So that I always know who has my dog and how the walk went

  These scenarios are acceptance criteria, not suggestions. An
  implementation that fails any of them is wrong. If a scenario is
  itself wrong, that is a versioned change to this file.

  Background:
    Given the owner "o-1001" exists
    And the owner requested a 60 minute walk for "Biscuit"

  Scenario: A requested booking can be cancelled
    When the owner cancels the booking because "owner_request" via cancelBooking
    Then the response status is 200
    And the booking status is "cancelled"
    And a "BookingCancelled" event is published on "bookings.cancelled.v1"
    And its data carries the booking_id, cancelled_at and reason

  Scenario: Cancellation is a CloudEvents envelope too
    When the owner cancels the booking because "dog_unwell" via cancelBooking
    Then a "BookingCancelled" event is published on "bookings.cancelled.v1"
    And the envelope carries specversion "1.0", a unique id and a time
    And the envelope source is /bookings and its type is com.hungovercoders.bookings.cancelled.v1
    And the envelope subject is the booking_id, with datacontenttype "application/json"

  Scenario: An accepted booking can still be cancelled
    Given a "WalkAccepted" event arrived on "walks.accepted.v1" for that booking_id
    When the owner cancels the booking because "owner_request" via cancelBooking
    Then the response status is 200
    And the booking status is "cancelled"

  Scenario: A walk that is already in progress cannot be cancelled
    Given a "WalkStarted" event arrived on "walks.started.v1" for that booking_id
    When the owner cancels the booking because "owner_request" via cancelBooking
    Then the response status is 409
    And the problem body carries an error_code and message
    And no "BookingCancelled" event is published

  Scenario: A completed walk cannot be cancelled
    Given a "WalkCompleted" event arrived on "walks.completed.v1" for that booking_id
    When the owner cancels the booking because "walker_no_show" via cancelBooking
    Then the response status is 409
    And the problem body carries an error_code and message

  Scenario: A no-show needs a walker who was due
    Given no walker has accepted the booking
    When the owner cancels the booking because "walker_no_show" via cancelBooking
    Then the response status is 400
    And the problem body carries an error_code and message

  Scenario: A no-show can be reported once a walker had accepted
    Given a "WalkAccepted" event arrived on "walks.accepted.v1" for that booking_id
    When the owner cancels the booking because "walker_no_show" via cancelBooking
    Then the response status is 200
    And the booking status is "cancelled"
    And the "BookingCancelled" event data reason is "walker_no_show"

  Scenario: Cancelling an unknown booking returns 404
    When an unknown booking_id is cancelled via cancelBooking
    Then the response status is 404
    And the problem body carries an error_code and message

  Scenario: An accepted walk shows the owner who is coming
    When a "WalkAccepted" event arrives on "walks.accepted.v1" for that booking_id
    Then the booking status is "accepted"
    And the booking carries the walker_id and walker_name from the event
    And replaying the same envelope id does not change the booking again

  Scenario: A started walk is in progress
    Given a "WalkAccepted" event arrived on "walks.accepted.v1" for that booking_id
    When a "WalkStarted" event arrives on "walks.started.v1" for that booking_id
    Then the booking status is "in_progress"

  Scenario: A completed walk brings its report to the owner
    Given a "WalkStarted" event arrived on "walks.started.v1" for that booking_id
    When a "WalkCompleted" event arrives on "walks.completed.v1" for that booking_id
    Then the booking status is "completed"
    And the booking report carries the walked_minutes, distance_metres, pee_count, poo_count and notes from the event
