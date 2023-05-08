#!/bin/bash
#
# Examples:
#   export REGISTRY_URL= us-central1-docker.pkg.dev/PROJECT_ID/REPO_NAME  # Docker Artifact registry repository URL
#   ./build-docker-extras.sh
#   EXTRAS_NAMES=extra_1,extra_2 ./build-docker-extras.sh
#   EXTRAS_NAMES="extra_1 extra_2" ./build-docker-extras.sh
#
#   export LOCAL=true
#   ./build-docker-extras.sh
#   EXTRAS_NAMES=extra_1,extra_2 ./build-docker-extras.sh
#   EXTRAS_NAMES="extra_1 extra_2" ./build-docker-extras.sh

set -e

BASE_DIR=$(dirname $0)

if [[ -z "$EXTRAS_NAMES" ]]; then
    EXTRAS_NAMES=$(find $BASE_DIR -type f -name 'requirements.*.txt' | grep -Po '(?<=requirements\.)[^.]+')
elif [[ ! -z "$(echo $EXTRAS_NAMES | grep -o ',')" ]]; then
    EXTRAS_NAMES=$(echo $EXTRAS_NAMES | sed 's/,/\n/g' | sed '/^\s*$/d')
fi

IMAGE_VERSION=$(date +%F_%H-%M-%S)
if [[ "$LOCAL" = true ]]; then
    if [[ -z "$GOOGLE_APPLICATION_CREDENTIALS" ]]; then
        ADDITIONAL_OPTIONS=()
    else
        CREDENTIALS_FILE="secrets/credentials"
        mkdir -p "$(dirname $BASE_DIR/$CREDENTIALS_FILE)"
        cp "$GOOGLE_APPLICATION_CREDENTIALS" "$BASE_DIR/$CREDENTIALS_FILE"
        ADDITIONAL_OPTIONS=(
            --build-arg "GOOGLE_APPLICATION_CREDENTIALS=$CREDENTIALS_FILE"
            -f "$BASE_DIR/Dockerfile.google_app_credentials"
        )
    fi

    for EXTRA_NAME in $EXTRAS_NAMES; do
        IMAGE_REF_1="${EXTRA_NAME}:${IMAGE_VERSION}"
        IMAGE_REF_2="${EXTRA_NAME}:latest"

        echo "Building: $IMAGE_REF_1"
        docker build \
            -t ${IMAGE_REF_1} \
            -t ${IMAGE_REF_2} \
            --build-arg EXTRA=${EXTRA_NAME} \
            ${ADDITIONAL_OPTIONS[@]} \
            $BASE_DIR
    done
elif [[ -z "$REGISTRY_URL" ]]; then
    echo >&2 'Undefined REGISTRY_URL'
    exit 1
else
    gcloud config set builds/use_kaniko True
    for EXTRA_NAME in $EXTRAS_NAMES; do
        IMAGE=${REGISTRY_URL}/${EXTRA_NAME}
        IMAGE_REF="${IMAGE}:${IMAGE_VERSION}"

        echo "Building: $IMAGE_REF"
        gcloud builds submit $BASE_DIR \
            --config $BASE_DIR/cloudbuild.yaml \
            --substitutions _IMAGE=$IMAGE,_MODULE_EXTRA=$EXTRA_NAME,_IMAGE_VERSION=$IMAGE_VERSION
    done
fi
