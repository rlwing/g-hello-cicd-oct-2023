FROM openjdk:11-jre-slim
WORKDIR /app
COPY ./build/libs/g-hello-0.0.1-SNAPSHOT.jar /app/g-hello-0.0.1-SNAPSHOT.jar
EXPOSE 8080
CMD ["java", "-jar", "/app/g-hello-0.0.1-SNAPSHOT.jar"]
