#!/bin/bash

GROUPID=`grep 'modowner=' gradle.properties | sed 's/modowner=//'`
NAME=`grep 'modname=' gradle.properties | sed 's/modname=//'`
VERSION=`grep 'version=' gradle.properties | sed 's/version=//'`
PORT=`grep 'skins=' conf.properties | grep -Eow "[0-9]+" | head -1 | awk '{ print $1 }'`

case `uname -s` in
  MINGW*)
    USER_UID=1000
    GROUP_UID=1000
    ;;
  *)
    if [ -z ${USER_UID:+x} ]
    then
      USER_UID=`id -u`
      GROUP_GID=`id -g`
    fi
esac

if [ -z ${BOWER_USERNAME:+x} ] && [ -e ~/.bower_credentials ]
then
  source ~/.bower_credentials
fi

clean () {
  rm -rf data scripts src ent*.json *.template deployments run.sh stop.sh *.tar.gz static default.properties bower_components traductions i18n
  if [ -e docker-compose.yml ]; then
    if [ "$USER_UID" != "1000" ] && [ -e mods ]; then
      docker run --rm -v "$PWD"/mods:/srv/springboard/mods opendigitaleducation/vertx-service-launcher:1.0.0 chmod -R 777 mods/*
    fi
    docker-compose down
    docker-compose run --rm -u "$USER_UID:$GROUP_GID" gradle gradle clean
    #stop && docker-compose rm -f
    docker volume ls -qf dangling=true | xargs -r docker volume rm
  fi
}

init() {
  if [ ! -e mods ]; then
    mkdir mods && chmod 777 mods
  fi
  if [ ! -e node_modules ]; then
    mkdir node_modules
  fi
  if [ -e "?/.gradle" ] && [ ! -e "?/.gradle/gradle.properties" ]
  then
    echo "odeUsername=$NEXUS_ODE_USERNAME" > "?/.gradle/gradle.properties"
    echo "odePassword=$NEXUS_ODE_PASSWORD" >> "?/.gradle/gradle.properties"
  fi
  docker run --rm -v "$PWD":/home/gradle/project -v ~/.m2:/home/gradle/.m2 -v ~/.gradle:/home/gradle/.gradle -w /home/gradle/project -u "$USER_UID:$GROUP_GID" gradle:4.5-alpine gradle init
  sed -i "s/8090:/$PORT:/" docker-compose.yml
  if [ -e bower.json ]; then
    sed -i "s/bower_username:bower_password/$BOWER_USERNAME:$BOWER_PASSWORD/" bower.json
  fi
  if [ ! -z ${MAVEN_REPOSITORIES:+x} ]
  then
    sed -i "s/#environment:/  environment:/" docker-compose.yml
    MVN_REPOS=`echo $MAVEN_REPOSITORIES | sed 's/"/\\\\"/g'`
    sed -i "s|#  MAVEN_REPOSITORIES: ''|    MAVEN_REPOSITORIES: '$MVN_REPOS'|" docker-compose.yml
  fi
  # TODO add translate
}

run() {
  docker-compose up -d neo4j
  docker-compose up -d postgres
  docker-compose up -d mongo
  sleep 10
  docker-compose up -d vertx
}

runJenkins() {
  sed -i 's/- "8090:8090"/#- "8090:8090"/' docker-compose.yml
  sed -i 's/ports:/#ports:/' docker-compose.yml
  docker-compose up -d neo4j
  docker-compose up -d postgres
  docker-compose up -d mongo
  sleep 10
  docker-compose up -d vertx
}

stop() {
  docker-compose stop
}

buildFront() {
  if [ "$USER_UID" != "1000" ] && [ -e mods ]; then
    mv mods mods.old
    cp -r mods.old mods
    docker run --rm -v "$PWD"/mods.old:/srv/springboard/mods opendigitaleducation/vertx-service-launcher:1.0.0 chmod -R 777 mods/*
    rm -rf mods.old
  fi
  case `uname -s` in
    MINGW*)
      docker-compose run --rm -u "$USER_UID:$GROUP_GID" node sh -c "npm rebuild node-sass --no-bin-links && npm install --no-bin-links && node_modules/bower/bin/bower cache clean && node_modules/gulp/bin/gulp.js build --max_old_space_size=5000"
      ;;
    *)
      docker-compose run --rm -u "$USER_UID:$GROUP_GID" node sh -c "npm rebuild node-sass && npm install && node_modules/bower/bin/bower cache clean && node_modules/gulp/bin/gulp.js build --max_old_space_size=5000"
  esac
  #rm mods/*.jar
  bash -c 'for i in `ls -d mods/* | egrep -i -v "feeder|session|tests|json-schema|proxy|~mod|tracer"`; do DEST=$(echo $i | sed "s/[a-z\.\/]*~\([a-z\-]*\)~.*/\1/g"); mkdir static/`echo $DEST`; cp -r $i/public static/`echo $DEST`; done; exit 0'
  mv static/app-registry static/appregistry
  mv static/collaborative-editor static/collaborativeeditor
  mv static/scrap-book static/scrapbook
  mv static/fake-sso static/sso
  mv errors static/
  find static/help -type l -exec rename 's/index.html\?iframe\=true/index.html/' '{}' \;
  I18N_VERSION=`grep 'i18nVersion=' gradle.properties | sed 's/i18nVersion=//'`
  if [ -e i18n ] && [ ! -z "$I18N_VERSION" ]; then
    rm -rf assets/i18n
    mv i18n assets/
  fi
}

