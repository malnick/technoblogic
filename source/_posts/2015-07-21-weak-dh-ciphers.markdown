---
layout: post
title: "Weak Diffe-Helman SSL Ciphers"
date: 2015-07-21 11:32:12 -0700
comments: true
categories: 
---
We recently scanned our ```srcclr.com``` domain via [Qualsys](https://www.ssllabs.com/) SSL Labs scanning suite. When we deployed this site in March (a migration from sourceclear.com to srcclr.com) we had an A+ rating. 

<!-- more -->

However, our CEO recently re-scanned the site, and to our dismay, we got a B rating.

What was the cuase? According to SSL Labs, we were supporting "weak Diffie-Hellman (DH) key exchange parameters. Grade capped to B."

Usually this would be due to supporting export grade crypto suites, which can be used in a man in the middle attack to fake you into using a weak cipher during your session. 

In order to double check the SSL labs output, I ran my own scan using nmap:

```
nmap --script ssl-enum-ciphers -p 443 srcclr.com                  
Starting Nmap 6.47 ( http://nmap.org ) at 2015-07-21 11:31 PDT
Nmap scan report for srcclr.com (107.23.63.147)
Host is up (0.094s latency).
Other addresses for srcclr.com (not scanned): 52.7.116.135
rDNS record for 107.23.63.147: ec2-107-23-63-147.compute-1.amazonaws.com
PORT    STATE SERVICE
443/tcp open  https
| ssl-enum-ciphers:
|   SSLv3: No supported ciphers found
|   TLSv1.0:
|     ciphers:
|       TLS_DHE_RSA_WITH_AES_128_CBC_SHA - strong
|       TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA - strong
|       TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA - strong
|       TLS_RSA_WITH_3DES_EDE_CBC_SHA - strong
|       TLS_RSA_WITH_AES_128_CBC_SHA - strong
|       TLS_RSA_WITH_AES_256_CBC_SHA - strong
|     compressors:
|       NULL
|   TLSv1.1:
|     ciphers:
|       TLS_DHE_RSA_WITH_AES_128_CBC_SHA - strong
|       TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA - strong
|       TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA - strong
|       TLS_RSA_WITH_3DES_EDE_CBC_SHA - strong
|       TLS_RSA_WITH_AES_128_CBC_SHA - strong
|       TLS_RSA_WITH_AES_256_CBC_SHA - strong
|     compressors:
|       NULL
|   TLSv1.2:
|     ciphers:
|       TLS_DHE_RSA_WITH_AES_128_CBC_SHA - strong
|       TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA - strong
|       TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256 - strong
|       TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 - strong
|       TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA - strong
|       TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384 - strong
|       TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 - strong
|       TLS_RSA_WITH_3DES_EDE_CBC_SHA - strong
|       TLS_RSA_WITH_AES_128_CBC_SHA - strong
|       TLS_RSA_WITH_AES_128_CBC_SHA256 - strong
|       TLS_RSA_WITH_AES_128_GCM_SHA256 - strong
|       TLS_RSA_WITH_AES_256_CBC_SHA - strong
|       TLS_RSA_WITH_AES_256_CBC_SHA256 - strong
|       TLS_RSA_WITH_AES_256_GCM_SHA384 - strong
|     compressors:
|       NULL
|_  least strength: strong

Nmap done: 1 IP address (1 host up) scanned in 4.64 seconds
```

Low and behold, there were the weak DHE non EC type ciphers. 

Our front ends for our corporate site are hosted on Elastic Load Balancers. I double checked their configuration, and it appears AWS updated the default cipher suite in May, about a month after we deployed the site. The new cipher policy removes the non EC Diffe-Helman ciphers from the list. I turned on the new policy (which should automatically default to newest, IMO) and re-ran a scan:

```
nmap --script ssl-enum-ciphers -p 443 srcclr.com

Starting Nmap 6.47 ( http://nmap.org ) at 2015-07-21 12:21 PDT
Nmap scan report for srcclr.com (107.23.63.147)
Host is up (0.091s latency).
Other addresses for srcclr.com (not scanned): 52.7.116.135
rDNS record for 107.23.63.147: ec2-107-23-63-147.compute-1.amazonaws.com
PORT    STATE SERVICE
443/tcp open  https
| ssl-enum-ciphers:
|   SSLv3: No supported ciphers found
|   TLSv1.0:
|     ciphers:
|       TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA - strong
|       TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA - strong
|       TLS_RSA_WITH_3DES_EDE_CBC_SHA - strong
|       TLS_RSA_WITH_AES_128_CBC_SHA - strong
|       TLS_RSA_WITH_AES_256_CBC_SHA - strong
|     compressors:
|       NULL
|   TLSv1.1:
|     ciphers:
|       TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA - strong
|       TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA - strong
|       TLS_RSA_WITH_3DES_EDE_CBC_SHA - strong
|       TLS_RSA_WITH_AES_128_CBC_SHA - strong
|       TLS_RSA_WITH_AES_256_CBC_SHA - strong
|     compressors:
|       NULL
|   TLSv1.2:
|     ciphers:
|       TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA - strong
|       TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256 - strong
|       TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 - strong
|       TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA - strong
|       TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384 - strong
|       TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 - strong
|       TLS_RSA_WITH_3DES_EDE_CBC_SHA - strong
|       TLS_RSA_WITH_AES_128_CBC_SHA - strong
|       TLS_RSA_WITH_AES_128_CBC_SHA256 - strong
|       TLS_RSA_WITH_AES_128_GCM_SHA256 - strong
|       TLS_RSA_WITH_AES_256_CBC_SHA - strong
|       TLS_RSA_WITH_AES_256_CBC_SHA256 - strong
|       TLS_RSA_WITH_AES_256_GCM_SHA384 - strong
|     compressors:
|       NULL
|_  least strength: strong

Nmap done: 1 IP address (1 host up) scanned in 4.38 seconds
```

That appeared to have done the trick. I double checked by [re-scanning our site on SSL labs](https://www.ssllabs.com/ssltest/analyze.html?d=srcclr.com&s=52.7.116.135&latest), and it came up as an A+.

Moral of the story: scan your site regularly so you can stay on top of all the breaking SSL vulnerabilities. We should have been doing this every month, and will try to stick to that schedule from here on out. 
