#/!/usr/bin/env just

# Extract dockerfile from an image
extract-dockerfile image output="Dockerfile":
    @echo "Extracting Dockerfile from {{image}}..."
    docker pull {{image}}
    docker pull alpine/dfimage:latest
    docker run -v /var/run/docker.sock:/var/run/docker.sock --rm alpine/dfimage -sV=1.36 {{image}} | tail -n +2 > {{output}}
    @echo "Dockerfile extracted to {{output}}"

# Extract dockerfile from a crowdbotics image
extract-cb-dockerfile version:
    @just extract-dockerfile crowdbotics/cb-django:{{version}}-slim-buster ./images/xperts-{{version}}/Dockerfile

dive-cb-dockerfile version:
    dive crowdbotics/cb-django:{{version}}-slim-buster

# Cleans up orphaned images and volumes
clean-docker:
    @echo "Cleaning up orphaned Docker images and volumes..."
    docker image prune -a -f
    docker volume prune -f
    @echo "Cleanup complete."