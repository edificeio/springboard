# About SpringBoard

Springboard is a boilerplate project to configure and run a education's portal based on ODE Frameworks.

* It's extensible with your own applications and widget
* It's customizable with ovverride of theme, template and translations and assets

# Installation 

Clone this repository and follow that [Insallation guide](https://opendigitaleducation.gitbooks.io/reference-manual/content/first-steps/simple-install.html) 

# Main Properties

To deep dive in configuration capabilities you can browse the [Properties Inventory](https://opendigitaleducation.gitbooks.io/reference-manual/content/advanced-topics/properties.html)

__General__

| Property | Value |
| -------- | ----- |
| mode      | dev |
| host      | http://localhost:8090 |
| httpProxy | true |

__Neo4J__

| Property | Value |
| -------- | ----- |
| neo4jUri | http://localhost:7474 |

__MongoDB__

| Property | Value |
| -------- | ----- |
| dbName    | ${MONGO_DB_NAME} |
| mongoHost | localhost |
| mongoPort | 27017 |

__Postgres__ (optionnal. usefull for application that needs relationnal data storage)

| Property | Value |
| -------- | ----- |
| sqlUrl      | jdbc:postgresql://localhost:5432/$PSQL_DB_NAME?stringtype=unspecified |
| sqlUsername | $PSQL_USER |
| sqlPassword | $PSQL_USER_PWD |

__Skin__ (to map skin with domain and define skin's theme)
    
| Property | Value |
| -------- | ----- |
|    skin   | leo |
|    skins  | {"localhost:8090":"leo"} |
|    themes | {"_id": "default","displayName": "default","path": "/assets/themes/leo/default/"},{"_id": "dyslexic","displayName": "dyslexic","path": "/assets/themes/leo/dyslexic/"} |



