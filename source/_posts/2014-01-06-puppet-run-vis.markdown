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
	* Error type - red for failure, orange for warning, green for successful 	* Resource Invovled - the resource that either failued, generated warning or was successful. 

So in my mind, I have this layout which actually involved a couple layers:

    * View 1 - Circular graph; inner circle represents precentage of nodes with failures in red; mid circle is percentage of nodes with warnings in orange; outer circle is percentage of nodes with no errors in green.
    * View 2 - Click on red area of graph; transition to new circular graph of same circumfrance; starting at 12 o'clock and moving clockwise around the graph is time, each 360 rotation starts a new level; each level is denoted by the number of failures; each failure's area or degrees of circumfrance is the precentage of nodes with that error. 
        * In eaxmple: if you have a 5 errors over 50 nodes, each with 10 instances of those 5 errors the area of the graph that the error takes up would be equally distributed through out the circle starting at time -0 at 12 o'clock moving clockwise around the circle (ok maybe a tarus now) until a equal number of levels has been reached once the center of the circle or tarus has been reached.
    * View 3 - same as 2 but for warnings (orange).
    * View 4 - same as 2 but for successes or no error (green).

