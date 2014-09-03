SET PATH=%PATH%;tools\vertx\bin;tools\gradle\bin;tools\jdk\bin

tasklist /nh /fi "imagename eq mongod.exe" | find /i "mongod.exe" > nul || (start cmd /k tools\mongodb\bin\mongod.exe --dbpath tools\mongodb-data)
vertx runMod org.entcore~infra~1.9-SNAPSHOT -conf ent-core.embedded.json
