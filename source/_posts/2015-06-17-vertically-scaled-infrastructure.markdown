---
layout: post
title: "Vertically Scaled Infrastructure"
date: 2015-06-17 12:48:27 -0700
comments: true
categories: 
---
## "...but does is scale?" 

When it comes to micro-service architectures that's always the big question. You can maintain a solid agile development process, design a micro service architecture, and implement seamless CI to ensure developers can launch code from their local test environment into Prod but if you can't respond to the increase in demand for your product then who cares? Unusable products, no matter how cool, won't get traffic and your company will suffer. 

## Vertical Scaling
Scaling starts vertically - or locally - before moving to multiple machines. 

It's important to understand how scaling a micro-service works in order to buy into this logic. First, a micro-service architecture is comprised of lots of atomic, REST endpoints, that should be able to generate some meaningful data on their own, with out the help of other services in the ecosystem. As long as service 'x' can talk to your queue and perhaps a datastore of some kind, it should be considered healthy.

### The Essence of a "Service"
Starting and stopping service 'x' can be viewed as a [unary](https://en.wikipedia.org/wiki/Unary_operation) operation which is [idempotent](https://en.wikipedia.org/wiki/Idempotence) across restarts and environment configruation. I tell service 'x' to start on port :4321 with ```datasource.host=my.postgres.com``` then no matter where I start the service, as long as those two external services are available, service 'x' should be healthy.  

Simple right? 

### ...do it again...
Now we want to start multiple processes of service 'x' on the same machine. We want to do this in order to fully realize the computing potential of our EC2 instance, Digital Ocean droplet, Heroku dyno (insert name of virtual computing resource here) in order to incrase availability, performance and return on investment of our infrastructure.

Several key factors need to change in order to realize multiples of the same service on a single machine:

1. Environment or External Configuration of the Application
1. Port assignments at the application layer 
1. Port assignments at the load balancer to proxy requests

We use HaProxy as an internal loadbalancer to proxy requests to our backend micro services. However, you could accomplish the same task with any kind of proxy, whether it's [written in Go](https://github.com/GoogleCloudPlatform/kubernetes/blob/master/pkg/proxy/loadbalancer.go) or built on iptables, proxying requests from a single endpoint to multiple instances of service 'x' enables the most basic type of HA via redundency and increases performance generally. 

In the previous example we told service 'x' to start on :4321 but we can't do that twice on the same box, we'd have a port collision. So we need to run service 'x'(2) on another port, let's say :4322.

Luckily for us, service 'x' can be externally configured via environment variables or using a plain text file called ```app.service_x_1-properties``` and ```app.service_x_2-properties```. In fact, we were already using the app.properties type of external config to set passwords and API tokens service 'x' requires since we didn't want to place those sensitive items, hard coded, in our github repository. So we simply modify the app.properties file for each service with ```service.port``` definitions to ensure they startup on :4321 and :4322 respectivily. 

### Automate it
Now we have to automate this process, ensuring that service 'x' gets provisioned to a node two times with the correct external config. That's easy enough since our tool (puppet, chef, whatever) can take a simple hash of external config for each instance of service 'x' and write that app.properties file on the box. We can use the same hash, or at least the ```service.port``` part, to configure haproxy.cfg on another node, ensuring our service proxy is properly configured. 

Succeess! We have vertically scaled our service!

### Orchestrate it
We could call this success, but does it scale? Let's recap. 

Every time we deploy service 'x' or service 'a', service 'y' or service 'b', we have to manually assign ports in configuration management to be written to a text file on a node running that service. We now have not 1 but 4 services ('x','y','a', and 'b') each requiring a known range of port assignments so we can simultaniously configure the application port in external config and the port assignemnt for the server in haproxy.cfg.

Those assignments might be a table such as:

```sh
service 'a': 1000-1010
service 'b': 1011-1020
service 'x': 1021-1030
service 'z': 1031-1040
```

This is usable, and it "scales" to a maximum of 10 nodes since our known port assignment hash goes 10 deep for each service. 

Now we have 100 million users, and we need to scale our application's backend services 'a', 'b', 'x' and 'y' to ***FAR*** more than 10 instances a piece. In fact, we not only need to scale those to more instances, upper management asked us to add features. These features came by adding sevices 'c', 'd', 'e', 'f' and 'z'. We have to build a port assignment hash for those as well, and it would be great if this distributed micro-service was also highly available beyond just a single node running multiple instances, so we're going to ensure that services 'a' - 'f' and 'x' - 'z' are running a minimum of 50 processes a piece across a minimum of 3 virtual machines.

Now we've got:

```sh
service 'a': 1000-1050
service 'b': 1051-1100
service 'c': 1101-1150
service 'd': 1151-1200
service 'e': 1201-1250
service 'f': 1251-1300
service 'x': 1301-1350
service 'y': 1351-1400
service 'z': 1401-1450
```

Great, we can scale out to 50 instances of each service. Now all I need to do is write all the configuration management code to deploy each one... each one of ***450*** instances across all services. 

I call this "scaling" not scaling. 

### $PORT
This would be so much easier if I could just run these services on $PORT and have our load balancer "just know" what that $PORT assignment was, reconfigure itself dynamically, and automagically proxy requests to all our services, no matter how many instances are running. That's the dream I call scaling. 

### Containers
The cool thing about containers is they're not only self-contained instances of your application, they're self-contained networks. And the most commonly used LXC wrapper, Docker, ships with its own [network proxy](https://docs.docker.com/articles/networking/) to handle port forwarding and routing into and out of a container to the host machine. Docker also allows us to pass in environment variables to the container, environment variables that are as segregated in a similar way to being in separate sub shells. We can leverage both these facets of containers along with new frameworks to orchestrate them (such as Kubernete and Mesosphere). 

Those frameworks can assign ephemeral $PORT assignments for our services, and as long as each service [EXPOSE](https://docs.docker.com/reference/builder/#expose)'s and is configured within the container to run on their given port (each service now only needs a single port mapping since it's executed in it's own network, proxied via $PORT to the host), then those frameworks have their own independant way of loadbalancing requests to the service.

For example, if you run ```docker ps``` and service 'x' is running you might see:

```sh
CONTAINER ID        IMAGE             COMMAND  CREATED             STATUS              PORTS                   NAMES
d7588285b831        service_x:0.5.1   "java"   57 minutes ago      Up 57 minutes       0.0.0.0:1322->1301/tcp  stoic_elion
```

and in ```netstat``` you would see soemthing akin to:

```sh
tcp6       0      0 :::1132      :::*      LISTEN      4743/docker-proxy
```

You don't need a range of port mappings, you need a single mapping. ```docker-proxy``` is proxy'ing the requests from the host on port 1322 to the container where the service is listening on a base port of 1301. 

You don't need to write thousands of lines of configuration management code, you need to build an atomic container and execute it with ```-p 1322:1301```. Orchestration frameworks reduce the configuration further by taking care of the port mapping by bascially running ```-p $PORT:1301```. 

Those same orchestration frameworks then update a named loadbalancer to proxy the request to the correct ephemeral $PORT mapping for your service. Magic.

You don't need to manage CM code for each individual service, you need to have a CI job that builds new containers with each release of your service and track only the version tag you want running in your environment. 

Might I add that scaling is as easy as POST'ing to the Mesos master the number of containers you want running for a given service or POST'ing an updated Replication Controller (RC) in Kubernetes. 

## CAP Therom for Scaling
“This should be simple” is a common platitude outside the hallways of backend engineering. Because vendors and white papers spoon feed the message "we make it simple", everyone wants to think their highly available, distribtued, micro-service architectures should be "simple" and cheap and performant all at the same time. Optimistic and forward thinking executives envision simplicity and effort lying along the same continuum.

In reality, simplicity and engineering effort are inversely related. Simplifying an inherently complex system is essential to scale services within it, but actually requires more effort the simpler the system *seems* to become. This is because system *simplification* is most commonly implemented with abstraction layers. Tools that abstract these systems by cofifying or containerizing small pieces of the system are advertised by venders as "easy to implement" when in practice integrating features, availability, and performance is rarely the easy task the literature or marketing materials would have you believe. 

Don't get me wrong, I'm all for simple, and cost savings. In fact, I work hard every day to make the most of all system resources by leveraging platforms like docker and container orchestration frameworks. We have some amazing frameworks such as Mesosphere and Kubernete and new frameworks are being created every day, further enabling us to simplify incredibly complex systems. They allow us to minimize codified configuration by atomizing each service; taking the complex orchestration piece and turning it into a scalable solution. 

But, like distributed datastores, a back end system generally also obey CAP theorem in terms of cost and complexity; there is always a trade off. Any increase in consistency, availability or partition tolerance increases the cost and complexity of the system, and simplifying it again is tough - somewhere entropy will intrude and suddenly your "simple" dream is suddenly far more complex. However, these dreams can still be a reality as long as you're using tools to orchestrate the chaos. As we move forward in a containerized world, that's going to be my rule of thumb. 


