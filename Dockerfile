FROM eclipse-temurin:21-jdk AS build

WORKDIR /app

COPY gradlew gradlew.bat build.gradle ./
COPY gradle/ gradle/

RUN --mount=type=cache,target=/root/.gradle ./gradlew --version

COPY src/ src/

RUN --mount=type=cache,target=/root/.gradle ./gradlew --no-daemon clean bootJar \
    -Dspring-framework.version=6.2.11 \
    -Dtomcat.version=10.1.47

FROM gcr.io/distroless/java21-debian12

WORKDIR /app

COPY lib/applicationinsights.json ./

COPY --from=build /app/build/libs/spring-boot-template.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]