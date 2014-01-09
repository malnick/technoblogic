---
layout: post
title: "Puppet Run Vis"
date: 2014-01-06 15:39:29 -0700
comments: true
categories:['yaml','visualization','javascript','node'] 
---
###D3 Visualization for a Puppet Run

One of the common complaints with puppet, especially puppet enterprise (PE) is that it does not scale as one would hope. In example, the PE console. EVERY NODE must report to the console in PE. So, if, for example, you're a sysadmin working with 10,000+ or even 1,000+ PE nodes you're going to have a crazy busy console. 

To make this problem more managable a visualization is necessary - until humans start developing USB ports for their brains. Here I propose one such way to manage this using D3 as the visualization tool and the post-run YAML log from PuppetDB.

The main issue here is in developing such a debugging tool I would hope to alliviate and not add to the already cumbersome way console manages 1000's of nodes. The tool should scale to 'n' number of nodes - if there are 10 or 10,000,000 nodes I want this tool to be able to help the user troubleshoot errors on three axes:

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

The initial view is simple, it is a ratio of nodes in three categories of "has failures (center, red)", "has warnings (mid circle, orange)" and "has no errors (outter circle, green)". 

How do we deal with nodes with errors, warnings and successes? We lop them into the lowest common denomenator: if it has successes and warnings it goes to the warning loop; if it has successes warnings and errors it goes to error loop; if it has successes and errors it goes to error. 

Our lowest common denomenator is the fact that we are only concerned with nodes that have errors or warnings, if it's successful that's great, we want to see it but errors are the what we are debugging. 

###'n' scalability

It needs to happen. 

Humans are bad at abstracting long lists. I mean, "node so-and-so had error this-and-that" for 10,000,000 lines isn't so helpful. Sure, "--trace" or "--debug" is helpful, but ITSALOTOFLINESOFCODE".

Humans can abstract information on more levels than "line 1, 2,3....'n'". We have 5 complete senses (for most of us!) so we should leverage a few more than textual abstractions of code. Color, shapes, area graphs; abstracting the run levels of a puppet run into "zooms". These are all available to us. 

###D3

D3 is a javascript lib that talks directly to the DOM to quickly and efficiently create interactive scalable vector graphics. 

What?

It means it can run in the PE console with little overhead, take it's datasets from the parsed YAML in PuppetDB via some savvy js-yaml action and run in basically any browser.

All you need to know is it's super rad.. and more importantly, proven. 

###HOW DO WE PARSE THE YAML

js-yaml, maybe. Or some other YAML to JSON converter that we can get arrays of data out of the YAML from for our JS D3 vis. That isn't so difficult. 