archive() {
  #tar cfzh $NAME-static.tar.gz static
  tar cfzh ${NAME}.tar.gz mods/*.jar assets/* static
}

publish() {
  case "$VERSION" in
    *SNAPSHOT) nexusRepository='snapshots' ;;
    *)         nexusRepository='releases' ;;
  esac
  mvn deploy:deploy-file -DgroupId=$GROUPID -DartifactId=$NAME -Dversion=$VERSION -Dpackaging=tar.gz -Dfile=${NAME}.tar.gz -DrepositoryId=ode-$nexusRepository -Durl=https://maven.opendigitaleducation.com/nexus/content/repositories/ode-$nexusRepository/
 # mvn deploy:deploy-file -DgroupId=$GROUPID -DartifactId=$NAME -Dversion=$VERSION -Dpackaging=tar.gz -Dclassifier=static -Dfile=${NAME}-static.tar.gz -DrepositoryId=ode-$nexusRepository -Durl=https://maven.opendigitaleducation.com/nexus/content/repositories/ode-$nexusRepository/

}

generateConf() {
  docker-compose run --rm -u "$USER_UID:$GROUP_GID" gradle gradle generateConf
}

integrationTest() {
  BASE_CONTAINER_NAME=`basename "$PWD" | sed 's/-//g'`
  VERTX_IP=`docker inspect ${BASE_CONTAINER_NAME}_vertx_1 | grep '"IPAddress"' | head -1 | grep -Eow "[0-9\.]+"`
  sed -i "s|baseURL.*$|baseURL(\"http://$VERTX_IP:$PORT\")|" src/test/scala/org/entcore/test/simulations/IntegrationTest.scala
  docker-compose run --rm -u "$USER_UID:$GROUP_GID" gradle gradle integrationTest
}

for param in "$@"
do
  case $param in
    clean)
      clean
      ;;
    init)
      init
      ;;
    generateConf)
      generateConf
      ;;
    integrationTest)
      integrationTest
      ;;
    run)
      run
      ;;
    runJenkins)
      runJenkins
      ;;
    stop)
      stop
      ;;
    buildFront)
      buildFront
      ;;
    archive)
      archive
      ;;
    publish)
      publish
      ;;
    help)
      echo "
                clean : clean springboard and docker's containers
                 init : fetch files and artefacts usefull for springboard's execution
         generateConf : generate an vertx configuration file (ent-core.json) from conf.properties
                  run : run databases and vertx in distinct containers
                 stop : stop containers
      integrationTest : run integration tests
           buildFront : fetch wigets and themes using Bower and run Gulp build. (/!\ first run can be long becouse of node-sass's rebuild).
              archive : make an archive with folder /mods /assets /static
              publish : upload the archive on nexus
      "
    ;;
    *)
      echo "Invalid command : $param. Use one of next command [ help | clean | init | generateConf | run | stop | buildFront | archive | publish ]"
  esac
  if [ ! $? -eq 0 ]; then
    exit 1
  fi
done

