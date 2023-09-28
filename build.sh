#!/bin/bash

GROUPID=`grep 'modowner=' gradle.properties | sed 's/modowner=//'`
NAME=`grep 'modname=' gradle.properties | sed 's/modname=//'`
VERSION=`grep 'version=' gradle.properties | sed 's/version=//'`
PORT=`grep 'skins=' conf.properties | grep -Eow "[0-9]+" | head -1 | awk '{ print $1 }'`

if [[ "$*" == *"--no-user"* ]]
then
  USER_OPTION=""
else
  case `uname -s` in
    MINGW* | Darwin*)
      USER_UID=1000
      GROUP_GID=1000
      ;;
    *)
      if [ -z ${USER_UID:+x} ]
      then
        USER_UID=`id -u`
        GROUP_GID=`id -g`
      fi
  esac
  USER_OPTION="-u $USER_UID:$GROUP_GID"
fi

if [ -z ${BOWER_USERNAME:+x} ] && [ -e ~/.bower_credentials ]
then
  source ~/.bower_credentials
fi

clean () {
  if [ -e docker-compose.yml ]; then
    ## Delete pgdata
    docker-compose run postgres bash -c "sleep 5 && rm -Rf /var/lib/postgresql/data"
    #docker-compose run mongo bash -c "sleep 5 && rm -Rf /data/db"
  fi
  rm -rf data scripts src ent*.json *.template deployments run.sh stop.sh *.tar.gz static default.properties bower_components traductions i18n
  if [ -e docker-compose.yml ]; then
    if [ "$USER_UID" != "1000" ] && [ -e mods ]; then
      docker run --rm $USER_OPTION -v "$PWD"/mods:/srv/springboard/mods opendigitaleducation/vertx-service-launcher:1.4.5 chmod -R 777 mods/*
    fi
    docker-compose down
    docker-compose run --rm $USER_OPTION gradle gradle clean
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
    SET_HOME_ENV_ARG=""
  else
    SET_HOME_ENV_ARG="-e GRADLE_USER_HOME=/home/gradle/.gradle -e USER_HOME=/home/gradle"
  fi
  docker run --rm $USER_OPTION -v "$PWD":/home/gradle/project -v ~/.m2:/home/gradle/.m2 -v ~/.gradle:/home/gradle/.gradle -w /home/gradle/project $SET_HOME_ENV_ARG opendigitaleducation/gradle:4.5.1 gradle init
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
  mkdir -p data
  chmod -R 777 data
  mkdir -p .config
  # TODO add translate
}

run() {
  chmod -R 777 assets/
  docker-compose up -d --scale vertx=0
  sleep 10
  docker-compose up -d vertx
}

stop() {
  docker-compose stop
}

buildFront() {
  #dynamic theme
  TH1D="${THEME1D:-one}"
  TH2D="${THEME2D:-neo}"
  echo "Compiling theme1d=$TH1D and theme2d=$TH2D"
  sed -i'' -e "s/THEME1D/${TH1D}/" assets/themes/package.json
  sed -i'' -e "s/THEME2D/${TH2D}/" assets/themes/package.json
  sed -i'' -e "s/BT1D/${BT1D}/" assets/themes/package.json
  sed -i'' -e "s/BT2D/${BT2D}/" assets/themes/package.json
  set -e
  #prepare
  chmod -R 777 assets/ || true
  find -L assets/js/ -mindepth 1 -maxdepth 1 -not -name 'package.json' -not -name '.npmrc' -exec rm -rf {} \;
  find -L assets/themes/ -mindepth 1 -maxdepth 1 -not -name 'package.json' -not -name '.npmrc' -exec rm -rf {} \;
  if [[ $CI = "true" ]]
  then
    EXTRA_DOCKER_ARGS="-v /var/lib/jenkins:/var/lib/jenkins"
  else
    EXTRA_DOCKER_ARGS=""
  fi
  docker-compose run $EXTRA_DOCKER_ARGS -e NPM_TOKEN $USER_OPTION node sh -c "cd /home/node/app/assets/themes && yarn install && chmod -R 777 node_modules && cd /home/node/app/assets/js && pnpm config set store-dir /tmp/store && pnpm install  && chmod -R 777 node_modules"
  #clean
  find -L assets/js/ -mindepth 1 -maxdepth 1 -not -name 'node_modules' -exec rm -rf {} \;
  find -L assets/themes/ -mindepth 1 -maxdepth 1 -not -name 'node_modules' -exec rm -rf {} \;
  #move artefact
  find -L ./assets/js/node_modules/ -mindepth 1 -maxdepth 2 -type d -name "dist" | sed -e "s/assets\/js\/node_modules\///"  | sed -e "s/dist//" | xargs -i mv ./assets/js/node_modules/{}dist/ ./assets/js/{}
  find -L ./assets/themes/node_modules/ -mindepth 1 -maxdepth 2 -type d -name "dist" | sed -e "s/assets\/themes\/node_modules\///"  | sed -e "s/dist//" | xargs -i mv ./assets/themes/node_modules/{}dist/ ./assets/themes/{}
  #clean node_modules
  rm -rf assets/js/package.json assets/themes/package.json assets/widgets/package.json
  rm -rf assets/js/node_modules assets/themes/node_modules assets/widgets/node_modules
  rm -rf cdn/assets/.pnpm-store
}

archive() {
  #tar cfzh $NAME-static.tar.gz static
  rm -rf cdn/assets/.pnpm-store
  tar cfzh ${NAME}.tar.gz mods/*.jar assets/* cdn/* static
}

deployCDN()
{
    #rm mods/*.jar
  bash -c 'for i in `ls -d mods/* | egrep -i -v "feeder|session|tests|json-schema|proxy|~mod|tracer"`; do DEST=$(echo $i | sed "s/[a-z\.\/]*~\([a-z\-]*\)~[-A-Za-z0-9\.]*\(-SNAPSHOT\)*/\1/g"); mkdir static/`echo $DEST`; cp -r $i/public static/`echo $DEST`; done; exit 0'
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
  echo "DEFAULT_DOCKER_USER=`id -u`:`id -g`" > .env
  ENTCOREVERSION=$(grep entCoreVersion= gradle.properties | awk -F "=" '{ print $2 }' | sed -e "s/\r//")
  sed -i "s/entcoreVersion=.*/entcoreVersion=$ENTCOREVERSION/" conf.properties
  docker-compose run --rm $USER_OPTION gradle gradle generateConf
}

integrationTest() {
  #CONTAINER_NAME=`docker ps --format '{{.Names}}' | grep vertx`
  #VERTX_IP=`docker inspect ${CONTAINER_NAME} | grep '"IPAddress"' | head -1 | grep -Eow "[0-9\.]+"`
  sed -i "s|baseURL.*$|baseURL(\"http://vertx:$PORT\")|" src/test/scala/org/entcore/test/simulations/IntegrationTest.scala
  docker-compose run --rm $USER_OPTION gradle gradle integrationTest
}

for param in "$@"
do
  case $param in
    '--no-user')
      ;;
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
    buildLocalFront)
      buildLocalFront
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

