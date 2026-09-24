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
  rm -Rf ./it
  rm -Rf ./stress
  mkdir -p ./it/src
  mkdir -p ./it/resources
  mkdir -p ./stress/src
  mkdir -p ./stress/resources
  rm -rf mods.old
  rm -rf data scripts src ent*.json *.template deployments run.sh stop.sh *.tar.gz static default.properties bower_components traductions i18n
  if [ -e docker-compose.yml ]; then
    if [ "$USER_UID" != "1000" ] && [ -e mods ]; then
      docker run --rm -v "$PWD"/mods:/srv/springboard/mods opendigitaleducation/vertx-service-launcher:1.1.0 chmod -R 777 mods/*
    fi
    docker-compose down
    docker-compose run --rm -u "$USER_UID:$GROUP_GID" gradle gradle clean
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
  if [ ! -e "?/.gradle/gradle.properties" ]
  then
    mkdir -p "?/.gradle/"
    echo "odeUsername=$NEXUS_ODE_USERNAME" > "?/.gradle/gradle.properties"
    echo "odePassword=$NEXUS_ODE_PASSWORD" >> "?/.gradle/gradle.properties"
    echo "cgiUsername=$NEXUS_CGI_USERNAME" >> "?/.gradle/gradle.properties"
    echo "cgiPassword=$NEXUS_CGI_PASSWORD" >> "?/.gradle/gradle.properties"
  fi
  docker run --rm -v "$PWD":/home/gradle/project -v ~/.m2:/home/gradle/.m2 -v ~/.gradle:/home/gradle/.gradle -w /home/gradle/project -u "$USER_UID:$GROUP_GID" gradle:4.5-alpine gradle init
  sed -i "s/8090:/$PORT:/" docker-compose.yml.template
  # Update github token
  sed -i "s/GITHUB_API_TOKEN/$GITHUB_API_TOKEN/" assets/widgets/package.json
  if [ -e bower.json ]; then
    sed -i "s/bower_username:bower_password/$BOWER_USERNAME:$BOWER_PASSWORD/" bower.json
  fi
  if [ ! -z ${MAVEN_REPOSITORIES:+x} ]
  then
    sed -i "s/#environment:/  environment:/" docker-compose.yml.template
    MVN_REPOS=`echo $MAVEN_REPOSITORIES | sed 's/"/\\\\"/g'`
    sed -i "s|#  MAVEN_REPOSITORIES: ''|    MAVEN_REPOSITORIES: '$MVN_REPOS'|" docker-compose.yml.template
  fi
  # TODO add translate 
}

run() {
  docker-compose up -d --scale vertx=0
  sleep 10
  docker-compose up -d --scale vertx=1
}

runJenkins() {
  chmod -R 777 assets/
  sed -i 's#vertx-service-launcher:2.0.1#vertx-service-launcher:2.0.1-jenkins#' docker-compose.yml
  sed -i 's/- "8090:8090"/#- "8090:8090"/' docker-compose.yml
  sed -i 's/- "3000:3000"/#- "3000:3000"/' docker-compose.yml
  sed -i 's/- "9200:9200"/#- "9200:9200"/' docker-compose.yml
  sed -i 's/- "9300:9300"/#- "9300:9300"/' docker-compose.yml
  sed -i 's/- "3100:3000"/#- "3100:3000"/' docker-compose.yml
  sed -i 's/ports:/#ports:/' docker-compose.yml
  docker-compose up -d --scale vertx=0
  sleep 10
  docker-compose up -d --scale vertx=1
}

stop() {
  docker-compose stop
}

down() {
  docker-compose down
}

buildFront() {
  set -e
  #prepare
  chmod -R 777 assets/ || true
  find -L assets/js/ -mindepth 1 -maxdepth 1 -not -name 'package.json' -not -name '.npmrc' -exec rm -rf {} \;
  find -L assets/themes/ -mindepth 1 -maxdepth 1 -not -name 'package.json' -not -name '.npmrc' -exec rm -rf {} \;
  find -L assets/widgets/ -mindepth 1 -maxdepth 1 -not -name 'package.json' -not -name '.npmrc' -exec rm -rf {} \;
  #run pnpm install
  sed -i "s/BOWER_USERNAME/$BOWER_USERNAME/" assets/widgets/package.json
  sed -i "s/BOWER_PASSWORD/$BOWER_PASSWORD/" assets/widgets/package.json
  docker run -e NPM_TOKEN --rm -v "$PWD":/home/node opendigitaleducation/node:18-alpine-pnpm sh -c "cd /home/node/assets/themes && yarn install && chmod -R 777 node_modules && cd /home/node/assets/widgets && yarn install  && chmod -R 777 node_modules && cd /home/node/assets/js && pnpm install  && chmod -R 777 node_modules"
  #clean
  find -L assets/js/ -mindepth 1 -maxdepth 1 -not -name 'node_modules' -exec rm -rf {} \;
  find -L assets/themes/ -mindepth 1 -maxdepth 1 -not -name 'node_modules' -exec rm -rf {} \;
  find -L assets/widgets/ -mindepth 1 -maxdepth 1 -not -name 'node_modules' -exec rm -rf {} \;
  #move artefact
  mv assets/widgets/node_modules/* assets/widgets/
  find -L ./assets/js/node_modules/ -mindepth 1 -maxdepth 2 -type d -name "dist" | sed -e "s/assets\/js\/node_modules\///"  | sed -e "s/dist//" | xargs -i mv ./assets/js/node_modules/{}dist/ ./assets/js/{}
  find -L ./assets/themes/node_modules/ -mindepth 1 -maxdepth 2 -type d -name "dist" | sed -e "s/assets\/themes\/node_modules\///"  | sed -e "s/dist//" | xargs -i mv ./assets/themes/node_modules/{}dist/ ./assets/themes/{}
  #clean node_modules
  rm -rf assets/js/package.json assets/themes/package.json assets/widgets/package.json
  rm -rf assets/js/node_modules assets/themes/node_modules assets/widgets/node_modules
  docker run --rm -v "$PWD":/home/node opendigitaleducation/node:18-alpine-pnpm sh -c "rm -rf /home/node/assets/.pnpm-store"
  #rm mods/*.jar
  bash -c 'for i in `ls -d mods/* | egrep -i -v "feeder|session|tests|json-schema|proxy|~mod|tracer"`; do DEST=$(echo $i | sed "s/[a-z\.\/]*~\([a-z\-]*\)~[A-Z0-9\-\.]*\(-[a-z]*\)*\(-SNAPSHOT\)*/\1/g"); mkdir static/`echo $DEST`; cp -r $i/public static/`echo $DEST`; done; exit 0'
  #bash -c 'for i in `ls -d mods/* | egrep -i -v "feeder|session|tests|json-schema|proxy|~mod|tracer"`; do DEST=$(echo $i | sed "s/[a-z\.\/]*~\([a-z\-]*\)~[A-Z0-9\-\.]*\(-SNAPSHOT\)*/\1/g"); mkdir static/`echo $DEST`; cp -r $i/public static/`echo $DEST`; done; exit 0'
  #bash -c 'for i in `ls -d mods/* | egrep -i -v "feeder|session|tests|json-schema|proxy|~mod|tracer"`; do DEST=$(echo $i | sed "s/[a-z\.\/]*~\([a-z\-]*\)~.*/\1/g"); mkdir static/`echo $DEST`; cp -r $i/public static/`echo $DEST`; done; exit 0'
  mv static/app-registry static/appregistry
  find static/help -type l -exec rename 's/index.html\?iframe\=true/index.html/' '{}' \;
  
  echo "$VERSION" > assets/version
}

