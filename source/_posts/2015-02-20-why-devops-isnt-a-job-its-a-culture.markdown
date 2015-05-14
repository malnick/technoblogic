---
layout: post
title: "Why DevOps Isn't a Job, It's a Culture"
date: 2015-02-20 07:22:08 -0800
comments: true
categories: 
---
DevOps is not a job, it's a culture. DevOps is a shift in how you decide to manage, deploy, develop, monitor, and interact with your application code and your infrastructure as a whole. DevOps is a holistic approach to enacting the now bankrupt term "agile" as a method of development and operations engineering in an organization.

At SRC:CLR we have a culture of DevOps that puts me face-to-face with developers everyday. At many companies the 'DevOps' team never sees another dev. In fact, they may not see another operations person either. Usually, when you hear the term 'DevOps team', that means it's just another siloed group of people in a company, usually focused on automating infrastructure.

At SRC:CLR we roll DevOps in the way it was meant to be rolled: me, 'Mr. DevOps', sits shoulder to shoulder with our devs. No partitions, no separate team. When we get a Dir. of Engineering I'll be reporting to him, the same as our devs. Our operations are tightly coupled with the development of our code. That coupling ensures everyone is on a flat playing field, pushing towards the same goal.

How does this affect operations and development at SRC:CLR? It's the feedback loop stupid - it's continuous integration of ideas and knowledge of our application and our infrastructure. It creates synergy between how we architect our applications and how we automate and deploy our infrastructure.

True story: last week we had a hard time diagnosing why one of our main services was crashing. At first we thought it was Tomcat not having enough heap space. That helped but didn't fix it from continuing to silently crash. We enabled more robust logging but ended up with massive amounts of java spring output that we started grepping through.

Not useful.

I started looking at the process and realized our current monitoring system wasn't robust. We were using a mixture of New Relic for application and systems monitoring with CloudWatch from AWS. New Relic didn't have any logging data and what we wanted to find was correlation between the generated logs at failure and the process crashing. We didn't have a robust tool to look at the log data.

I started looking at hosted solutions: SumoLogic, Librato + Logstash, loggly. In the end our developers and I agreed that even though Librato has AMAZING graphing capabilities that offloading our logs to a hosted solution was insecure at best. We needed to stand up a solution in our private VPC.

After that lunch meeting I went back to the drawing board and started piecing together some Puppet code around Elasticsearch, Logstash and Kibana that I had started the previous week. In an hour I had an ELK + Redis stack up and running that was pulling down unfiltered log data from the node running the service which was crashing.

If you've never graphed logging data you're not doing it right.

One of the lead devs on our platform started looking at the graphing output. A lot of it was health checks from HaProxy. Not a problem, I can filter that out on the node using 'drop{}' in logstash. Next up was creating a lot of data on the node. We ran some queries against the service and started looking at the data that was coming in.

Having an interactive face to our logging data in the Kibana dashboard is invaluable. We can find correlations between crashes (on timestamps) and generated logging output. We can use that data to create alerts that go off before the process crashes.  

At the end of the day I'm an automation guru. The infrastructure that I automate is tightly coupled with our code. Since I have the skills to bring to life the data that the developers generate (in this case logging data) I can help alleviate stress on our infrastructure, create a more performate and stable platform and enable deep insights to how code responds in a fully integrated environment.

This transparency between the code development process and how deployed code behaves is core to DevOps culture. My job is about creating feedback loops for our development team so when things break in a deployed environment we can intelligently respond and iterate faster and smarter. 

I can do this in a fully secure VPC or I can develop other methodologies in less secure hosted solutions. Either way, at the end of my day it's my job to ensure we have ```uptime```. By far the best way to achieve that is to embed me in the middle of the development process, enabling fast iteration and seamless feedback between the development and operations ends of the deployment process.

That's why DevOps isn't a job, it's a process in which everyone in engineering participates. DevOps might be in my title as an employee but what it truly represents is SRC:CLR's commitment to blurring the lines between development and operations, enhancing feedback loops in both directions. This ensures more security, higher performance and better ``uptime```.

