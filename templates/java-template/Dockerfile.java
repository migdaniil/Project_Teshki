# Multi-stage build для Java
FROM eclipse-temurin:17-jdk as builder
WORKDIR /app

# Копируем исходный код
COPY pom.xml .
COPY src ./src

# Собираем JAR
RUN mvn clean package -DskipTests

# Финальный образ
FROM eclipse-temurin:17-jre
WORKDIR /app

# Копируем JAR из стадии builder
COPY --from=builder /app/target/*.jar app.jar

# Настройки здоровья приложения
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
