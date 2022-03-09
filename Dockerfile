# Container image that runs your code
FROM nikodonoso86/base-image:latest

# Copies your code file from your action repository to the filesystem path `/` of the container
RUN aws s3 cp s3://swish-gh-actions/entrypoints/config-handler.sh entrypoint.sh
# COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]