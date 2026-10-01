# syntax=docker/dockerfile:1

# Builds the backend image from source. CI runs the test suite before building, so
# tests are skipped here. REVISION is the version embedded in the build (see RELEASE.md).

FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /src
ARG REVISION=dev-SNAPSHOT
COPY pom.xml ./
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 \
    mvn -B --no-transfer-progress -Drevision="${REVISION}" -DskipTests package \
 && java -Djarmode=tools -jar target/app.jar extract --layers --launcher --destination /extracted

FROM eclipse-temurin:17-jre
RUN groupadd --system inatrace && useradd --system --gid inatrace --home-dir /app inatrace
WORKDIR /app

# Read from the working directory at runtime: PDF fonts and the country list used to
# seed an empty database (INATrace.import.path = import/).
COPY fonts ./fonts
COPY import ./import

# One layer per Spring Boot layer, least to most frequently changed.
COPY --from=build /extracted/dependencies/ ./
COPY --from=build /extracted/spring-boot-loader/ ./
COPY --from=build /extracted/snapshot-dependencies/ ./
COPY --from=build /extracted/application/ ./

# The image ships no configuration. Mount it at /app/config/application.properties
# (based on src/main/resources/application.properties.template) or use environment
# variables; Spring Boot reads ./config/ automatically.
USER inatrace
EXPOSE 8080
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
