### Overview

I have developed a bash script that performs pinging of domains. This script is executed within a pod. The script retrieves the list of domains to ping from a configmap called `ping-urls`.

The script saves the ping data into a PostgreSQL database running in another pod. To connect to the database, you have set environment variables for the pod using a config called `postgres-config`. The password for the database is encoded and securely stored in a secret called `postgres-secret`.

To ensure data persistence for the PostgreSQL pod, have created a persistent volume (PV) and a persistent volume claim (PVC) specifically for it.

---

### postgres-config

    apiVersion: v1
    kind: ConfigMap
    metadata:
        name: postgres-config
    data:
        POSTGRES_DB: network
        POSTGRES_HOST: localhost
        POSTGRES_PORT: "5432"

This ConfigMap is used to provide environment variables for PostgreSQL database pod.

---

### postgres-secret

    apiVersion: v1
    kind: Secret
    metadata:
        name: postgres-secret
    type: Opaque
    data:
        POSTGRES_PASSWORD: ...
    stringData:
        POSTGRES_USER: dbuser

The above YAML code represents a Kubernetes Secret resource named `postgres-secret` and is used to provide user and pass for PostgreSQL database pod.

`POSTGRES_PASSWORD`: The value is the base64-encoded representation of the PostgreSQL password.

---

**Note:** 
To run a hostPath PV and Postgres pod on the same node:

- Create a label for the worker node:

    kubectl label nodes worker-1 name=worker-1

- Create a PersistentVolume (PV) with node affinity:

- Create a Postgres deployment with node affinity:

---

### postgres-pv and postgres-pvc

    apiVersion: v1
        kind: PersistentVolume
        metadata:
        name: postgres-pv
        labels:
            type: local
            app: postgres
        spec:
        nodeAffinity:
            required:
            nodeSelectorTerms:
                - matchExpressions:
                - key: name
                    operator: In
                    values:
                    - worker-1
        storageClassName: manual
        capacity:
            storage: 5Gi
        accessModes:
            - ReadWriteMany
        hostPath:
            path: "/data/db"



- It has a storage capacity of 5Gi.
- It can be accessed in read-write many mode.
- It is backed by a hostPath volume, which means that the data is stored on a local directory on the node.


<br>

    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
        name: postgres-pvc
        labels:
            app: postgres
    spec:
        storageClassName: manual
        accessModes:
          - ReadWriteMany
        resources:
            requests:
                storage: 5Gi

- It requests a storage capacity of 5Gi.
- It can be accessed in read-write many mode.

The PV represents the actual storage, while the PVC is used to request and claim that storage for use by an application. The postgres pod will use the `postgres-pvc` PVC to store its data.

### postgres-svc

By creating this Service, you enable other components within the Kubernetes cluster to access the Postgres deployment using the `postgres-service` name.

---

### postgres-deployment

- Environment Variables:
The envFrom field is used to inject environment variables from two sources: a Secret and a ConfigMap.
The Secret is referenced by secretRef with the name `postgres-secret`. It likely contains sensitive information like passwords or credentials.
The ConfigMap is referenced by configMapRef with the name `postgres-config`. It provides configuration data to the Pod.

- Persistent Volume and Persistent Volume Claim:
The Deployment specifies the use of persistent storage for the PostgreSQL data directory.
It defines a PersistentVolumeClaim (PVC) named `postgres-pvc` which is used to request storage from a PersistentVolume (PV) that matches the requested criteria.
The PVC is mounted to the container using the volumeMounts field with the name "postgres-database-storage" and the mount path "/var/lib/pgsql/data".

- Readiness and Liveness Probes:
The Deployment includes both readiness and liveness probes to ensure the proper functioning of the containerized PostgreSQL database.
The readiness probe is configured to execute the command `pg_isready -U postgres` and it starts checking for readiness after an initial delay of 5 seconds, repeating every 10 seconds.
The liveness probe is configured identically to the readiness probe, except that it starts checking for liveness after an initial delay of 30 seconds.

- Resource Limits and Requests:
The resources field specifies the resource requirements for the container.
limits restricts the maximum amount of CPU and memory the container can use. In this case, the limit is set to 500 milliCPU (0.5 CPU) and 512 Mebibytes (Mi) of memory.
requests specify the minimum amount of CPU and memory the container requires. It is set to 200 milliCPU (0.2 CPU) and 256 Mebibytes (Mi) of memory.

After applying this deployment, you can execute the psql command in the postgres pod to check the data.

    psql -U dbuser network
    select * from domain_info;

### ping-config

    apiVersion: v1
    kind: ConfigMap
    metadata:
        name: ping-urls
    data:
        urls: |
            google.com
            yahoo.com
            bing.com

You can use this ConfigMap to provide the list of URLs to ping them in the `ping`  pod. You can do this by mounting the ConfigMap to the pod.

### ping-deployment

- The container gets environment variables from the postgres-secret secret and the postgres-config config map.
- The container mounts the ping-urls config map at the /my-domain path.
- The container has a limit of 200m CPU and 256Mi memory, and a request of 100m CPU and 128Mi memory.
- The container uses the regsecret image pull secret to pull the image from a private registry.
- The Deployment uses the ping-urls config map to provide the list of URLs to ping to the ping-bash container.

### ping-bash deployment

- It connects to the postgres pod.
- It creates a table called domain_info in the Postgres database.
- It pings the URLs from the ping-urls config map, which is mounted in the /my-domain path.
- It runs the ping commands continuously every 30 seconds.
- It writes the data from the ping commands into the domain_info table in the Postgres database.

---

I've created `regsecret` for my private docker hub repo. for more information click [here](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/)


### Challenges

https://medium.com/@danielepolencic/learn-why-you-cant-ping-a-kubernetes-service-dec88b55e1a3
