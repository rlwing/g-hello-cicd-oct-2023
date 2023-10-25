FROM eclipse-temurin:11-jdk-alpine
WORKDIR /app
COPY build/libs/*SNAPSHOT.jar app.jar
CMD java -jar app.jar
EXPOSE 8080
