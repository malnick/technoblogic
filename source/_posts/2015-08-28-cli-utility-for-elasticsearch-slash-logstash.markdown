---
layout: post
title: "logasurous: A CLI Utility for Elasticsearch / Logstash"
date: 2015-08-28 12:19:11 -0700
comments: true
categories: 
---
<img style="float: center;" src="https://dl.dropboxusercontent.com/u/77193293/logasaurous.png">

Like most operations teams, at SRC:CLR we're offloading our logs to a aggregated log solution. We use the popular ELK (Elasticsearch, logstash, kibana). I love this solution, but when it comes to simply copying and pasting log data from Kibana, things get messy. When our developers need to get data quickly, it would be easier to have a CLI utility that can do the same queries than having to open a browser and screen grab from Kibana. 

## So we wrote [logasurous](https://github.com/sourceclear/logasaurous)
logasurous runs in realtime, just like Kibana, on similar searches. This is great if your workflow is primarily in the console, and you're using Kibana mainly for query operations. You can use your tmux copy/paste shortcuts to grab data quickly. Queries are just as fast. 

logasurous was written in Go, so you know it's performant and lightweight. 

## How it works
First, download and build the go binary:

```bash
git clone https://github.com/sourceclear/logasurous
cd logasurous
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

```yaml
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

```
./loga -d "some_value AND another_value"
```

#### Something is broken

```
./loga -d my_query -v
```

#### Override the sync and depth interval

Sync interval = time in seconds to refresh the logs. Default: 5 seconds.
Sync depth = time in minutes to go back in the ES datastore. Default: 10 minutes.

```
./loga -d my_query -si 10 -sd 1
```

^^ Queries logs from the last 1 minute, refreshing every 10 seconds.

### Closing Thoughts
The great thing about this system is the outputs are "${hostname} ${message}" which is the main thing we end up sorting by.

Sometimes we just run a search on "*" when new services come up, and we keep an eye out for errors.

With loga, we can execute this on the CLI:

```
loga -d "*"
```
 
Then when we get a stack trace, we can see the host(s) that the stack trace occured and update our query:

```
loga -d "\"host-name-internal\""
```

We can also search back to the stacktrace if it occured more than 10 minutes ago:

```
loga -sd 20 -d "\"host-name-internal\""
```

That will dump the last 20 minutes of log data, or 500 queries in asending order. 

We love Kibana, but sometimes it's just faster to have a CLI utility to do the mundane things. We really like this tool, and we hope you will to. If you have any suggestions, please reach out malnick at google mail dot com.



