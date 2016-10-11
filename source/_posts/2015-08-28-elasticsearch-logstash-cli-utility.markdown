---
layout: post
title: "Logasaurus: A CLI Utility for Elasticsearch / Logstash"
date: 2015-08-28 12:19:11 -0700
comments: true
categories: DevOps
author: Jeff Malnick
---
<img style="float: center;" src="https://dl.dropboxusercontent.com/u/77193293/logasaurus.png">

Like most operations teams, at SRC:CLR we're offloading our logs to an aggregated log solution. We use the popular ELK (Elasticsearch, Logstash, Kibana). I love this solution but when it comes to simply copying and pasting log data from Kibana things get messy. When our developers need to get data quickly it would be easier to have a CLI utility that can do the same queries than having to open a browser and screen grab from Kibana.

<!-- more -->

[Logasaurus](https://github.com/malnick/logasaurus) runs in realtime just like Kibana on similar searches. This is great if your workflow is primarily in the console and you're using Kibana mainly for query operations. You can use your tmux copy/paste shortcuts to grab data quickly. Queries are just as fast.

Logasuarous was written in Go, so it's performant and lightweight.

## How it works
First, download and build the go binary:

```
git clone https://github.com/malnick/logasaurus
cd logasaurus
go build loga.go
```

Configure the config.yaml:

```
vi config.yaml
```

Update your Elasticsearch URI, and add some service abstractions to the 'define' section.

Execute your first query:

```
./loga -s my_example_service
```

#### Add some queries to config.yaml
You can store long, hard to type queries in the config.yaml for use later:

```
---
  # Defined services
  define:
    my_example_service: some_value AND another_value
    webhooks_frontend: webhooks AND haproxy
...
```

```
./loga -s webhooks_frontend
```

#### Do a defined query on the CLI
If you need to run a lookup quickly you can do a defined query directly on the CLI:

```
user@shell: ./loga -d "qa"

INFO[0000] Loglevel: Info
INFO[0000] qa
INFO[0000] Querying : qa
2015-09-06 16:03:58.112  INFO 7 --- [nio-8080-exec-3] c.s.websocket.scm.ScmWebSocketHandler    : Received heartbeat message from agent REDACTED at /192.168.1.72:53812
...
```

#### Want to know what host the log message is coming from?
You can use `-h` to highlight the hostname/ip address at the beginning of the line:

```
user@shell: loga -d "qa" -h

INFO[0000] Loglevel: Info
INFO[0000] qa
INFO[0000] Querying : qa
192.168.1.68 2015-09-06 16:01:08.108  INFO 7 --- [io-8080-exec-10] c.s.websocket.scm.ScmWebSocketHandler    : Received heartbeat message from agent REDACTED at /192.168.1.45:53812
```

#### Change sync window
By default Loga will querey time.Now() minus 10 minutes, and return those logs up to 500 queries. You can change start time with `-st`, and start time.Now() minutes back. 

To query logs 24 hours ago in a 10 minute window you could run:

```
user@shell: TZ=utc date
Sun Sep  6 16:31:23 UTC 2015
user@shell: loga -d "qa" -st 1440

WARN[0000] Using Start Time: 2015-09-05 09:31:24.961285247 -0700 PDT
INFO[0000] qa
INFO[0000] Querying : qa

2015-09-05 16:21:25.009  INFO 7 --- [nio-8080-exec-3] c.s.websocket.scm.ScmWebSocketHandler    : Received heartbeat message from agent REDACTED at /192.168.1.42:54931
...
```

#### Override the sync and depth interval

Sync interval = time in seconds to refresh the logs. Default: 5 seconds.
Sync depth = time in minutes to go back in the ES datastore. Default: 10 minutes.

```
./loga -d my_query -si 10 -sd 1
```

^^ Queries logs from the last 1 minute, refreshing every 10 seconds.

#### Something is broken

```
./loga -d my_query -v
```

### Closing Thoughts
We love Kibana but sometimes it's just faster to have a CLI utility to do the mundane things. We really like this tool and we hope you will to. If you have any suggestions please reach out jeff at srcclr dot com.

Visit [Logasaurus](https://github.com/malnick/logasaurus) on github.com for complete details.
