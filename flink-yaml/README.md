 # Deploying Flink Cluster

<br>

---
> **_NOTE:_**  Below instructions are tested for flink 1.12.  
> These Yaml files for flink cluster only support one flink cluster per AKS cluster
---

<br>

 Once you have aks cluster deployed, Make sure you are pointing to the right aks cluster by running

 ```shell
  # Find the current cluster that kubectl is pointing to
  kubectl config get-contexts

  # Change the cluster
  kubectl config use-context <clusterName>
 ```

 ## Deploy the kubernetes resources for the flink cluster

```shell

# Give permissions for the default service account
kubectl create clusterrolebinding flink-role-binding-default --clusterrole=edit --serviceaccount=default:default

# Create Persistent volume claimset. 
# This creates the pvc which is then used in both job manager and task manager as shared storage for storing checkpoints, savepoints etc..
kubectl apply -f session-cluster/pvc.yaml

# apply flink config map
 kubectl apply -f flink-configuration-configmap.yaml

# create job manager service
kubectl apply -f jobmanager-service.yaml

# create Job manager deployment
kubectl apply -f session-cluster/jobmanager-session-deployment.yaml

# create Task manager deployment
kubectl apply -f session-cluster/taskmanager-session-deployment.yaml

# Create Jobmanager rest service so that you can access the rest service from outside the aks cluster
kubectl apply -f opt/jobmanager-rest-service.yaml

# Optional - Create task manager query state to access the query state service from outside the aks cluster
kubectl apply -f opt/taskmanager-query-state-service.yaml 

```

## [Optional] Enabling Auto Scaling on the flink cluster

This [autoscale.yaml](./flink-1.12/opt/autoscale.yaml) file has auto scale configurations for the flink cluster. 

```shell
kubectl apply -f opt/autoscale.yaml
```

## Accessing the flink web ui

```shell
# Forward the webui port from the jobmanager to the localhost 
kubectl port-forward deployment/flink-jobmanager 8081:8081
```
Navigate to http://localhost:8081 from your browser

## Accessing the Flink Sql shell

```shell
# login to the jobmanager pod
kubectl exec --stdin --tty deployment/flink-jobmanager -- /bin/bash

# Start the shell
./bin/sql-client.sh embedded
```

## Testing few commands on SQL shell

Below are few sql commands from [here](https://ci.apache.org/projects/flink/flink-docs-stable/dev/table/sqlClient.html) and [here](https://git.corp.linkedin.com:1367/a/plugins/gitiles/multiproducts/flink-base-image-slim/+/master/README.md)

> Please note that kafka catalogs are not enabled in this setup

```sql
SELECT 'Hello World';

SELECT name, COUNT(*) AS cnt FROM (VALUES ('Bob'), ('Alice'), ('Greg'), ('Bob')) AS NameTable(name) GROUP BY name;

CREATE TABLE datagen ( 
 f_sequence INT, 
 f_random INT, 
 f_random_str STRING, 
 ts AS localtimestamp, 
 WATERMARK FOR ts AS ts 
) WITH ( 
 'connector' = 'datagen', 
 -- optional options -- 
 'rows-per-second'='1000', 
 'fields.f_sequence.kind'='sequence', 
 'fields.f_sequence.start'='1', 
 'fields.f_sequence.end'='1000000', 
 'fields.f_random.min'='1', 
 'fields.f_random.max'='1000', 
 'fields.f_random_str.length'='10' 
); 

-- simple stuff 
select * from datagen; 
 
-- Window stuff 
SELECT 
TUMBLE_START(ts, INTERVAL '1' MINUTE) as window_start, 
TUMBLE_END(ts, INTERVAL '1' MINUTE) as window_end, 
SUM(f_sequence) as sum_seq, 
AVG(f_random) as avg_random, 
COUNT(f_random_str) as count_str, 
COUNT(distinct f_random_str) 
FROM datagen 
GROUP BY TUMBLE(ts, INTERVAL '1' MINUTE); 

```

## Running the Flink sample job on the Cluster

- Download the latest flink distribution from https://flink.apache.org/downloads.html
- Expand the tarball

```shell
# Start the job
./bin/flink run -m localhost:8081 ./examples/streaming/TopSpeedWindowing.jar

# Starting the job in detached mode with parallelism of 3
./bin/flink run -d -p 3 -m localhost:8081 ./examples/streaming/TopSpeedWindowing.jar
# Take note of the job id printed above
```
---
>  **_Please note that the checkpointing is not enabled in the sample._**  <br>
Flink TopSpeedWindowing sample with checkpointing enabled is forked [here](https://dev.azure.com/StreamsFlink/Flink/_git/flink-samples?path=%2Fflink-examples-streaming%2Fsrc%2Fmain%2Fjava%2Forg%2Fapache%2Fflink%2Fstreaming%2Fexamples%2Fwindowing%2FTopSpeedWindowing.java)<br>
To test checkpointing, please use the jar from [here](https://dev.azure.com/StreamsFlink/eb87a937-1e2d-4513-82ff-9cf55c93cbc7/_apis/git/repositories/0a9cb03f-9ca3-4e59-ab52-62289533d2ff/items?path=%2Fjars%2Fflink-examples-streaming-0.1.0.jar&versionDescriptor%5BversionOptions%5D=0&versionDescriptor%5BversionType%5D=0&versionDescriptor%5Bversion%5D=master&resolveLfs=true&%24format=octetStream&api-version=5.0&download=true). 
---

- You should be able to look at the running job in the flink web ui. 
- You can play with the flink UI to look at the job manager logs, task manager logs, tasks. 

You can view the output from the sample job by fetching the logs from the task manager 
```shell
# fetching logs from task manager
kubectl logs deployment/flink-taskmanager
```

## Taking the savepoint and stopping the job

Stopping the job will take the savepoint by default. You can follow below instructions to stop the job. 
- Get the job ID. Job id is printed in the console when you started the job (or) 
- you can get the job id from the flink web ui (or)
- By listing all the jobs using ./bin/flink 

```shell
# replace <jobid> with the actual job id. You 
./bin/flink stop -m localhost:8081 <jobId>

# please note the savepoint path from the above command
```


## Restart the job from the savepoint

Savepoints allow you restart the job from the previous position with a different parallelism. You can use the below command to start the job using the existing savepoint with a different parallelism.
```shell
./bin/flink run -d -p 5 -m localhost:8081 ./examples/streaming/TopSpeedWindowing.jar -s file:/opt/flink/shared-state/savepoints/savepoint-a30bfc-ef619f978230
```




