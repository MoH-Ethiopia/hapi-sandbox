function fn() {
  var shr = java.lang.System.getProperty('shr');
  var config = {
    // FHIR base the harness validates against (the sandbox). Override with -Dshr=...
    shrUrl: shr ? shr : 'http://localhost:8090/fhir'
  };
  // error/fatal issue count from an OperationOutcome (0 == conformant)
  config.errorCount = function (oo) {
    return karate.sizeOf(karate.jsonPath(oo, "$.issue[?(@.severity=='error' || @.severity=='fatal')]"));
  };
  karate.configure('headers', { 'Content-Type': 'application/fhir+json', 'Accept': 'application/fhir+json' });
  karate.configure('ssl', true);
  karate.configure('connectTimeout', 10000);
  // validation on a cold server can be slow
  karate.configure('readTimeout', 120000);
  karate.log('ET harness — SHR:', config.shrUrl);
  return config;
}
