@ignore
Feature: Validate one stored resource via instance-level $validate (callable helper)

  Expects (from caller): resourceType, id. Validates the STORED resource against
  its own declared meta.profile (+ base FHIR) — IG-agnostic. Fails on any
  error/fatal issue. shrUrl comes from karate-config.

  Scenario:
    Given url shrUrl
    And path resourceType, id, '$validate'
    When method get
    Then status 200
    And match response.resourceType == 'OperationOutcome'
    And match response.issue[*].severity !contains 'fatal'
    And match response.issue[*].severity !contains 'error'
