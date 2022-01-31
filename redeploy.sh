oc delete secret token-introspection-context
oc create secret generic token-introspection-context \
    --from-file=./apicast-policy.json \
    --from-file=./init.lua \
    --from-file=./token_introspection_context.lua \
    --from-file=./tokens_cache.lua
oc get pods | grep my-gateway | awk '{ print $1 }' | xargs oc delete pod
oc get pods -w | grep my-gateway 