archive() {
  COUNT_THEME=$(find assets/themes/*/skins/default -name theme.css | grep -v 'bootstrap' | wc -l)
  if [ "$COUNT_THEME" -eq "0" ]; then
    echo "Error: 0 theme.css build"
    exit 1
  else
    echo "$COUNT_THEME successful theme.css build"
  fi
  
  if [ -e static/conversation ] && [ -e static/workspace ]; then
    echo "Check statics successful"
  else
    echo "Error: missing statics. It usually happens when many springboards are built at the same time, try to rebuild."
    exit 1
  fi
  
  tar cfzh ${NAME}.tar.gz assets/* static
}

publish() {
  case "$VERSION" in
    *SNAPSHOT) nexusRepository='snapshots' ;;
    *)         nexusRepository='releases' ;;
  esac
  docker run --rm -v "$(echo ~/.m2)":/root/.m2 -v "$(pwd)":/usr/src/mymaven -w /usr/src/mymaven maven:3.3-jdk-8 mvn deploy:deploy-file -DgroupId=$GROUPID -DartifactId=$NAME -Dversion=$VERSION -Dpackaging=tar.gz -Dfile=${NAME}.tar.gz -DrepositoryId=ode-$nexusRepository -Durl=https://maven.opendigitaleducation.com/nexus/content/repositories/ode-$nexusRepository/
}

generateConf() {
  echo "DEFAULT_DOCKER_USER=`id -u`:`id -g`" > .env
  ENTCOREVERSION=$(grep entCoreVersion= gradle.properties | awk -F "=" '{ print $2 }' | sed -e "s/\r//")
  sed -i "s/entcoreVersion=.*/entcoreVersion=$ENTCOREVERSION/" conf.properties
  sed -i "s/.*REMOVE_BY_CI.*//g" docker-compose.yml.template
  docker-compose run --rm -u "$USER_UID:$GROUP_GID" gradle gradle generateConf
  docker run --rm $USER_OPTION -v "$PWD":/home/gradle/project -v ~/.m2:/home/gradle/.m2 -v ./?/.gradle:/home/gradle/.gradle -w /home/gradle/project $SET_HOME_ENV_ARG opendigitaleducation/gradle:4.5.1 gradle generateConf
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
	down)
      down
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
