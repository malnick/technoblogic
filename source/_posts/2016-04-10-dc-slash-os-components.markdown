---
layout: post
title: "DC/OS Components"
date: 2016-04-10 13:20:36 -0700
comments: true
categories: 
---
What are the core DC/OS components? What do we mean by components? 

By components, we're referring to the services which work together to bring the DC/OS ecosystem alive. The core component is of course [Apache Mesos](http://mesos.apache.org/) but the DC/OS is actually made of of *many* more services than just this.

If you log into any host in the DC/OS cluster, you can view the currently running services by inspecting `/etc/systemd/system/dcos.target.wants/`:

```bash
ip-10-0-6-126 system # ls dcos.target.wants/
dcos-adminrouter-reload.service  dcos-exhibitor.service        dcos-marathon.service
dcos-adminrouter-reload.timer    dcos-gen-resolvconf.service   dcos-mesos-dns.service
dcos-adminrouter.service         dcos-gen-resolvconf.timer     dcos-mesos-master.service
dcos-cluster-id.service          dcos-history-service.service  dcos-minuteman.service
dcos-cosmos.service              dcos-keepalived.service       dcos-signal.service
dcos-ddt.service                 dcos-logrotate.service        dcos-signal.timer
dcos-epmd.service                dcos-logrotate.timer          dcos-spartan.service
```

Let's take a closer look at what these services do. 

## Admin Router Service
Admin router is our core internal load balancer. Admin router is a customized [Nginx](https://www.nginx.com/resources/wiki/) which allows us to proxy all the internal services on :80. 

Without admin router being up, you could not access the DCOS UI. Admin router is a core component of the DC/OS ecosystem. 

```
[Unit]
Description=Admin Router: A high performance web server and a reverse proxy server
After=dcos-gen-resolvconf.service
ConditionPathExists=/var/lib/dcos/cluster-id

[Service]
Restart=always
StartLimitInterval=0
RestartSec=5
EnvironmentFile=/etc/environment
EnvironmentFile=/opt/mesosphere/environment
Type=forking
PIDFile=/opt/mesosphere/packages/adminrouter--1ec9969794ff4fcbde235d029652679b6a51e51e/nginx/logs/nginx.pid
PrivateDevices=yes
StandardOutput=journal
StandardError=journal
ExecStartPre=/bin/ping -c1 ready.spartan
ExecStartPre=/bin/ping -c1 marathon.mesos
ExecStartPre=/bin/ping -c1 leader.mesos
ExecStart=/opt/mesosphere/packages/adminrouter--1ec9969794ff4fcbde235d029652679b6a51e51e/nginx/sbin/nginx
ExecReload=/usr/bin/kill -HUP $MAINPID
KillSignal=SIGQUIT
KillMode=mixed
```

## Cluster ID Service
The cluster-id service allows us to generate a UUID for each cluster. We use this ID to track cluster health remotely (if enabled). This remote tracking allows our support team to better assist our customers. 

The cluster-id service runs an internal tool called `zk-value-consensus` which uses our internal Zookeeper to generate a UUID that all the masters agree on. Once an agreement is reached, the ID is written to disk at `/var/lib/dcos/cluster-id`. We write it to `/var/lib/dcos` so the ID is ensured to persist cluster upgrades without changing. 

```
[Unit]
Description=Cluster ID: Generates anonymous DCOS Cluster ID
[Service]
Type=oneshot
EnvironmentFile=/opt/mesosphere/environment
ExecStartPre=/bin/mkdir -p /var/lib/dcos
ExecStart=/bin/sh -c "/opt/mesosphere/bin/python -c 'import uuid; print(uuid.uuid4())'  | /opt/mesosphere/bin/zk-value-consensus /cluster-id > /var/lib/dcos/cluster-id"
```

## Cosmos Service
The Cosmos service is our internal packaging API service. You access this service everytime you run `dcos package install...` from the CLI. This API allows us to deploy DC/OS packages from the DC/OS universe to your DC/OS cluster.

```
[Unit]
Description=Package Service: DCOS Packaging API
After=dcos-mesos-master.service
After=dcos-gen-resolvconf.service

[Service]
Restart=always
StartLimitInterval=0
RestartSec=15
EnvironmentFile=/opt/mesosphere/environment
ExecStartPre=/bin/ping -c1 ready.spartan
ExecStartPre=/opt/mesosphere/bin/exhibitor_wait.py
## CoreOS
ExecStartPre=-/usr/bin/mkdir -p /var/lib/cosmos
## Ubuntu
ExecStartPre=-/bin/mkdir -p /var/lib/cosmos
ExecStart=/opt/mesosphere/bin/java -Xmx2G -jar "/opt/mesosphere/packages/cosmos--e5b42c8cd703c1eb7b83868b1
```

## Diagnostics (DDT) Service
The diagnostics service (also known as 3DT or dcos-ddt.service, no relationship to the pesticide!) is our diagnostics utility for DC/OS systemd components. This service runs on every host, tracking the internal state of the systemd unit. The service runs in two modes, with or without the `-pull` argument. If running on a master host, it executes `/opt/mesosphere/bin/3dt -pull` which queries MesosDNS for a list of known masters in the cluster, then queries a master (usually itself) `:5050/statesummary` and gets a list of slaves. 

From this complete list of cluster hosts, it queries all 3DT health endpoints (`:1050/system/health/v1/health`). This endpoint returns health state for the DC/OS systemd units on that host. The master 3DT processes, along with doing this aggregation also expose `/system/health/v1/` endpoints to feed this data by `unit` or `node` IP to the DC/OS user interface. 

```
[Unit]
Description=Diagnostics: DCOS Distributed Diagnostics Tool Master API and Aggregation Service
[Service]
EnvironmentFile=/opt/mesosphere/environment
Restart=always
StartLimitInterval=0
RestartSec=5
ExecStart=/opt/mesosphere/bin/3dt -pull
```

## Erlang Port Mapper (EPMD) Service

## Exhibitor Service

## Generate resolv.conf (gen-resolvconf) Serivce

## History Service

## Logrotate Service

## Marathon Service

## MesosDNS Service

## Minuteman Service

## Signal Service

## Spartan Service

