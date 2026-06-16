Feature: ET test fixtures validate against their ET profiles

# Data-free: fixtures come from the et.fhir.core.test package (resolved by
# run-tests.sh, which writes the manifest passed in -Dfixtures). Each fixture is
# validated by validate-one.feature, called once per fixture.

Scenario: validate all fixtures
  * def fixtures = read('file:' + karate.properties['fixtures'])
  * call read('validate-one.feature') fixtures
