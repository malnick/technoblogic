---
layout: post
title: "Using Golang for More Performant DevOps Tasks"
date: 2015-07-31 06:05:55 -0700
comments: true
categories: 
---
# Part 1 if 2
This is a two part post on leveraging golang for more performant DevOps tasks. In this post, I'll go over the benefits of GoLang and dive into the re-writing of an application we use to track versions of all our running services, focusing on building a REST interface to available services in haproxy.cfg. In the second post I'll move into re-writing the tool that leverages that REST interface to give us visibility into the versions of running services in our infrastructure - a very important tool in a microservices architecture.

## The Why
A major component of the DevOps workflow is building more visibility into the daily operations of a deployment. In my career I've typically build my tools in Ruby. Sinatra webhooks were a mainstay of almost all my applications. It's simple to read, easy to implement language that is as useful on the command line as it is building full fledged web applications. 

What Ruby is not, however, is lightweight and fast. Often times, it's also easy to get bitten by developing on OSx and deploying into a linux environment is not of the same Ruby version you built on. Ruby is also an interpreted language (queue comments about how it's not *just* an interpreted language).

## GoLang
Go is a compiled language. And when I say it's compiled, I mean the GC compiler (well there are a few compilers, but GC is the main one), I mean it compiles directly to assembly. No need to have an exact Go version match on a given machine for deployment. Also, packages tend to be **far** smaller than interpreted versions. 

Go is strict about importing libraries. If the library is imported and unused, it'll blow up. Initially this felt like a burden (but I want ***all*** the libraries!! What if...), but in the end it makes up for some very efficient compile times and less bloat.

## An Example
I wrote a program not to long ago called [VersionCtl](https://github.com/malnick/versionctl). VersionCtl queried the CSV endpoint on our internal HaProxies, which had only services currently running which were provisioned by Puppet. The server name attribute was ```$::role-$dashed_ip_address```. By parsing the IP address in the server name I could build up a list of currently available services, and query them for the running version on the available (internally) management port. 

I then compared the versions currently running to those that were defined in a hiera data file called versions.yaml. Versions.yaml is managed by a webhook on our Puppet Master that receives a POST from Jenkins every time a new service is build (per environment). The webhook writes the new version of a service to this file, and implements MCO to kick off a run on all boxes matching a ```$::role``` fact. 

Sometimes, CI would break: we would deploy a service and the running version was not the version we just deployed. VersionCtl compares the versions in hiera to the currently running versions (the versions.yaml is exposed via another REST endpoint on the Puppet Master). If the versions don't match, the server line goes red; if they match, everything is green.

What this looked like when everything was OK:

<<<Image>>>

And when things broke:

<<<Image>>>

## But, Problems...
To say the least, I wasn't happy with this program. It was slow to query all the endpoints, and the code felt bloated at best. Several optimizations could be made, least of which was writing it in something more lightweight. 

First, I redesigned in my head, how it should work. First off, the parsing of Haproxy's CSV endpoint was not performant or durable. If the `server name` attribute changed, it would not work. Also, Haproxy should have some kind of endpoint on it that VersionCtl could query to get available services - services listed on the server line in the haproxy.cfg file. This way I could also get the management port info that the current version of versionctl required to reach the /info endpoint. 

This also meant I would have info regarding individual processes. Before, if we had many instances of the same service running on a box,  we'd end up guessing what port each was running on since that isn't available in the CSV endpoint. The CSV endpoint should only be used to determine if a given `server name` is available, and that's it. All other service info needs to come out of the config file.

The second part is that this is a simple REST proxy for our /info endpoints - it should be fast as ... fast. I wanted to make the service lightweight in the sense that haproxy's admin console is lightweight. Very simple HTML updated by a fast backend. Done and Done.

## A REST Interface for HaProxy
First, we needed to build this rest interface for haproxy, I decided to use GoLang for this as I could easily build a binary for AMD64 and ship it to our linux distro via Puppet and an internal datastore. 
The project is available [here](https://github.com/malnick/rest_haproxy), but let's take a closer look:

```go
package main

import (
  "bufio"
  "encoding/json"
  "log"
  "net/http"
  "os"
  "regexp"
  "strings"
)

type Available struct {
  Name     string
  Ip       string
  Port     string
  MgmtPort string
}

type Services struct {
  Servers []Available
}
```

We start with some basic data structures: one that ships our available services into JSON, and another that will drop into a slice that defines each service.

Our main() is straightforward:

```go
func main() {
  http.HandleFunc("/services", response)
  http.ListenAndServe(":3000", nil)
}
```

The ```HandleFunc``` takes our response function, which kicks off the rest of the process:

```go
func response(rw http.ResponseWriter, request *http.Request) {
  services, err := parsefile("/etc/haproxy/haproxy.cfg")
  if err != nil {
    log.Println("ERROR: ", err)
  }
  json, err := json.Marshal(services)
  rw.Write([]byte(json))
}
```

Now things get interesting, the parsefile() takes the path to the haproxy.cfg, and loads it into the services struct:

```go
func parsefile(filename string) (*Services, error) {
  // Temp array
  var temp_avail []Available
  var a Available
```

We define a temporary array with type ```Available```, and an instance of ```Available``` as ```a```.

```go
  // Define our regex to parse
  regex, err := regexp.Compile(`^\s*server`)
  if err != nil {
    return nil, err // there was a problem with the regular expression.
  }
```

Then we define a rexex to match against. It matches any white space that eventually a ```server``` line directive.

```go
  inFile, _ := os.Open(filename)
  defer inFile.Close()
  scanner := bufio.NewScanner(inFile)
  scanner.Split(bufio.ScanLines)
```

Then we open the haproxy config, and build a new Scanner using bufio. 

```go
  for scanner.Scan() {
    line := scanner.Text()
    if regex.MatchString(line) {
      log.Println("MATCHED:\n", line)
      larry := strings.Fields(line)
      log.Println("LENGTH: ", len(larry))
      log.Println("NAME: ", larry[1])
      a.Name = larry[1]
      dest := strings.Split(larry[2], ":")
      a.Ip, a.Port = dest[0], dest[1]
      log.Println("IP: ", dest[0])
      log.Println("PORT: ", dest[1])
      if len(larry) == 6 {
        a.MgmtPort = larry[5]
      } else {
        a.MgmtPort = a.Port
      }
      log.Println("MGMT PORT: ", a.MgmtPort)

      temp_avail = append(temp_avail, a)
    }
  }

  return &Services{
      Servers: temp_avail,
    },
    nil
}
```

The last thing we do is scan each line in the file, match the server lines we want, and split those into slices on white space. We parse out the parts we want, and load those into our instance of ```Available``` as ```a```. 

I originally did this with a ```strings.Split``` but realized the white space at the beginning of the line would also be a slice element. I had to remove that white space. In the end, I went with ```strings.Fields``` since it only grabs non-blank strings, allowing me to have a known slice length.

We then append our instance of ```a``` to our ```temp_avail``` slice. Once we reach the end of the file, we pass ```temp_avail``` to our ```Servers``` key and return the pointer to ```Services````. 

The ability to have pointers in golang is one performance increase over creating new object variables (instance or class) in Ruby - you have far more control over memory allocation and variable bloat. 

Upon return, golang dereferences the &Services to a meaningful variable ```services``` in the response().

Once compete, response() marshels ```services``` to JSON and writes it out as a type ```[]byte``` (expected by http.ResponseWriter). 


