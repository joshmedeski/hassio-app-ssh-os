image_name := "hass-ssh-test"
ssh_port := "2222"
mosh_port := "60000"
base_image := if arch() == "aarch64" { "ghcr.io/home-assistant/aarch64-base:3.21" } else { "ghcr.io/home-assistant/amd64-base:3.21" }
build_arch := if arch() == "aarch64" { "aarch64" } else { "amd64" }

build:
    docker build \
        --build-arg BUILD_FROM={{ base_image }} \
        --build-arg BUILD_ARCH={{ build_arch }} \
        -t {{ image_name }} ssh-os

run: build
    docker rm -f {{ image_name }} 2>/dev/null || true
    docker run -d \
        --name {{ image_name }} \
        -p {{ ssh_port }}:22 \
        -p {{ mosh_port }}:{{ mosh_port }}/udp \
        -v {{ justfile_directory() }}/tests/options.json:/data/options.json:ro \
        -v {{ justfile_directory() }}/tests/entrypoint.sh:/entrypoint.sh:ro \
        -v {{ justfile_directory() }}/tests/homeassistant:/homeassistant \
        -v {{ justfile_directory() }}/tests/mock-ha.sh:/tests/mock-ha.sh:ro \
        --entrypoint /bin/bash \
        {{ image_name }} \
        /entrypoint.sh
    @echo "Container started. SSH: ssh -p {{ ssh_port }} ha@localhost (password: testpassword)"

test:
    @bash tests/test.sh

stop:
    docker rm -f {{ image_name }} 2>/dev/null || true

ssh:
    sshpass -p testpassword ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {{ ssh_port }} ha@localhost

mosh:
    SSHPASS=testpassword mosh --ssh="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {{ ssh_port }}" --port={{ mosh_port }} ha@localhost

logs:
    docker logs -f {{ image_name }}
