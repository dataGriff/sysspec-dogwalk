Feature: Walking the dog
  As a dog walker
  I want to start the walk at pickup and report on it when I bring the dog home
  So that the owner can follow the walk and I get paid for it

  These scenarios are acceptance criteria, not suggestions. An
  implementation that fails any of them is wrong. If a scenario is
  itself wrong, that is a versioned change to this file.

  Background:
    Given the walker "w-2001" exists
    And the walker accepted the 60 minute walk for "Biscuit"

  Scenario: The walk starts at pickup
    When the walker starts the walk via startWalk
    Then the response status is 200
    And the walk status is "in_progress"
    And the walk carries a started_at
    And a "WalkStarted" event is published on "walks.started.v1"
    And its data carries the walk_id, booking_id, walker_id and started_at

  Scenario: Start is a CloudEvents envelope
    When the walker starts the walk via startWalk
    Then a "WalkStarted" event is published on "walks.started.v1"
    And the envelope carries specversion "1.0", a unique id and a time
    And the envelope source is /walks and its type is com.hungovercoders.walks.started.v1
    And the envelope subject is the walk_id, with datacontenttype "application/json"

  Scenario: Only the walker who accepted the walk can start it
    When the walker "w-2002" starts the walk via startWalk
    Then the response status is 409
    And the problem body carries an error_code and message
    And no "WalkStarted" event is published

  Scenario: A walk cannot start before it is accepted
    Given a walk is still open for "Rex"
    When the walker starts that walk via startWalk
    Then the response status is 409
    And the problem body carries an error_code and message

  Scenario: The walk is completed with a report for the owner
    Given the walker started the walk at 2026-09-14T09:02:00Z
    When the walker completes it at 2026-09-14T10:01:00Z with 3200 distance_metres, 2 pee_count, 1 poo_count and notes "Lovely walk, chased a squirrel" via completeWalk
    Then the response status is 200
    And the walk status is "completed"
    And the walk carries a completed_at and a report with the distance_metres, pee_count, poo_count and notes
    And a "WalkCompleted" event is guaranteed to be published for the walk

  Scenario: The walk and its completion event succeed or fail together
    Given the walker started the walk
    And event publication is unavailable
    When the walker completes it via completeWalk
    Then the response status is 200
    And the "WalkCompleted" event is published once publication recovers
    And no completed walk ever exists without its "WalkCompleted" event

  Scenario: Completion is a CloudEvents envelope that carries the walker's fee
    Given the walker started the walk at 2026-09-14T09:02:00Z
    When the walker completes it at 2026-09-14T10:01:00Z via completeWalk
    Then a "WalkCompleted" event is published on "walks.completed.v1"
    And the envelope carries specversion "1.0", a unique id and a time
    And the envelope source is /walks and its type is com.hungovercoders.walks.completed.v1
    And the envelope subject is the walk_id, with datacontenttype "application/json"
    And the data carries the walk_id, booking_id, walker_id, completed_at, distance_metres, pee_count, poo_count and notes
    And the data walked_minutes is 59, from started_at to completed_at
    And the data fee_pence is 1920, the walk's fee
    And handlers dedupe on the envelope id, not the natural key

  Scenario: Completing a walk twice does not pay twice
    Given the walker completed the walk
    When the walker completes it again via completeWalk
    Then the response status is 409
    And no second "WalkCompleted" event is published

  Scenario: A walk cannot be completed before it starts
    When the walker completes the walk via completeWalk
    Then the response status is 409
    And the problem body carries an error_code and message

  Scenario: Only the walker who started the walk can complete it
    Given the walker started the walk
    When the walker "w-2002" completes it via completeWalk
    Then the response status is 409
    And the problem body carries an error_code and message

  Scenario Outline: A report must be plausible
    Given the walker started the walk
    When the walker completes it with <problem> via completeWalk
    Then the response status is 400
    And the problem body carries an error_code and message

    Examples:
      | problem                    |
      | a negative distance_metres |
      | a negative pee_count       |
      | a negative poo_count       |
