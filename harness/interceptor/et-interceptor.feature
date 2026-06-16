Feature: ET conformance interceptor

# Always-on conformance proxy (Karate mock mode). A client POSTs any FHIR
# resource; the interceptor validates it against its ET profile via HAPI's
# type-level $validate and returns the OperationOutcome plus a verdict header.
# Profile selection: the resource's own meta.profile[0] wins; else the
# profileFor table; else base FHIR for that resourceType.
#
# This is VALIDATE-ONLY (it does not persist). Use /fhir for the full API.
# A pass-through "also create" mode can be layered on later (MODE=proxy).

Background:
  * configure cors = true
  * def System = Java.type('java.lang.System')
  * def target = System.getProperty('et.target', 'http://fhir-server:8080/fhir')
  * def profileFor = read('profileFor.json')
  * def errorCount =
    """
    function(oo) {
      var errs = karate.jsonPath(oo, "$.issue[?(@.severity=='error' || @.severity=='fatal')]");
      return karate.sizeOf(errs);
    }
    """

  # POST of a FHIR resource -> validate against its ET profile
  Scenario: methodIs('post') && request != null && request.resourceType != null
    * def body = request
    * def rt = body.resourceType
    * def metaProfile = (body.meta && body.meta.profile && body.meta.profile[0]) ? body.meta.profile[0] : null
    * def profile = metaProfile ? metaProfile : profileFor[rt]
    Given url target + '/' + rt + '/$validate'
    And params (profile ? { profile: profile } : {})
    And header Content-Type = 'application/fhir+json'
    And header Accept = 'application/fhir+json'
    And request body
    When method post
    # response / responseStatus now hold the $validate OperationOutcome + status
    * def errs = errorCount(response)
    * def verdict = errs + ' error(s) vs ' + (profile ? profile : ('base ' + rt))
    * karate.log('ETVALIDATE|' + rt + '|' + verdict)
    * def responseHeaders =
      """
      {
        'Content-Type': 'application/fhir+json',
        'X-ET-Validation': '#(verdict)',
        'X-ET-Profile': '#(profile ? profile : "base/" + rt)',
        'Access-Control-Expose-Headers': 'X-ET-Validation, X-ET-Profile'
      }
      """

  # POST without a parseable FHIR resource
  Scenario: methodIs('post')
    * def responseStatus = 400
    * def response = { resourceType: 'OperationOutcome', issue: [{ severity: 'error', code: 'invalid', diagnostics: 'POST body must be a FHIR resource with a resourceType' }] }
    * def responseHeaders = { 'Content-Type': 'application/fhir+json' }

  # Everything else: the interceptor only validates POSTs
  Scenario:
    * def responseStatus = 405
    * def response = { resourceType: 'OperationOutcome', issue: [{ severity: 'error', code: 'not-supported', diagnostics: 'ET interceptor validates POSTed resources only; use /fhir for the full API.' }] }
    * def responseHeaders = { 'Content-Type': 'application/fhir+json' }
