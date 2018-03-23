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
          sh './build.sh run'
        }
      }
      stage('Integration Tests') {
        steps {
          sh './build.sh integrationTest'
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
    }
}

