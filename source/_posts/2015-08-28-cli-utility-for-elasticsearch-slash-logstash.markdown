---
layout: post
title: "Logit: A CLI Utility for Elasticsearch / Logstash"
date: 2015-08-28 12:19:11 -0700
comments: true
categories: 
---
<img style="float: center;" src="https://dl.dropboxusercontent.com/u/77193293/masked_logitexample.png">

Like most operations teams, at SRC:CLR we're offloading our logs to a aggregated log solution. We use the popular ELK (Elasticsearch, logstash, kibana). I love this solution, but when it comes to simply copying and pasting log data from Kibana, things get messy. When our developers need to get data quickly, it would be easier to have a CLI utility that can do the same queries than having to open a browser and screen grab from Kibana. 

## So we wrote [Logit](https://github.com/malnick/logit)
Logit runs in realtime, just like Kibana, on similar searches. This is great if your workflow is primarily in the console, and you're using Kibana mainly for query operations. You can use your tmux copy/paste shortcuts to grab data quickly. Queries are just as fast. 

Logit was written in Go, so you know it's performant and lightweight. 

## How it works
First, download and build the go binary:

1. ```git clone https://github.com/malnick/logit```
1. ```cd logit```
1. ```go build logit.go```

Configure the config.yaml:

1. ```vi config.yaml```

Update your Elasticsearch URI, and add some service abstractions to the 'define' section. 

Execute your first query:

1. ```./logit -s my_example_service```

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
./logit -s webhooks_frontend
```

#### Do a defined query on the CLI

```
./logit -d "some_value AND another_value"
```

#### Something is broken

```
./logit -d my_query -v
```

#### Override the sync and depth interval

Sync interval = time in seconds to refresh the logs. Default: 5 seconds.
Sync depth = time in minutes to go back in the ES datastore. Default: 10 minutes.

```
./logit -d my_query -si 10 -sd 1
```

^^ Queries logs from the last 1 minute, refreshing every 10 seconds.

## Screen Grabs!
Here is a masked screen grab of a logit query, only showing the first of the 500 lines that would be returned: 

<img style="float: center;" src="https://dl.dropboxusercontent.com/u/77193293/masked_logitexample.png">
