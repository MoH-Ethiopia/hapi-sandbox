@auditor
Feature: Auditor — validate what a system stored for a patient

  For auditing data an external system (or the interceptor's pass-through) left on
  the server: find everything stored for a patient and re-validate each resource
  against its declared profile. IG-agnostic (uses instance-level $validate, which
  validates against each resource's meta.profile).

  Run:
    AUDIT_PATIENT_IDENTIFIER='<system>|<value>' \
      java -Dshr=<fhir-base> -jar karate-2.0.3.jar features/auditor.feature

  Background:
    * url shrUrl
    * def auditIdentifier = java.lang.System.getenv('AUDIT_PATIENT_IDENTIFIER')
    * if (!auditIdentifier) karate.fail('Set AUDIT_PATIENT_IDENTIFIER=<system>|<value> to run the auditor')
    * def toItems =
      """
      function(bundle) {
        var out = []; var entries = (bundle && bundle.entry) ? bundle.entry : [];
        for (var i = 0; i < entries.length; i++) {
          var r = entries[i].resource;
          if (r && r.id) out.push({ resourceType: r.resourceType, id: r.id });
        }
        return out;
      }
      """

  Scenario: Everything stored for the audited patient conforms to its declared profiles
    # locate the patient as stored
    Given path 'Patient'
    And param identifier = auditIdentifier
    When method get
    Then status 200
    * if (!response.entry || response.entry.length == 0) karate.fail('AUDIT: no Patient matches ' + auditIdentifier + ' on ' + shrUrl)
    * def patientId = response.entry[0].resource.id
    * def items = [{ resourceType: 'Patient', id: patientId }]

    # collect the patient's resources (types common to the demo workflow)
    Given path 'Encounter'
    And param subject = 'Patient/' + patientId
    When method get
    * def items = items.concat(toItems(response))

    Given path 'MedicationDispense'
    And param subject = 'Patient/' + patientId
    When method get
    * def items = items.concat(toItems(response))

    Given path 'MedicationRequest'
    And param subject = 'Patient/' + patientId
    When method get
    * def items = items.concat(toItems(response))

    Given path 'Observation'
    And param subject = 'Patient/' + patientId
    When method get
    * def items = items.concat(toItems(response))

    Given path 'Condition'
    And param subject = 'Patient/' + patientId
    When method get
    * def items = items.concat(toItems(response))

    # validate each stored resource against its declared profile
    * karate.log('Auditing', items.length, 'stored resources for patient', patientId)
    * def results = call read('common/validate-resource.feature') items
