# A propos de SpringBoard

Springboard est un conteneur de personnalisation et de lancement d'un portail basé sur les composants ENT Core.
Il s'agit d'un template à dupliquer pour créer son projet spécifique de portail motoriser par ENT Core. Les modules (dépendances) ENT Core utiles pour l'éxécution de votre springboard sont téléchargés depuis les dépôts Maven du projet. 

# Notes d'utilisation

Ces notes proposent une démarche rapide de prise en main (pour une machine de développement). Elles ne détaillent pas l'installation des composants techniques. Il suffit pour cela de suivre la documentation de référence de chacun d'entre eux ou d'utiliser le cas échéant le gestionnaire de paquets de votre système d'exploitation.


## Le code

Installer [Git](http://git-scm.com/) et cloner le dépôt suivant

- springboard : `git clone https://github.com/entcore/springboard.git`

## Les composants techniques

- __JSE 7__ (www.oracle.com/technetwork/java/javase/downloads/index.html)
- __Gralde 1.6__ (www.gradle.org)
- __Vert.x 2.1.1__  (vertx.io)
- __Neo4j 2.1__ (www.neo4j.org)
- __MondoDB 2.4 +__ (mongodb.org)

__Remarques__ : 
- _Il est fortement recommandé d'utiliser le JDK d'Oracle, notamment pour le bon fonctionnement de Neo4j_
- _Assureez-vous que les serveurs de bases de données (Neo4j et MongoDB) sont bien démarré_ 

## Installation simple 

## Configurer les dépôts Maven spécifiques 

Ajouter au fichier `{VERTX_HOME}/conf/repos.txt` la ligne suivante (Où `{VERTX_HOME}` est le dossier d'installation de Vert.x) :

		maven:http://maven.web-education.net/nexus/content/groups/public/

## Compiler et Lancer

Préparer le Springboard . Depuis son dossier de clonage (`path-to-our/springboard`) lancer :

		gradle init
		gradle generateConf

Si Neo4j est en mode serveur (propriété de configuration  `neo4jEmbedded=false`) installer manuellement le schema :

		neo4j-shell < scripts/schema.cypher

Lancer la plateforme avec le Springboard

		vertx runMod org.entcore~infra~{entcore.version} -conf ent-core.json

Le springboard résout et télécharge et les dépendances et lance la plate-forme. L'hôte d'accès par défaut est `localhost:8090`

__Remarques__ : _L'utilisateur qui lance le springboard doit avoir les droits sur le dossier d'installation de Vert.x, pour permettre l'installation de modules (Vert.x) systèmes_

## Développer

### Ajouter un application


Un template exemple d'application est disponible ici https://github.com/entcore/template

1. Cloner le template d'application 

2. Modifier le code et la configuration selon vos besoins

3. Déclarer l'application dans votre springboard. Ajouter dans la section `dependencies` du fichier `buid.gradle` :

		deployment "myApp.goupName:myApp.name:myApp.version:deployment"
		testCompile "myApp.goupName.name:myApp.version:tests"

4. Compiler et installer : `gradle clean install`

5. Redémarrer le springboard : `CTRL+C` puis  `vertx runMod org.entcore~infra~{entcore.version} -conf ent-core.json` 

### Débugage

Ajouter la variable d'environnement suivante pour debugger à distance (utile pour le Remote Debug depuis un IDE). Ici on écoute sur le port 5000
		export VERTX_OPTS='-Xdebug Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=5000'

