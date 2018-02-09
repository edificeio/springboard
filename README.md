# About SpringBoard

Springboard is a boilerplate project to configure and run a education's portal based on ODE Frameworks.

* It's extensible with your own applications and widget
* It's customizable by ovverriding the theme, template, i18n file and others assets

# Installation 

Clone this repository and follow that [Insallation guide](https://opendigitaleducation.gitbooks.io/reference-manual/content/first-steps/) 

# Main Properties

To deep dive in configuration capabilities you can browse the [Properties Inventory](https://opendigitaleducation.gitbooks.io/reference-manual/content/ops/advanced-topics/properties-inventory.html)

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
    
| Property   | Value |
| ---------- | ----- |
| skins      | {"localhost:8090":"ode", "localhost:9000":"ode""} |
| assetsPath | ../.. |


