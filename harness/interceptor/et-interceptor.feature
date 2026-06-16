Feature: ET conformance interceptor (pass-through proxy)

# Always-on conformance proxy (Karate mock). A client POSTs any FHIR resource or
# a transaction Bundle; the interceptor:
#   1. validates it against its ET profile via HAPI $validate
#        - Bundle      -> POST {target}/Bundle/$validate (HAPI validates each entry
#                         against its meta.profile)
#        - resource    -> POST {target}/{type}/$validate?profile=...
#                         (meta.profile wins, else profileFor default, else base)
#   2. records the verdict (session-<port>-validation-reports.json) + patient ids
#      (session-<port>-patients.txt) and logs an ETPROXY line for the live feed
#   3. forwards the original request to the real server and returns its response,
#      with X-ET-Validation / X-ET-Validation-Report headers added.
# (For validate-only with no forwarding, use the /validate route instead.)

Background:
  * configure cors = true
  * def System = Java.type('java.lang.System')
  * def target = System.getProperty('et.target', 'http://fhir-server:8080/fhir')
  * def port = System.getProperty('et.port', '8080')
  * def profileFor = read('profileFor.json')
  * def reportsFile = 'session-' + port + '-validation-reports.json'
  * def patientsFile = 'session-' + port + '-patients.txt'
  * def valReports = []
  * def seenPatients = {}
  * def errorIssues =
    """
    function(oo) {
      var list = karate.jsonPath(oo, "$.issue[?(@.severity=='error' || @.severity=='fatal')]");
      var out = [];
      for (var i = 0; i < karate.sizeOf(list); i++) {
        var x = list[i];
        var msg = x.diagnostics ? x.diagnostics : ((x.details && x.details.text) ? x.details.text : '');
        var loc = (x.location && x.location[0]) ? x.location[0] : ((x.expression && x.expression[0]) ? x.expression[0] : '');
        out.push({ severity: x.severity, location: loc, message: (msg.length > 200 ? msg.substring(0, 200) + '…' : msg) });
      }
      return out;
    }
    """
  * def recordReport =
    """
    function(action, subject, profile, issues) {
      var id = 'r' + (valReports.length + 1);
      valReports.push({ id: id, action: action, subject: subject, profile: profile, errors: issues.length, issues: issues });
      karate.write(JSON.stringify(valReports, null, 2), reportsFile);
      return id;
    }
    """
  * def recordPatients =
    """
    function(body) {
      var entries = (body.resourceType == 'Bundle') ? (body.entry || []) : [{ resource: body }];
      for (var i = 0; i < entries.length; i++) {
        var r = entries[i].resource;
        if (r && r.resourceType == 'Patient' && r.identifier) {
          for (var j = 0; j < r.identifier.length; j++) {
            var id = r.identifier[j];
            if (id.system && id.value) seenPatients[id.system + '|' + id.value] = true;
          }
        }
      }
      var keys = []; for (var k in seenPatients) keys.push(k);
      if (keys.length) karate.write(keys.join('\n'), patientsFile);
    }
    """
  * def headerReport = function(issues) { return encodeURIComponent(JSON.stringify(issues)) }

  # --- POST a transaction Bundle: validate the whole bundle, then forward (execute) ---
  Scenario: methodIs('post') && request != null && request.resourceType == 'Bundle'
    * def body = request
    * eval recordPatients(body)
    * def n = body.entry ? karate.sizeOf(body.entry) : 0
    * def subject = 'Bundle (' + n + ' entries)'
    Given url target + '/Bundle/$validate'
    And header Content-Type = 'application/fhir+json'
    And header Accept = 'application/fhir+json'
    And request body
    When method post
    * def issues = errorIssues(response)
    * def verdict = issues.length + ' error(s) in ' + subject
    * def reportId = recordReport('push', subject, 'Bundle', issues)
    * karate.log('ETPROXY|push|' + subject + '|' + issues.length + ' errors|' + reportId)
    # forward: execute the transaction on the real server; its response goes back
    Given url target
    And header Content-Type = 'application/fhir+json'
    And request body
    When method post
    * def responseHeaders =
      """
      {
        'X-ET-Validation': '#(verdict)',
        'X-ET-Validation-Report': '#(headerReport(issues))',
        'Access-Control-Expose-Headers': 'X-ET-Validation, X-ET-Validation-Report'
      }
      """

  # --- POST a single resource: validate against its ET profile, then forward (create) ---
  Scenario: methodIs('post') && request != null && request.resourceType != null
    * def body = request
    * def rt = body.resourceType
    * eval recordPatients(body)
    * def metaProfile = (body.meta && body.meta.profile && body.meta.profile[0]) ? body.meta.profile[0] : null
    * def profile = metaProfile ? metaProfile : profileFor[rt]
    Given url target + '/' + rt + '/$validate'
    And params (profile ? { profile: profile } : {})
    And header Content-Type = 'application/fhir+json'
    And header Accept = 'application/fhir+json'
    And request body
    When method post
    * def issues = errorIssues(response)
    * def verdict = issues.length + ' error(s) vs ' + (profile ? profile : ('base ' + rt))
    * def reportId = recordReport('push', rt, (profile ? profile : ('base ' + rt)), issues)
    * karate.log('ETPROXY|push|' + rt + '|' + issues.length + ' errors|' + reportId)
    # forward: create on the real server; its response goes back
    Given url target + '/' + rt
    And header Content-Type = 'application/fhir+json'
    And request body
    When method post
    * def responseHeaders =
      """
      {
        'X-ET-Validation': '#(verdict)',
        'X-ET-Profile': '#(profile ? profile : "base/" + rt)',
        'X-ET-Validation-Report': '#(headerReport(issues))',
        'Access-Control-Expose-Headers': 'X-ET-Validation, X-ET-Profile, X-ET-Validation-Report'
      }
      """

  # POST without a parseable FHIR resource
  Scenario: methodIs('post')
    * def responseStatus = 400
    * def response = { resourceType: 'OperationOutcome', issue: [{ severity: 'error', code: 'invalid', diagnostics: 'POST body must be a FHIR resource or Bundle with a resourceType' }] }
    * def responseHeaders = { 'Content-Type': 'application/fhir+json' }

  # Everything else: the interceptor only handles POSTs
  Scenario:
    * def responseStatus = 405
    * def response = { resourceType: 'OperationOutcome', issue: [{ severity: 'error', code: 'not-supported', diagnostics: 'ET interceptor handles POSTed resources/bundles only; use /fhir for the full API.' }] }
    * def responseHeaders = { 'Content-Type': 'application/fhir+json' }
