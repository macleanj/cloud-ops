# Resize of volumeClaimTemplate
Terraform will not be able to take care of volume increase itself, only the config. Follow the following procedures to enlarge the disk space:
```
kubectl edit pvc <name>                     # for each PVC in the StatefulSet, to increase its capacity in line with the new capacity specs in the Terraform config.
kubectl delete sts --cascade=orphan <name>  # to delete the StatefulSet and leave its pods.

# Use the following command to verify the resize status:
kubectl get pvc prometheus-monitoring-kube-prometheus-prometheus-db-prometheus-monitoring-kube-prometheus-prometheus-0 -o json | jq -r '.status'
# type: Resizing                            -> wait
# type: FileSystemResizePending             -> Continue with redeploying the StatefulSet to finalize the resizing of the corresponding pods.

terragrunt taint helm_release.main          # to enable Terraform for StatefulSet config change
terragrunt apply                            # to recreate the StatefulSet with new config

```

Manually
```
kubectl edit pvc <name>                     # for each PVC in the StatefulSet, to increase its capacity.
kubectl delete sts --cascade=orphan <name>  # to delete the StatefulSet and leave its pods.

# Check resizing status. See above.

kubectl apply -f <name>                     # to recreate the StatefulSet after config change . taint if needed.
kubectl rollout restart sts <name>          # to restart the pods, one at a time. During restart, the pod's PVC will be resized.
```

Sources:
- https://kubernetes.io/blog/2018/07/12/resizing-persistent-volumes-using-kubernetes/
- https://strimzi.io/blog/2019/02/28/resizing-persistent-volumes/