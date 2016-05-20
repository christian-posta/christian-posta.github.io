---
layout: post
title: "Message Durability in ActiveMQ 5.x"
modified:
categories: activemq
comments: true
tags: [activemq, messaging, durability, jms]
image:
  feature:
date: 2016-05-20T09:41:04-07:00
---

I get asked quite a bit to explain the basics of how ActiveMQ works with respect to how it stores messages (or doesn't in some cases). Here's the high level explanation of it. Note, the context is within JMS. If you use ActiveMQ's non JMS clients (ie, STOMP, AMQP, MQTT, etc) then the behavior may be different in some cases.  


## ActiveMQ 

The JMS durability guarantees are pretty strong in terms of not losing messages that are marked "persistent." Let's see how that applies for ActiveMQ

### Topics
Topics are a broadcast mechanism. They allow us to implement publish-subscribe semantics in JMS land. However, what happens if we mark a message "persistent" and there are no subscribers? In any normal broadcast (ie, I go downtown and start shouting about the awesomeness of ActiveMQ), if there are no subscribers (it's 3a and there's nobody around to hear me.... must've been a good night out if i'm out at 3a) then what happens? Nothing. Nobody hears it. And we move on. ActiveMQ doesn't do anything with the message if you publish it (persistent or not persistent) and there are no subscribers (no live subscribers and no durable subscribers). 

ActiveMQ will only store the message if there are _durable_ subscribers (active or inactive). For an inactive durable subscription, ActiveMQ will store messages marked "persistent" into a non-volatile store and wait for a subscriber to rejoin the subscription. At that point it will try to delivery messages. 


### Queues
For queues, ActiveMQ treats "persistent" messages with a simple default protocol. We basically block the main producer thread and wait for confirmation that the broker has actually gotten the message:

Producer:

* Producer sends message
* Producer blocks, waits for ACK from broker
  * Producer continues on if successful ACK
  * Retries if NACK or timeout or failover

Broker:
* receives message
* stores message to disk
* sends back ACK

![amq persistent flow](/images/activemq-durable/amq-persistent.png)

For "non-persistent" sends, the flow is different. We send in a "fire and forget" mode. The main producer thread does not get blocked and any ACK or other response happens asynchronously on the ActiveMQ Connection Transport thread:

* Producer sends message
* Producer continues on with its thread and does not block
* Producer eventually gets ACK on a separate thread than the main producer thread
  * if failure, then clients can subscribe to a [JMS ExceptionListener](https://docs.oracle.com/javaee/7/api/javax/jms/ExceptionListener.html) to get notified
 

![non-persistent flow](/images/activemq-durable/amq-non-persistent.png)



#### Transacted sends?

We can increase performance of sends to the broker by batching up multiple messages to send at once. This utilizes the network as well as the broker storage more effectively. There's an important distinction you must be aware of when sending transacted. The opening of the TX session and the closing of it (rollback/commit) are all _sycnhronous_ interactions with the broker, _however_, the sends for each individual message during the TX window are all sent _asynchronous_. This is okay if everything works out because the broker batches these messages up. But what happens if there are transport errors? Or the broker runs out of space to save these messages?

We need to set an [ExceptionListener](https://docs.oracle.com/javaee/7/api/javax/jms/ExceptionListener.html) to watch for errors during these sends. We also need to (or should) set a client side sending "producer window" to allow us to enforce producer flow control when the broker runs out of resources. See [ActiveMQ producer flow control](http://activemq.apache.org/producer-flow-control.html) for more. 

![tx flow](/images/activemq-durable/amq-tx-send.png)


#### Changing the defaults

The interesting settings on the producer that can change these behaviors:

* useAsyncSend - always wait for ACKs asynchronously, even in persistent sends and commits
* alwaysSyncSend -- force all sends (non-persistent or transactional sends included) to always wait for ACK from the broker

Using the defaults are generally what folks want. 

### Storage

For production usage of ActiveMQ, I recommend the [shared-storage approach](http://activemq.apache.org/shared-file-system-master-slave.html) at the moment. In this case, we need to be aware of what's happening at the storage layer to understand ActiveMQ's guarantees.   

ActiveMQ by default will implement JMS durability requirements which basically states messages that get stored must survive crashes. For this, we by default will do a "fsync" on the filesystem. Now what happens on each system will be dependent on what OS, network, storage controller, storage devices, etc you use. This is the same you'd expect for any type of database that needs to persistently store messages and is not ActiveMQ specific per-se.

When we write to the ActiveMQ transaction journal we need to ask the OperatingSystem to flush the journal to disk with a call to _fsync_. Basically what happens is we force the OS to write back the page-file cache it uses to cache file changes to the storage medium. It also encourages the storage medium to do what it needs to do (depends on implementation) to "store" the data to disk:

![storage](/images/activemq-durable/storage-layers.png)

Some storage controllers have their own cache that needs to be flushed. The disk drives have their own caches, etc. Some of these caches are backed by battery and may write-back at their own time intervals, etc. For you to understand the durability of your messages running through ActiveMQ, you should understand the guarantees of your storage layer.


### Consumers

Finally the last piece of the puzzle is how we deliver/dispatch messages to consumers and how they acknowledge. The ActiveMQ JMS libraries handle all of this for you, so you don't need to worry about whether or not you're going to lose messages.


![consumer dispatch](/images/activemq-durable/dispatch.png)

Messages get dispatched to consumers up to a certain "prefetch" buffer that lives on the consumer. This helps speed up message processing by having an available cache of messages on the consumer ready to process and then refill this cache as the consumer consumes them. In ActiveMQ these prefetched messages are denoted as "in flight" in the console. A this point it's up to the consumer to process these messages and ACK them. (this will depend on the ack modes... default of auto ack will send the ACK as the consumer gets the message.. for more important message processing you may wish to use "client" ack where the client explicitly says when to ack the message, ie, after it's completed some processing). 

If the consumer fails for some reason, any of the non-ack'd messages will be redelivered to another consumer (if available) and follow the same processing as above. The broker will not remove the message from its indexes until it get an ACK. So this includes failures at both the consumer and network level. If there are errors at either of these levels even after a consumer as "successfully processed" (note, this is very use case what "successfully processed" means), and the broker does not get the ack, then it's possible the broker will re-send the message. In this case you could end up with duplicates on the consumer side and will probably want to implement an idempotent consumer. For scaling up messaging producers/consumers, you'll want to have idempotent consumers in place anyway. 

Last thing to note: JMS DOES NOT GUARANTEE ONCE AND ONLY ONCE PROCESSING of a message without the use of XA transactions. JMS guarantees once and only once delivery insofar it can mark messages as being "redelivered" and have the consumer check that, but the consumer is responsible for how many times it should be allowed to process (or filter out with idempotent consumer). 

