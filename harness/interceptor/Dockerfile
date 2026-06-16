# Always-on conformance interceptor: Karate mock mode running et-interceptor.feature.
FROM eclipse-temurin:21-jre

ARG KARATE_VERSION=2.0.3
WORKDIR /app
# Karate standalone jar (CLI includes `mock`).
ADD https://github.com/karatelabs/karate/releases/download/v${KARATE_VERSION}/karate-${KARATE_VERSION}.jar /app/karate.jar
COPY et-interceptor.feature profileFor.json /app/

# Target HAPI base URL the interceptor validates against (compose overrides it).
ENV ET_TARGET=http://fhir-server:8080/fhir
EXPOSE 8080

CMD ["sh", "-c", "java -Det.target=\"$ET_TARGET\" -jar /app/karate.jar mock -m /app/et-interceptor.feature -p 8080"]
