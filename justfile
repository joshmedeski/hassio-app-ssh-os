image_name := "hass-ssh-test"
ssh_port := "2222"
base_image := if arch() == "aarch64" { "ghcr.io/home-assistant/aarch64-base:3.21" } else { "ghcr.io/home-assistant/amd64-base:3.21" }
build_arch := if arch() == "aarch64" { "aarch64" } else { "amd64" }

build:
    docker build \
        --build-arg BUILD_FROM={{ base_image }} \
        --build-arg BUILD_ARCH={{ build_arch }} \
        -t {{ image_name }} .

run: build
    docker rm -f {{ image_name }} 2>/dev/null || true
    docker run -d \
        --name {{ image_name }} \
        -p {{ ssh_port }}:22 \
        -v {{ justfile_directory() }}/tests/options.json:/data/options.json:ro \
        -v {{ justfile_directory() }}/tests/entrypoint.sh:/entrypoint.sh:ro \
        --entrypoint /bin/bash \
        {{ image_name }} \
        /entrypoint.sh
    @echo "Container started. SSH: ssh -p {{ ssh_port }} root@localhost (password: testpassword)"

test:
    @bash tests/test.sh

stop:
    docker rm -f {{ image_name }} 2>/dev/null || true

ssh:
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p {{ ssh_port }} root@localhost

logs:
    docker logs -f {{ image_name }}
