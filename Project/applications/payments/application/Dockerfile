FROM openjdk:12-alpine

COPY ./build/libs/spring-boot-payments-0.0.15.jar .

RUN apk update && \
  apk add curl unzip

RUN curl "https://releases.hashicorp.com/waypoint-entrypoint/0.6.3/waypoint-entrypoint_0.6.3_linux_amd64.zip" -o waypoint-entrypoint.zip

RUN unzip waypoint-entrypoint.zip && \ 
  mv waypoint-entrypoint /usr/local/bin/waypoint-entrypoint

ENTRYPOINT [ "/usr/local/bin/waypoint-entrypoint" ]

CMD ["java", "-jar", "./spring-boot-payments-0.0.15.jar"]
