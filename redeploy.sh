oc delete secret jwe-token-introspection
oc create secret generic jwe-token-introspection \
    --from-file=./policy/apicast-policy.json \
    --from-file=./policy/init.lua \
    --from-file=./policy/jwe-token-introspection.lua \
    --from-file=./policy/tokens_cache.lua
oc get pods | grep my-gateway | awk '{ print $1 }' | xargs oc delete pod
oc get pods -w | grep my-gateway 
