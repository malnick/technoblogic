---
layout: post
title: "The Benefits of being Sheep"
date: 2014-10-31 06:44:08 -0700
comments: true
categories: 
---
Sometimes we have to check our ego's. This post is a completely opinionated piece on why following community practice is a best practice. Sometimes people refer to this as being "sheep".

Communities exist to support people. In our community, we support each other on IRC, by commenting on tickets we have interest in, and by BBC's and email lists. We also have friends who call on us to help them in their daily work, answer questions about why this error or that warning are flashing across their screens, or the best way to get around a known bug. We help each other becuase we're all on a mission to build and leverage technology to do the shit work for us. However, when that technology breaks, it's the community that we commonly go back to, asking questions, seeking answers. 

The other day a colleague asked me why I use explicit hiera() lookups in my code. He made a lot of very sound points: it's messy, automatic data bindings already do this for us, it's clearer if you just assume the data is coming from hiera... I agreed with all of them, yet I still use the explicit lookup in my profiles. Why?

I do this because everyone else does this, it's a community best practice. His response was, well sure, we can all be sheep. Ah yes, sheep. Let's side track on that topic for a second. Why do sheep travel in packs and follow each other? They do it because when a preditor shows up, they can work as a group to confuse it, and possibly save each other. They work together for the common good. 

In our line of work we need the community. Why use a tool like Puppet or Chef, an open source, community supported framework, if you're just going to tuck the best practices away in your pocket becuase you feel like it doesn't suit you? If that was your intent all along, you might as well roll your own CM tool. Oh wait, rolling your own tool sounds really hard? Ok then use the open source tool chain. And when you get that error about hiera not finding data in one of your 50 profiles, but you know the data is in hiera and you can't figure out what's going on, where do you turn? IRC, BBC, email lists, jira, etc... and when you put your code down in those forums and everyone see's you're not explicitly looking up the values, it's then someone asks "Is this a fresh node?" "sure is!" you say "Maybe the operations person who provisioned puppet turned off automatic data bindings..." - that turns out to be the case... or any number of other possible scenarios that might prevent hiera from getting a value. 
