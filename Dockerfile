# Stage 1: Build the Java project dependencies
FROM maven:3.8.4-openjdk-17-slim AS dependencies
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline

# Stage 2: Build the Java project
FROM dependencies AS build
COPY src ./src
RUN mvn package -DskipTests

# Stage 3: Create the final Docker image
FROM openjdk:17-slim

# Tracing with AWS auto instrumentation agent #
ADD https://github.com/aws-observability/aws-otel-java-instrumentation/releases/download/v1.21.1/aws-opentelemetry-agent.jar /app/aws-opentelemetry-agent.jar
ENV JAVA_TOOL_OPTIONS "-javaagent:/app/aws-opentelemetry-agent.jar"
# OpenTelemetry agent configuration
ENV OTEL_TRACES_SAMPLER "always_on"
ENV OTEL_PROPAGATORS "tracecontext,baggage,xray"
ENV OTEL_RESOURCE_ATTRIBUTES "service.name=Petclinic-adot-example"
ENV OTEL_IMR_EXPORT_INTERVAL "10000"
ENV OTEL_EXPORTER_OTLP_ENDPOINT "http://my-collector-collector.opentelemetry-operator-system.svc.cluster.local:4317"
###############################################

ENV APP_NAME=petclinic
WORKDIR /app
COPY --from=build /app/target/$APP_NAME.jar .
CMD java -jar $APP_NAME.jar