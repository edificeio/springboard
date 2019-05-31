FROM opendigitaleducation/vertx-service-launcher:1.0.3
LABEL maintainer="systeme@opendigitaleducation.com"

COPY assets/ /srv/springboard/assets/
COPY mods/ /srv/springboard/mods/

USER vertx

WORKDIR /srv/springboard
EXPOSE 8090

CMD java -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -jar /opt/vertx-service-launcher.jar -Dvertx.services.path=/srv/springboard/mods -Dvertx.disableFileCaching=true -conf /srv/springboard/conf/vertx.conf

