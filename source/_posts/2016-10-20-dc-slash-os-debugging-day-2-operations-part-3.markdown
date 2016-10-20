---
layout: post
title: "DC/OS Debugging (Day 2 Operations, Part 3)"
date: 2016-10-20 13:29:22 -0700
comments: true
categories: 
---
## DC/OS Debugging API
Things fail in production, many times it takes more than the logs to understand what’s going wrong. Instead of requiring end users to SSH arbitrarily across the cluster and have root access, we have built a single tool that can access any running container from a developer’s laptop without having to figure out where it is running.

What this interaction looks like to our end-users:

```
dcos task exec <$TASK_ID> <$EXEC_COMMAND> [-[-i]nteractive] [-[-t]ty]
```

The `exec` subcommand for our `task` utility finds  the host which is running  `<$TASK_ID>` in your cluster. It forks a process within the namespace of that container on that host, returning `STDOUT` an `STDERR` to your command line interface. Optionally, you can attach and stream `STDIN` but using the `--interactive` flag or a `TTY` by using the `--tty` flag. This mimics in many ways `docker exec` functionality.

The `exec` command does much more than spawn a forked process within your container namespace. Unlike `docker exec`,`dcos task exec` works over your DC/OS network,  finding the host running the container, and securely processes the `exec` request through our internal, encrypted authN / authZ subsystem. This API functions over HTTP/S. in comparison to running this as a SSH tunnel over your network, the debug API obeys fine-grained access control lists (ACLs) for the user and requires no other special software other than the latest `dcos` CLI (to be released in DC/OS 1.10 this Winter). 

Nobody ants to debug containers in production, but when you have to, you can now easily do so with the `dcos task exec` command. In the future we'd like to also add the ability to mount a container image, a debug container if you will, to the container which you're debugging. With this functionality you can ensure your debugging tools of choice are present for ease of use. 

The `task exec` functionality is jus the first of many debug tools we aim to ship in DC/OS over the coming year. If you have any suggestions, please reach out to us ... <Judith community contact info>
