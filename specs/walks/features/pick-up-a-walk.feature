Feature: Picking up a walk
  As a dog walker
  I want to see the walks owners have requested and claim one
  So that I have a dog to walk and the owner knows who is coming

  These scenarios are acceptance criteria, not suggestions. An
  implementation that fails any of them is wrong. If a scenario is
  itself wrong, that is a versioned change to this file.

  Background:
    Given the walker "w-2001" exists

  Scenario: A requested booking opens a walk
    When a "BookingRequested" event arrives on "bookings.requested.v1" for a 60 minute walk priced at 2400 pence
    Then a walk exists for that booking_id with status "open"
    And the walk carries a walk_id and the owner_id, dog_id, dog_name, dog_size, scheduled_for, duration_minutes, pickup_postcode and instructions from the event
    And the walk fee_pence is 1920, 80 percent of the booking's price_pence
    And replaying the same envelope id does not open a second walk

  Scenario: A walker browses the open walks
    Given walks are open for "Biscuit" and "Rex"
    And the walk for "Bruno" has already been accepted by another walker
    When the walks are listed via listWalks with status "open"
    Then the response status is 200
    And the walks list carries the walks for "Biscuit" and "Rex" only, soonest scheduled_for first

  Scenario: A walker accepts an open walk
    Given a walk is open for "Biscuit"
    When the walker accepts it with their walker_id and walker_name via acceptWalk
    Then the response status is 200
    And the walk status is "accepted"
    And the walk carries the walker_id and walker_name
    And a "WalkAccepted" event is guaranteed to be published for the walk

  Scenario: Acceptance is a CloudEvents envelope
    Given a walk is open for "Biscuit"
    When the walker accepts it via acceptWalk
    Then a "WalkAccepted" event is published on "walks.accepted.v1"
    And the envelope carries specversion "1.0", a unique id and a time
    And the envelope source is /walks and its type is com.hungovercoders.walks.accepted.v1
    And the envelope subject is the walk_id, with datacontenttype "application/json"
    And the data carries the walk_id, booking_id, walker_id, walker_name and accepted_at
    And handlers dedupe on the envelope id, not the natural key

  Scenario: Only one walker can hold a walk
    Given the walker "w-2002" already accepted the walk for "Biscuit"
    When the walker accepts the same walk via acceptWalk
    Then the response status is 409
    And the problem body carries an error_code and message
    And no second "WalkAccepted" event is published

  Scenario: A cancelled booking closes its walk
    Given a walk is open for "Biscuit"
    When a "BookingCancelled" event arrives on "bookings.cancelled.v1" for that booking_id
    Then the walk status is "cancelled"
    And accepting it via acceptWalk returns 409

  Scenario: A cancelled booking takes an accepted walk off the walker
    Given the walker accepted the walk for "Biscuit"
    When a "BookingCancelled" event arrives on "bookings.cancelled.v1" for that booking_id
    Then the walk status is "cancelled"
    And starting it via startWalk returns 409

  Scenario: A walker sees their own walks
    Given the walker accepted the walks for "Biscuit" and "Rex"
    And a walk is open for "Bruno"
    When the walks are listed via listWalks with their walker_id
    Then the response status is 200
    And the walks list carries only the walks for "Biscuit" and "Rex"

  Scenario: A walk can be fetched by its id
    Given a walk is open for "Biscuit"
    When the walk is fetched by walk_id via getWalk
    Then the response status is 200
    And the walk carries the walk_id, booking_id, owner_id, dog_id, dog_name, dog_size, status, scheduled_for, duration_minutes, pickup_postcode and fee_pence

  Scenario: Fetching an unknown walk returns 404
    When an unknown walk_id is fetched via getWalk
    Then the response status is 404
    And the problem body carries an error_code and message
