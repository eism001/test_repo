##################
# Achtung: Dieses Skript wird im OLS SVN gepflegt und sollte auch dort angepasst werden.
# Anschliessen sollten die Anpassung auch in die anderen oCRM Projekte (BS, LA, BE, OLS) eingepflegt werden.
# https://svn.bpghub.de/svn/deutschlandcard/trunk/10_Tools/jenkins/oracle_start_script.sh
##################


export LANG=de_DE@euro
export TZ="Europe/Berlin"
export DB_NAME="dcardolsxe"
export DB_PORT="1555"

function oracleIsUseable() {
	echo -n "Pruefe ob die Oracle laeuft..."
	docker ps | grep $DB_NAME | grep "(healthy)" >>/dev/null
	ret=$?
	if [ "$ret" == "0" ];then
		echo ok
		return 0
	else
		echo not ok
		return 1
	fi
}

function killOracle() {
    docker rm -f -v $DB_NAME || true
}

function waitForOracle() {
	COUNTER=0
	MAX_TRIES=50
    until oracleIsUseable || [ $COUNTER -gt $MAX_TRIES ]
    do
        echo "Waiting for Oracle XE to start...($(date))"
        sleep 30
		let COUNTER=COUNTER+1
    done
	if [ $COUNTER -gt $MAX_TRIES ]; then
		(>&2 echo "Oracle cannot be started.")
		exit 99
	fi
}

function startOracle() {
    docker run --name $DB_NAME -e ORACLE_PWD=oracle --shm-size=1g -m 3G  -d -p $DB_PORT:1521 -e TZ=$TZ container-registry.oracle.com/database/express:18.4.0-xe
    waitForOracle
    docker exec -i --user=oracle $DB_NAME bash -c 'echo -e "alter system disable restricted session;" | sqlplus / as sysdba@XE'
    docker exec -i --user=oracle $DB_NAME bash -c 'echo -e "ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME UNLIMITED" | sqlplus / as sysdba@XE'
	docker ps -a | grep $DB_NAME || true
}

function createOracleUser() {
	if [ -e $TEST_DB_USER ]; then
		export TEST_DB_USER="jenkins"
	fi
	echo "Erstelle DB-Nutzer $TEST_DB_USER"
    docker exec -i --user=oracle $DB_NAME bash -c "echo -e 'alter session set \"_ORACLE_SCRIPT\"=true;\n create user $TEST_DB_USER identified by jenkins; \n grant all privileges to $TEST_DB_USER;' | sqlplus / as sysdba@XE"	
}

function deleteOracleUser() {
	if [ -e $TEST_DB_USER ]; then
		export TEST_DB_USER="jenkins"
	fi
	echo "Lösche DB-Nutzer $TEST_DB_USER"
    docker exec -i --user=oracle $DB_NAME bash -c "echo -e 'alter session set \"_ORACLE_SCRIPT\"=true;\n drop user $TEST_DB_USER cascade;' | sqlplus / as sysdba@XE"	
}

echo "Aktueller Jenkins Workspsace: $(pwd)"

case "$1" in
    start)
		if ! oracleIsUseable; then
			killOracle
			startOracle
		fi
    ;;
    stop)
		killOracle
    ;;
    createOracleUser)
		createOracleUser               
    ;;
    deleteOracleUser)
    	deleteOracleUser
    ;;
esac

