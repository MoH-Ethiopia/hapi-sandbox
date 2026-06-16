@ignore
Feature: validate a single fixture against its ET profile

# Called once per fixture; the fixture's fields (name, file, resourceType,
# profile, expectError) arrive as variables. shrUrl + errorCount come from
# karate-config.js. POSTs to type-level $validate and asserts the verdict.

Scenario: validate one
  Given url shrUrl + '/' + resourceType + '/$validate'
  And params (profile ? { profile: profile } : {})
  And request read('file:' + file)
  When method post
  * def errs = karate.sizeOf(karate.jsonPath(response, "$.issue[?(@.severity=='error' || @.severity=='fatal')]"))
  * print name, '->', errs, 'error(s) vs', (profile ? profile : 'base ' + resourceType), '| expectError =', expectError
  * def pass = expectError ? (errs > 0) : (errs == 0)
  * match pass == true
