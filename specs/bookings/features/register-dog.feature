Feature: Registering a dog
  As a dog owner
  I want to register my dog
  So that I can book walks for it

  These scenarios are acceptance criteria, not suggestions. An
  implementation that fails any of them is wrong. If a scenario is
  itself wrong, that is a versioned change to this file.

  Background:
    Given the owner "o-1001" exists

  Scenario: A dog is registered with its size
    When the owner registers "Biscuit", a "medium" cockapoo, via registerDog
    Then the response status is 201
    And the dog carries a dog_id, the owner_id, name, breed and size

  Scenario Outline: Size is one of small, medium or large
    When the owner registers a dog with size "<size>" via registerDog
    Then the response status is 400
    And the problem body carries an error_code and message

    Examples:
      | size |
      | tiny |
      | huge |
      |      |

  Scenario Outline: A dog needs a name and a breed
    When the owner registers a dog with <problem> via registerDog
    Then the response status is 400
    And the problem body carries an error_code and message

    Examples:
      | problem          |
      | an empty name    |
      | an empty breed   |
      | a missing size   |

  Scenario: A dog can be fetched by its id
    Given the owner registered "Biscuit"
    When the dog is fetched by dog_id via getDog
    Then the response status is 200
    And the dog carries the dog_id, owner_id, name, breed and size

  Scenario: Fetching an unknown dog returns 404
    When an unknown dog_id is fetched via getDog
    Then the response status is 404
    And the problem body carries an error_code and message
