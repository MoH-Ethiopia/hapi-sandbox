Feature: ET test fixtures validate against their ET profiles

# Fixtures come from the et.fhir.core.test package (valid examples) plus
# harness fixtures/invalid/ (negative examples) — run-tests.sh writes the merged
# manifest passed in -Dfixtures. Each fixture is validated by
# validate-one.feature, called once per fixture.

Scenario: validate all fixtures
  * def fixtures = read('file:' + karate.properties['fixtures'])
  * call read('validate-one.feature') fixtures
