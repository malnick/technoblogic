---
layout: post
title: "Puppet Run Vis"
date: 2014-01-06 15:39:29 -0700
comments: true
categories:['yaml','visualization','javascript','node'] 
---
###D3 Visualization for a Puppet Run

One of the common complaints with puppet, especially puppet enterprise (PE) is that it does not scale in the way that one would hope. In example, the PE console. EVERY NODE must report to the console in PE. So, if, for example, you're a sysadmin working with 10,000+ or even 1,000+ PE nodes you're going to have a crazy busy console. 

One way to make this problem more managable is to find savvy ways to visualize the data. Here I propose one such way to manage this using D3 as the visualization tool and js-yaml, a node.js lib to parse a PE run YAML file for the D3 dataset.

The main issue here is in developing such a debugging tool I would hope to alliviate and not add to the already cumbersome way console manages 1000's of nodes. The tool should scale to 'n' number of nodes, no matter what changes on the backend with postgres or the number of consoles - if there are 10 or 10,000,000 nodes I want this tool to be able to help the user troubleshoot errors on three axes:

	* Time - the time the error occured in the context of the run
	* Error type - red for failure, orange for warning, green for successful
	* Resource Invovled - the resource that either failued, generated warning or was successful. 

So in my mind, I have this layout which actually involved a couple layers:

    * View 1 - Circular graph; inner circle represents precentage of nodes with failures in red; mid circle is percentage of nodes with warnings in orange; outer circle is percentage of nodes with no errors in green.
    * View 2 - Click on red area of graph; transition to new circular graph of same circumfrance; starting at 12 o'clock and moving clockwise around the graph is time, each 360 rotation starts a new level; each level is denoted by the number of failures; each failure's area or degrees of circumfrance is the precentage of nodes with that error. 
        * In eaxmple: if you have a 5 errors over 50 nodes, each with 10 instances of those 5 errors the area of the graph that the error takes up would be equally distributed through out the circle starting at time -0 at 12 o'clock moving clockwise around the circle (ok maybe a tarus now) until a equal number of levels has been reached once the center of the circle or tarus has been reached.
    * View 3 - same as 2 but for warnings (orange).
    * View 4 - same as 2 but for successes or no error (green).

Something similar to this: http://xliberation.com/parse/colortable/parsed3.html

So the initial view is very simple, it is just a ratio of nodes in three categories of "has failures (center, red)", "has warnings (mid circle, orange)" and "has no errors (outter circle, green)". 

So, how do we deal with nodes with errors, warnings and successes? We lop them into the lowest common denomenator: if it has successes and warnings it goes to the warning loop; if it has successes warnings and errors it goes to error loop; if it has successes and errors it goes to error. 

Our lowest common denomenator is the fact that we are only concerned with nodes that have errors or warnings, if it's successful that's great, we want to see it but errors are the what we are debugging. 

###'n' scalability

Yeah, it's what needs to happen. 

Humans are really bad at abstracting long lists. I mean, "node so-and-so had error this-and-that" for 10,000,000 lines isn't so helpful. Sure, "--trace" or "--debug" is helpful, but ITSALOTOFLINESOFCODE" so wtf do we do? 

We have to make it human friendly. Humans can abstract information on way more levels than "line 1, 2,3....'n'". We have 5 complete senses (for most of us!) so we should leverage a few more than textual abstractions of code. Color, shapes, area graphs; abstracting the run levels of a puppet run into "zooms". These are all available to us. 

###D3

D3 is a javascript lib that talks directly to the DOM to quickly and efficiently create interactive scalable vector graphics. WTF does that mean? It means it can run in the PE console with little overhead, take it's datasets from the parsed YAML in PuppetDB via some savvy js-yaml action and run in basically any browser.

All you need to know is it's super rad.. and more importantly, proven. 

###HOW DO WE PARSE THE YAML

js-yaml, maybe. Or some other YAML to JSON converter that we can get arrays of data out of the YAML from for our JS D3 vis. That isn't so difficult. 


