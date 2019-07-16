#!/usr/bin/env groovy

pipeline {
  agent any
    stages {
      stage('Init') {
        steps {
          checkout scm
          sh './build.sh clean init generateConf'
        }
      }
      stage('Run') {
        steps {
          sh './build.sh runJenkins'
        }
      }
      stage('Integration Tests') {
        steps {
          sh 'sleep 30'
        }
      }
      stage('Stop') {
        steps {
          sh './build.sh stop'
        }
      }
      stage('Build Front') {
        steps {
          sh './build.sh buildFront'
        }
      }
      stage('Archive') {
        steps {
          sh './build.sh archive'
        }
      }
      stage('Publish') {
        steps {
          sh './build.sh publish'
        }
      }
      stage('Push Docker') {
        steps {
          sh 'docker build -t maven.opendigitaleducation.com/opendigitaleducation/entcore:latest .'
          sh 'docker push maven.opendigitaleducation.com/opendigitaleducation/entcore:latest'
        }
      }
    }
}

