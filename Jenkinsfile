#!/usr/bin/env groovy

pipeline {
  agent any

	environment {
	  BOWER_PASSWORD = credentials('bower-password')
	  MAVEN_REPOSITORIES = credentials('maven-repositories')
	  NEXUS_CGI_PASSWORD = credentials('nexus-cgi-password')
	  NEXUS_ODE_PASSWORD = credentials('nexus-ode-password')
	  NPM_TOKEN = credentials('npm-token')
	  TIPTAP_PRO_TOKEN = credentials('tiptap-pro-token')
	}
	
    stages {
      stage('Init') {
        steps {
          checkout scm
		  withCredentials([usernameColonPassword(credentialsId: 'jenkins-public-fine-grained-pat', variable: 'GITHUB_API_TOKEN')]) {
			sh './build.sh clean init generateConf'
		  }
        }
      }
      stage('Run') {
        steps {
          sh './build.sh runJenkins'
        }
      }
      stage('Integration Tests') {
        steps {
          //sh './build.sh integrationTest'
		  sh 'sleep 60'
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
    post {
		cleanup {
		  sh 'docker-compose down'
		}
   }
}

