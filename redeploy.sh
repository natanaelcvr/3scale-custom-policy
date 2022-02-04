oc delete secret jwe-token-introspection
oc create secret generic jwe-token-introspection \
    --from-file=./apicast-policy.json \
    --from-file=./init.lua \
    --from-file=./jwe-token-introspection.lua \
    --from-file=./tokens_cache.lua
oc get pods | grep my-gateway | awk '{ print $1 }' | xargs oc delete pod
oc get pods -w | grep my-gateway 
