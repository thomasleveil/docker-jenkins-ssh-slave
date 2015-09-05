#!/usr/bin/env bats

SUT_IMAGE=jenkins-ssh-slave
SUT_CONTAINER=bats-jenkins-ssh-slave
JENKINS_CONTAINER=bats-jenkins

load test_helpers
load keys

@test "build image" {
	cd $BATS_TEST_DIRNAME/..
	docker build -t $SUT_IMAGE .
}

@test "clean test container" {
	docker kill $SUT_CONTAINER &>/dev/null ||:
	docker rm -fv $SUT_CONTAINER &>/dev/null ||:
	docker kill $JENKINS_CONTAINER &>/dev/null ||:
	docker rm -fv $JENKINS_CONTAINER &>/dev/null ||:
}

@test "create slave container" {
	docker run -d --name $SUT_CONTAINER -P $SUT_IMAGE "$PUBLIC_SSH_KEY"
}

@test "create jenkins master container" {
	docker run -d \
		--name $JENKINS_CONTAINER \
		-p 8080 \
		--link $SUT_CONTAINER:slave \
		--volume $BATS_TEST_DIRNAME/init.groovy.d/:/usr/share/jenkins/ref/init.groovy.d/:ro \
		jenkins
	# add the private ssh key to the master
	docker exec -u jenkins $JENKINS_CONTAINER sh -c "
		mkdir /var/jenkins_home/.ssh
		echo '$PRIVATE_SSH_KEY' >/var/jenkins_home/.ssh/id_rsa
	"
}

@test "slave container is running" {
	sleep 1  # give time to sshd to eventually fail to initialize
	retry 3 1 assert "true" docker inspect -f {{.State.Running}} $SUT_CONTAINER
}

@test "connection with ssh + private key" {
	run_through_ssh echo f00

	[ "$status" = "0" ] && [ "$output" = "f00" ] \
		|| (\
			echo "status: $status"; \
			echo "output: $output"; \
			false \
		)
}

@test "slave.jar can be executed" {
	run_through_ssh java -jar /usr/share/jenkins/slave.jar --help

	[ "$status" = "0" ] \
		&& [ "${lines[0]}" = '"--help" is not a valid option' ] \
		&& [ "${lines[1]}" = 'java -jar slave.jar [options...]' ] \
		|| (\
			echo "status: $status"; \
			echo "output: $output"; \
			false \
		)
}

@test "Jenkins master container is running" {
	sleep 1  # give time to eventually fail to initialize
	retry 3 1 assert "true" docker inspect -f {{.State.Running}} $JENKINS_CONTAINER
}

@test "Jenkins master is initialized" {
	retry 30 5 curl_jenkins /api/json
}

@test "slave node created on master" {
	retry 2 5 curl_jenkins /computer/test-slave/
}

@test "Jenkins node connected" {
	jq_is_available_or_skip
	local url=$(get_jenkins_url)/computer/test-slave/api/json
    assert "false" sh -c "curl -sS --fail $url | jq '.offline'"
}