Our PuppetDB YAML looks a little like this (for an example, I'm using the first couple lines):

{% codeblock lang:yaml last_puppet_run.yaml%}
--- !ruby/object:Puppet::Transaction::Report
metrics: 
resources: !ruby/object:Puppet::Util::Metric
name: resources
label: Resources
values: 
- - total
- Total
- 85
- - skipped
- Skipped
- 0
- - failed
- Failed
- 1
- - failed_to_restart
- "Failed to restart"
- 0
- - restarted
- Restarted
- 0
- - changed
- Changed
- 0
- - out_of_sync
- "Out of sync"
- 1
- - scheduled
- Scheduled
- 0
{% endcodeblock %}

A converstion of this file to JSON would output something like:

{% codeblock lang:json last_puppet_run.json %}
{
  "metrics": null,
  "resources": "!ruby/object:Puppet::Util::Metric",
  "name": "!ruby/sym executed_command",
  "label": "Events",
  "values": [
    "- total",
    "Total",
    1,
    "- failure",
    "Failure",
    1,
    "- success",
    "Success",
    0
  ],
}
{% endcodeblock %}

This was encoded to JSON via: https://npmjs.org/package/yamljs

	yaml2json last_run_report.yaml --pretty

###First steps to building the vis

Start with an NGINX server running on localhost:8888 serving up the /www directory from my github.com/puppetlabs/banyan. 

Then I start with figuring out how the heck D3 works. Well, luckily for me it's pretty simple. You start by defining some CSS elements for the vis. In my case, I wanted to simply see how I would grab data from the YAML, parsed to JSON and push it into D3. 

Let's start small:

{% codeblock lang:html index.html %}
<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="utf-8">
        <title>D3 Test Visualization for PE Run</title>
    </head>
	<meta charset="utf-8">
	<style>
	.chart div {
	font: 10px sans-serif;
	background-color: steelblue;
	text-align: right;
	padding: 3px;
	margin: 1px;
	color: white;
	}
	</style>
{% endcodeblock %}

This initializes a bar chart and the colors, alignment and all the other CSS crap that will be used over and over again in the SVG. I'll use .chart as a CSS div element below. 

Then we need to tell the DOM that we're going to be using D3.js in our HTML script tags:

{% codeblock lang:html index.html %}
<script src="http://d3js.org/d3.v3.min.js"></script>
{% endcodeblock %}

Ok, phew, that was rough right? Right. Because I'm an ops guy and this dev shit is for the...

Anyways back to the meat of the index.html, our D3 script. 

Let's declare the script tags and initialize some vars that we'll use in the test code:

{% codeblock lang:html index.html %}
 <body>
        <script type="text/javascript">
        var data;
        var eval_time;
        var draw_this = new Array();
{% endcodeblock %}

Now lets parse that JSON I created from before via the YAML puppet_run_report. D3 is SO RAD that it ships with a nice JSON importer called 'd3.json'. We're going to use it here to grab the 'evaluation_time' metric from the parsed YAML (now a JSON) and push it into an array that we will eventually use to draw a bar representing this metric. 

{% codeblock lang:html index.html %}
d3.json("last_run_report.json", function(error,json){
        	data = json;
        	eval_time = data.evaluation_time;
        	draw_this.push(eval_time);
{% endcodeblock %}

Yep, that easy. Pretty rad right? Right. 

Now the fun part, let's draw some scalable vector graphics (from here on out referred to by their much less type consuming name 'svg'):

{% codeblock lang:html index.html %}
			var x = d3.scale.linear()
				.domain([0, d3.max(draw_this)])
				.range([0, 420]);

			d3.select(".chart")
				.selectAll("div")
				.data(draw_this)
				.enter().append("div")
				.style("width", function(d) { return x(d) + "px"; })
				.text("Evaluation Time");
				//.text(function(d) { return d; });
		});			
        </script>
{% endcodeblock %}

I start by telling D3 to scale the graph along the 'x' axis because eventually I'll have other bars and I don't want this thing getting out of control, since I am a control freak. 

Then we use the ever-so-awesome d3.select. The .select method is great, you could basically script an entire index.html with .select. What's actually happening here is .select is D3's way of saying, "Hey DOM, here's a CSS selector, give me the first element match". 

You can do .select("body"), .select("marquee") (if you're hella adventurous) or if you want to have access to all the DOM elements .selectAll(). 

I selected my div.chart that I defined earlier, as this is the CSS style I want to push onto my silly bar graph. So all data elements iterated over in .data() will use this style. Notice how .style is automagically added to the DOM for .select() to use down here? That's super cool. 

Then we pass my earlier defined array draw_this to .data(). .data is a holder for our soon to be iterated stuff. The magic happens when we use .enter, and wrap our div append in it. 

Anytime you bind data to an element (in this case we're binding the array draw_this) you need to use .enter(). We don't actually have any DOM elements for div yet, but we need a placeholder for our data (or whatever data-element binding you might have). .enter() makes this placeholder - it says, "hey I have this data, does the DOM have this data?". If the DOM is like, "hell no I have no such data." Then .enter() creates a placeholder for that data. 

Don't conflate data with DOM elements. In this example we're passing 1 data value (there only exists one data value in draw_this for now). .enter() will make sure we have placeholder <div> elements to put our data into since they do not exist. So .enter() in this example is making one <div> element PLACEHOLDER (all problems in computer science can be solved by enough levels of abstraction!). 

It passes a REFERENCE of this placeholder to the next thing in the chain, in this case an append of <div> which actually inserts our elements into the DOM. We then apply our CSS style to a bar that we defined earlier and does some scaling math so when we have more bars later it won't get out of control and bang, we have a DIV representing our data. 

So far our index.html looks like this: 
{% codeblock lang:html index.html %}
<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="utf-8">
        <title>D3 Test Visualization for PE Run</title>
    </head>
	<meta charset="utf-8">
	<style>
	.chart div {
	font: 10px sans-serif;
	background-color: steelblue;
	text-align: right;
	padding: 3px;
	margin: 1px;
	color: white;
	}
	</style>
	<div class="chart"></div>
	
	<script src="http://d3js.org/d3.v3.min.js"></script>
    <body>
        <script type="text/javascript">
		
        var data;
        var eval_time;
        var draw_this = new Array();
        
        d3.json("last_run_report.json", function(error,json){
        	data = json;
        	eval_time = data.evaluation_time;
        	//alert(eval_time);
        	draw_this.push(eval_time);
        	
        	//draw something
			var x = d3.scale.linear()
				.domain([0, d3.max(draw_this)])
				.range([0, 420]);

			d3.select(".chart")
				.selectAll("div")
				.data(draw_this)
				.enter().append("div")
				.style("width", function(d) { return x(d) + "px"; })
				.text(function(d) { return d; });
		});			
        </script>
    </body>
</html>     
{% endcodeblock %}

OMG IT'S SO AWESOME!
{% img /images/small_example.tiff 'awesome' 'images' %}




