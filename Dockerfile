# ---------- Stage 1: Build ----------
FROM maven:3.9.11-eclipse-temurin-21 AS builder

WORKDIR /app

COPY pom.xml .
COPY .mvn .mvn
COPY mvnw .
RUN chmod +x mvnw

RUN ./mvnw dependency:go-offline

COPY src src

RUN ./mvnw clean package -DskipTests

# ---------- Stage 2: Runtime ----------
FROM eclipse-temurin:21-jre

WORKDIR /app

COPY --from=builder /app/target/spring-petclinic-*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java","-jar","app.jar"]
