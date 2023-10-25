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
ENV APP_NAME=petclinic
WORKDIR /app
COPY --from=build /app/target/$APP_NAME.jar .
CMD java -Dspring.profiles.active=postgres -jar $APP_NAME.jar
# CMD java -jar $APP_NAME.jar