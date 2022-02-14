TOKEN=f6d72b42f17dd38113af394404524febbe0903c4205740f8d0b5d3760151312b
TSCALE_URL=3scale-admin.apps.cluster-b851.b851.sandbox243.opentlc.com
IMAGE_ADDRESS=registry.access.redhat.com/3scale-amp20/apicast-gateway:1.0
APICAST_CONFIGURATION_CACHE=0
THREESCALE_DEPLOYMENT_ENV=staging
APICAST_CONFIGURATION_LOADER=lazy
APICAST_LOG_LEVEL=debug
THREESCALE_CONFIG_FILE=apicast-config-api-sandbox-1.json

docker run --rm -it -p 8080:8080 \
    -v "$(pwd)/policy:/opt/app-root/policies/jwt-token-introspection-policy/1.0" \
    -v "$(pwd):/opt/app-root/custom" \
    -e THREESCALE_CONFIG_FILE=custom/apicast-config-api-sandbox-1.json \
    -e APICAST_CONFIGURATION_CACHE=$APICAST_CONFIGURATION_CACHE \
    -e THREESCALE_DEPLOYMENT_ENV=$THREESCALE_DEPLOYMENT_ENV \
    -e APICAST_CONFIGURATION_LOADER=$APICAST_CONFIGURATION_LOADER \
    -e APICAST_LOG_LEVEL=$APICAST_LOG_LEVEL \
    -e THREESCALE_PORTAL_ENDPOINT="https://$TOKEN@$TSCALE_URL" \
    $IMAGE_ADDRESS