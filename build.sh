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
  rm -rf data scripts src ent*.json *.template deployments run.sh stop.sh *.tar.gz static default.properties bower_components traductions
  if [ -e docker-compose.yml ]; then
    if [ "$USER_UID" != "1000" ] && [ -e mods ]; then
      docker run --rm -v "$PWD"/mods:/srv/springboard/mods opendigitaleducation/vertx-service-launcher:1.0-SNAPSHOT chmod -R 777 mods/*
    fi
    docker-compose run --rm -u "$USER_UID:$GROUP_GID" gradle gradle clean
    stop && docker-compose rm -f
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

stop() {
  docker-compose stop
}

buildFront() {
  if [ "$USER_UID" != "1000" ] && [ -e mods ]; then
    #docker run --rm -v "$PWD"/mods:/srv/springboard/mods opendigitaleducation/vertx-service-launcher:1.0-SNAPSHOT sh -c "find mods/ -name view -exec find {} -name *.html \; | xargs chmod 777 && chmod 777 mods/*.jar"
    mv mods mods.old
    cp -r mods.old mods
    docker run --rm -v "$PWD"/mods.old:/srv/springboard/mods opendigitaleducation/vertx-service-launcher:1.0-SNAPSHOT chmod -R 777 mods/*
    rm -rf mods.old
  fi
  case `uname -s` in
    MINGW*)
      docker-compose run --rm -u "$USER_UID:$GROUP_GID" node sh -c "npm rebuild node-sass --no-bin-links && npm install --no-bin-links && node_modules/bower/bin/bower cache clean && node_modules/gulp/bin/gulp.js build --max_old_space_size=5000"
      ;;
    *)
      docker-compose run --rm -u "$USER_UID:$GROUP_GID" node sh -c "npm rebuild node-sass && npm install && node_modules/bower/bin/bower cache clean && node_modules/gulp/bin/gulp.js build"
  esac
  rm mods/*.jar
#  if [ "$USER_UID" != "1000" ] && [ -e mods ]; then
    #docker run --rm -v "$PWD"/mods:/srv/springboard/mods opendigitaleducation/vertx-service-launcher:1.0-SNAPSHOT sh -c "find mods/ -name view -exec find {} -name *.html \; | xargs chmod 644"
 # fi
  if [ -d static/help ]; then rm -r static/help; fi
  mkdir -p static/help/application
  bash -c 'for i in `ls -d mods/* | egrep -i -v "feeder|session|tests|json-schema|proxy|~mod|tracer"`; do DEST=$(echo $i | sed "s/[a-z\.\/]*~\([a-z\-]*\)~[A-Z0-9\-\.]*\(-SNAPSHOT\)*/\1/g"); mkdir static/`echo $DEST`; cp -r $i/public static/`echo $DEST`; done; exit 0'
  # TODO get asciidoc online help
#  bash -c 'for i in `ls -d mods/* | egrep -i -v "feeder|session|tests|json-schema|proxy|~mod|tracer"`; do DEST=$(echo $i | sed "s/[a-z\.\/]*~\([a-z\-]*\)~[A-Z0-9\-\.]*\(-SNAPSHOT\)*/\1/g"); mkdir static/`echo $DEST`; cp -r $i/public static/`echo $DEST`; cp --remove-destination -rs ~/jobs/ong-asciidoc/workspace/application/$DEST/ static/help/application; done; exit 0'
#  bash -c 'cp --remove-destination -rs ~/jobs/ong-asciidoc/workspace/application/userbook static/help/application/userbook'
#  bash -c 'cp --remove-destination -rs ~/jobs/ong-asciidoc/workspace/assets static/help'
#  bash -c 'cp --remove-destination -rs ~/jobs/ong-asciidoc/workspace/wp-content static/help'
#  #bash -c 'cp --remove-destination -rs ~/jobs/ong-doc/workspace/help/userbook/application static/help'
#  #bash -c 'cp --remove-destination -rs ~/jobs/ong-doc/workspace/help/userbook/wp-content static/help'
#  bash -c "rm -r help/index.html* help/actualites* help/contact help/donec-eleifend-laoreet-libero-morbi-placerat-rutrum-dolor-molestie-lobortis-ex-porttitor-eu help/feed help/le-projet-one-laureat-e-education-2-fsnpia/ help/page-daccueil/ help/tag/ help/un-kit-de-developpement-et-dexecution-dapplications-web-dediees-a-leducation/ help/use* help/xmlrpc.php\?rsd; exit 0"
  mv static/app-registry static/appregistry
  mv static/collaborative-editor static/collaborativeeditor
  mv static/scrap-book static/scrapbook
  mv static/fake-sso static/sso
  mv static/help/application/collaborative-editor static/help/application/collaborativeeditor
  mv static/help/application/scrap-book static/help/application/scrapbook
  mv errors static/
  find static/help -type l -exec rename 's/index.html\?iframe\=true/index.html/' '{}' \;
  #Ajout lang
  if [ -e traductions/i18n ]; then
    rm -rf assets/i18n
    mv traductions/i18n assets/
  fi
}

archive() {
  #tar cfzh $NAME-static.tar.gz static
  tar cfzh ${NAME}.tar.gz mods/* assets/* static
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
  VERTX_IP=`docker inspect ${NAME}_vertx_1 | grep '"IPAddress"' | head -1 | grep -Eow "[0-9\.]+"`
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
    *)
      echo "Invalid argument : $param"
  esac
  if [ ! $? -eq 0 ]; then
    exit 1
  fi
done

