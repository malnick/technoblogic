---
layout: post
title: "TLS/SSL DH Cipher Padding Bug in ActiveMQ"
date: 2014-03-17 16:23:11 -0700
comments: true
categories: 
---
### Update

As of March 18 it appears that Oracle has implemented a fix in their release of [JDK and Java Standard Edition version 8](http://www.oracle.com/technetwork/java/javase/8train-relnotes-latest-2153846.html) and it's assocaited [security extensions](http://docs.oracle.com/javase/8/docs/technotes/guides/security/enhancements-8.html):

"Support stronger ephemeral DH keys in the SunJSSE provider: Make ephemeral DH key match the length of the certificate key during SSL/TLS handshaking in the SunJSSE provider. A new system property, jdk.tls.ephemeralDHKeySize, is defined to customize the ephemeral DH key sizes. The minimum acceptable DH key size is 1024 bits, except for exportable cipher suites or legacy mode (jdk.tls.ephemeralDHKeySize=legacy). See Customizing Size of Ephemeral DH Keys and RFE 6956398."

----------------------

In helping a client with an ActiveMQ issue in Puppet Enterprise I recently stumbled across this line in their wrapper log:

	INFO | jvm 1 | 2014/02/26 12:47:20 | WARN | Transport Connection to: tcp://ip.removed:49867 failed: javax.net.ssl.SSLHandshake
	Exception: Invalid Padding length: 239

The client thought this may have been exacberating a JVM memory problem, however I found it actually is a not related but in and of itself it's own  bug in the Java Security Extensions for Diffe-Helman cipher implementation over SSL. 

We have seen similar issues in JDK 1.7x security extensions in other Java-powered backends for Puppet Enterprise such as [PuppetDB](http://projects.puppetlabs.com/issues/19884). It has also been documented on the [Apache ActiveMQ ticket board](https://issues.apache.org/jira/browse/APLO-287) and the [Oracle community](https://community.oracle.com/message/11001587) board. 

The issue is dependant on:

	* OpenJDK Runtime Environment (PE Java 1.7.0.19) 
	* Linux OS's (so far my testing is on CentOS 6x) 
	* TLS_DHE_RSA_WITH_AES_128_CBC_SHA Cipher
	* openssl-1.0.0-27.el6_4.2.x86_64
	

To sum up the problem, every few hundred messages that are encrypted over SSL or TLS using DH ciphers the client gets a handshake exception. The exception is caused by a faulty SSL packet.

### Oracle's Solution
[A ticket was submitted](http://bugs.java.com/bugdatabase/view_bug.do?bug_id=8013059) to Java bugs and was set "resolved" on 2013-10-25. However, and this is a big however, their resolution is, "In order to have reliable TLS handshakes, Diffie Hellman key exchanges must be disabled."

I personally don't like this resolution since DH keys are sometimes neccessary, and in terms of security is superior to standard RSA ciphers. DH ciphers provide perfect forward secrecy. That means even if the private key is compromised you can not decrypt past data. Ciper suites which use DHE-RSA-AES128-SHA all implement the slower, more secure ephemeral DH crypto - it's ephemeral since new random numbers that generate the key are used each time. This is also why it's slower. However, it's also harder to run a selected clear text attack on EDH since the private key is used for only authentication and use an independant method to agree on a shared secret - standard RSA ciphers employ the private key for both auth and encryption for better performance in exchange for not providing perfect forward secrecy. 

You may now chime in with your own conspiracy theories as to why Oracle would settle for solving this cyrpto issue by simply using a less secure cipher - does the NSA not want Java applications, which function as the backbone to a great deal of web traffic, encrypting data with perfect forward secrecy? 

### Workaround in AMQ

Since there is no good way to get around this problem in JDK 1.7x security extensions you have two choices:

	1. Live with the error in approx. 5% of the SSL traffic
	2. Run SSL with a non-DH or DHE cipher  

#### Door #1
Example, you've got an AMQ broker administering messaging for 1000+ AMQ agents in a live management setup in Puppet Enterprise you'll see this error a lot, and it may (warning, assumption) degrade live management performance in such a large deployment.    

If you can live with either seeing this error 5% of the time or you can live with the hit in performance sticking it out with DH can still work. 

#### Door #2

You need the performance or are a stickler for perfect SSL key exchange. 

A possible solution would be modifying the transportConnector in /etc/puppetlabs/activemq/activemq.xml:

	<transportConnector name="openwire" uri="ssl://0.0.0.0:61616"/>
	<!-- Puppet mcollective_enable_stomp_ssl=true
	<transportConnector name="stomp+ssl" uri="stomp+ssl://0.0.0.0:61613"/>\

With the transport.enabledCipherSuites embedded:

	ssl://localhost:61616?transport.enabledCipherSuites=SSL_RSA_WITH_3DES_EDE_CBC_SHA

The SSL_RSA_WITH_3DES_EDE_CBC_SHA is non-DH cipher versus the  SSL_DH_anon_WITH_3DES_EDE_CBC_SHA which I think is what AMQ currently uses.

Note syntax: 
	ssl://…?socket.enabledCipherSuites=THE_CIPHER # for agents 

and 

	ssl://…?transport.enabledCipherSuites=THE_CIPHER # for brokers 

More information about this can be found on the [AMQ reference page](https://activemq.apache.org/ssl-transport-reference.html)


