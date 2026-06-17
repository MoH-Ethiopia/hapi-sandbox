Feature: ET fixtures validate against their ET profiles

# One scenario per fixture (dynamic Scenario Outline over the manifest that
# run-tests.sh writes). Resources POST to {Type}/$validate; Bundles to
# Bundle/$validate (which also checks each entry against its meta.profile).
# Valid fixtures come from the et.fhir.core.test package; invalid + bundle
# fixtures from harness/fixtures/. errorCount/shrUrl come from karate-config.js.

Scenario Outline: <name> — <resourceType> (expectError=<expectError>)
  Given url shrUrl + '/' + resourceType + '/$validate'
  And params (profile ? { profile: profile } : {})
  And request read('file:' + file)
  When method post
  * def errs = karate.sizeOf(karate.jsonPath(response, "$.issue[?(@.severity=='error' || @.severity=='fatal')]"))
  * print name, '->', errs, 'error(s) vs', (profile ? profile : 'base ' + resourceType), '| expectError =', expectError
  * def pass = expectError ? (errs > 0) : (errs == 0)
  * match pass == true

  Examples:
    | read('file:' + karate.properties['fixtures']) |
