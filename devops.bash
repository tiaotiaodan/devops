#!/bin/bash

#Data/time
CTIME=$(date "+%F-%H-%M")

#shell ENV
SHELL_NAME="deploy.sh"
SHELL_DIR="/data/deploy"
SHELL_LOG="${SHELL_DIR}"/"${SHELL_NAME}.log"
LOCK_FILE="/tmp/${SHELL_NAME}.lock"

#APP ENV
PKG_NAME="/data/pkg"
JENKINS_NAME_DIR="devops-demo-sit-stage"
CODE_DIR="/data/deploy/code"			
CONFIG_DIR="/data/deploy/config" 		
TMP_DIR="/data/deploy/tmp"       		
TAR_DIR="/data/deploy/pkg"       		
PKG_SERVER="192.168.3.176"     			


shell_log(){
	LOG_INFO=$1
	echo "$CTIME  ${SHELL_NAME}  :  ${LOG_INFO}"  >> ${SHELL_LOG}
}

shell_lock(){
	touch "${LOCK_FILE}"
}

shell_unlock(){
	rm -f "${LOCK_FILE}"
}

usage(){
	echo "Usage:  $0 [env deploy version] | rollback-list  | rollback  |fastrollback "
}


get_pkg(){
	echo "get pkg"
	shell_log "Get PKG"
	[ -d ${CODE_DIR}/${JENKINS_NAME_DIR} ]   ||  mkdir -p ${CODE_DIR}/${JENKINS_NAME_DIR} 
	scp root@${PKG_SERVER}:${PKG_NAME}/${JENKINS_NAME_DIR}/${JENKINS_NAME_DIR}.tar.gz   ${CODE_DIR}/${JENKINS_NAME_DIR}
}

config_pkg(){
	echo "config pkg"
	shell_log "Get PKG"
	[  -d ${TMP_DIR}/${JENKINS_NAME_DIR}/${JENKINS_NAME_DIR} ] && echo yes || mkdir -p ${TMP_DIR}/${JENKINS_NAME_DIR}/${JENKINS_NAME_DIR}
	cd ${CODE_DIR}/${JENKINS_NAME_DIR} &&   tar  -xzf  ${JENKINS_NAME_DIR}.tar.gz  -C  ${TMP_DIR}/${JENKINS_NAME_DIR}/${JENKINS_NAME_DIR} 
	/bin/cp   -a ${CONFIG_DIR}/${JENKINS_NAME_DIR}/demo-config/$DEPLOY_ENV/* ${TMP_DIR}/${JENKINS_NAME_DIR}/${JENKINS_NAME_DIR} 
	/bin/cp  -a  ${TMP_DIR}/${JENKINS_NAME_DIR}/${JENKINS_NAME_DIR} ${TMP_DIR}/${JENKINS_NAME_DIR}/${JENKINS_NAME_DIR}-${CTIME} 
	[  -d ${TAR_DIR}/${JENKINS_NAME_DIR} ] && echo yes || mkdir -p ${TAR_DIR}/${JENKINS_NAME_DIR}
	cd ${TMP_DIR}/${JENKINS_NAME_DIR}/
	tar -czPf  ${TAR_DIR}/${JENKINS_NAME_DIR}/${JENKINS_NAME_DIR}-${CTIME}.tar.gz ${JENKINS_NAME_DIR}-${CTIME}
	cd ${TMP_DIR}/${JENKINS_NAME_DIR} && rm -rf *
}

scp_pkg(){
	echo "scp pkg"
	shell_log "SCP pkg"
	scp -r ${TAR_DIR}/${JENKINS_NAME_DIR}/${JENKINS_NAME_DIR}-${CTIME}.tar.gz root@192.168.3.175:/usr/local/nginx/html/
}

deploy_pkg(){
	echo "deploy pkg"
	shell_log "Deploy PKG"
	ssh root@192.168.3.175 "cd /usr/local/nginx/html && tar zxf ${JENKINS_NAME_DIR}-${CTIME}.tar.gz && rm -f /usr/local/nginx/html/www && ln -s /usr/local/nginx/html/${JENKINS_NAME_DIR}-${CTIME} /usr/local/nginx/html/www"
}

test_pkg(){
	echo "test pkg"
	STATUS=$(curl -s --head http://192.168.3.175 | grep '200' | wc -l)
	if [ $STATUS = 1 ];then
		echo "自动化测试通过"
	else
		echo "自动化测试失败"
		exit;
	fi
}

fast_rollback(){
	echo "fast rollback"
}

rollback(){
	echo "rollback"
	shell_log "rollback"
	ssh root@192.168.3.175 "rm -f /usr/local/nginx/html/www && ln -s /usr/local/nginx/html/$DEPLOY_VER /usr/local/nginx/html/www"
}

rollback_list(){
	echo "rollback list"
	ssh root@192.168.3.175 "ls -l /usr/local/nginx/html/*.tar.gz"
}

main(){
	DEPLOY_ENV=$1
	DEPLOY_TYPE=$2
	DEPLOY_VER=$3
	if [ -f "${LOCK_FILE}" ]
		then
		shell_log "${SHELL_NAME}" is running
		echo "${SHELL_NAME}" IS running && exit
	fi
	shell_lock
	case $DEPLOY_TYPE in
		deploy)
			get_pkg
			config_pkg
			scp_pkg
			deploy_pkg
			test_pkg
			;;
		rollback)
			rollback $DEPLOY_VER
			;;
		fast_rollback)
			fast_rollback
			;;
		rollback_list)
			rollback_list
			;;
		test_pkg)
            test_pkg
            ;;
		*)
			usage
			;;
	esac
	shell_unlock
}

main $1 $2 $3
