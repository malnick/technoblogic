---
layout: post
title: "A Restful Haproxy Service Abstraction"
date: 2015-07-31 06:05:55 -0700
comments: true
categories: 
---
A major hurdle of microservices is visibility into the versions of your deployed infrastructure. At SRC:CLR we have 7 different micro services plus our platform that drive our product. These services are deployed as immutable infrastructure, their IP's and configuration is fluid and changing all the time. During a deployment, we might to a canary update of our services, but having to manually query the ```/info``` endpoint across 'n' number of nodes, IP addresses, and dynamic management port assignments is error prone and difficult. In order to gain visibility into the currently running services, we wrote a tool that finds available services by querying our frontend and internal loadbalancers for running services, and then queries those running services to get their running versions and display them in a lightweight frontend.

<!-- more -->

In order to get the server lines and service names from Haproxy we [wrote a tool called REST Haproxy](https://github.com/malnick/rest_haproxy) which allows us to query our haproxy for "service" abstractions. 

Given a haproxy configuration at path ```/etc/haproxy/haproxy.cfg```:

```ini
global
  daemon
  group  haproxy
  log  127.0.0.1 local0
  log  127.0.0.1 local1 notice
  maxconn  4096

defaults
  log global
  mode  http

frontend http-in
  bind *:80
  acl service path_beg -t /service
  acl other_service path_beg -t /other_service
  default backend my_service
  use_backend service if my_service
  use_backend other_service if other_service

backend service
  balance leastconn
  server service-01 10.0.1.10:31501 check port 32501
  server service-02 10.0.1.10:21502 check port 32502
  server service-03 10.0.2.10:31500 check port 32501
  server service-04 10.0.2.11:31500 check port 32502

backend other_service
  balance leastconn
  server service-01 10.0.5.10:31501 check
  server service-02 10.0.5.10:21502 check
  server service-03 10.0.5.10:31503 check
  server service-04 10.0.5.11:31500 check
```

Will result in the following JSON endpoint available at: ```localhost:3000/services```

```json
{
  "Service": {
    "other_service": [
      "10.0.5.10:31501",
      "10.0.5.10:21502",
      "10.0.5.10:31503",
      "10.0.5.11:31500"
    ],
    "service": [
      "10.0.1.10:31501 10.0.1.10:32501",
      "10.0.1.10:21502 10.0.1.10:32502",
      "10.0.2.10:31500 10.0.2.10:32501",
      "10.0.2.11:31500 10.0.2.11:32502"
    ]
  }
}
``` 

Initially, I thought about writing this in Ruby. It is my best language after all. But recently I've been bothered by Ruby. Mainly, I get bitten by not having the correct Ruby version installed on a machine, or having to install a whole suite of Ruby / gems versions. 

Shipping code in Ruby is inexpensive in that all you need to do is ```gem build && gem push``` but the heavyweight nature of an interpreted language wasn't something I wanted running on my lightweigtht Haproxy boxes. These boxes should be *only* Haproxy, and nothing else. 

I felt dirty enough having to install Java on them in order to ship logs with logstash, adding yet more libraries just didn't feel right...

## So I wrote it in GoLang...
GoLang is rad. Enough said. Why? Because it compiles directly to assembly. The Go tool has enough functionality that it makes it easy enough to test and run code locally, and if you don't want to ship a binary executable you can always dockerize it (but don't use a heavyweight base image!). 

For the REST Haproxy service I decided to host the executable on our downloads server, the source code was open source'ed after all. I then wrote a [some configuration management code](https://github.com/malnick/puppet-rest_haproxy) to wget the binary, and install a basic init script so it was available as a service.

## Results 
The result is a 7.5MB binary that runs on any AMD64 architecture. I don't need to configure any extra interpreters on the machine running the application and I don't need to manage issues that arise from that type of deployment. 

The service comes up instantly when started:

```bash
root@qa-haproxy-internal-recanted:/opt/rest_haproxy# time /etc/init.d/rest_haproxy start
     (       (                )      (
     )\ )    )\ )  *   )   ( /(      )\ )
    (()/((  (()/(` )  /(   )\())   )(()/((          ) (
     /(_))\  /(_))( )(_)) ((_)\ ( /( /(_))(   (  ( /( )\ )
    (_))((_)(_)) (_(_())   _((_))(_)|_))(()\  )\ )\()|()/(
    | _ \ __/ __||_   _|  | || ((_)_| _ \((_)((_|(_)\ )(_))
    |   / _|\__ \  | |    | __ / _` |  _/ '_/ _ \ \ /| || |
    |_|_\___|___/  |_|    |_||_\__,_|_| |_| \___/_\_\ \_, |
                                                      |__/
REST HaProxy Started
PID: 15803

real    0m0.003s
user    0m0.002s
sys     0m0.001s 
```

... and is exceptionally stable. The entire thing installs in less than 30 lines of configuration managment code:

```bash
for i in `find . -name \*.pp`;do cat $i | sed '/^\s*#/d;/^\s*$/d' | wc -l;done
      29
```

For these reasons I am sold on Golang, and decided to re-write the entire [VersionCtl](https://github.com/malnick/go_vctl) app using it - that's fodder for my next post.
