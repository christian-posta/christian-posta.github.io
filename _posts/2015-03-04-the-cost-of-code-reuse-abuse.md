---
layout: post
title: "The Cost of Code Reuse Abuse"
modified:
categories: design
comments: true
tags: [microservices, design, code-reuse, DDD]
image:
  feature:
date: 2015-03-04T06:32:02-07:00
---

Oddly enough, while I'm sleeping or in some zombie state while attempting to sleep, I often feel like the ideas I have while in that state are the best thing ever and could possibly solve all the worlds problems. But then I wake up, and try to recall those thoughts and realize... nope, just shit.

But I think last night I was stirring up something in my head that has some merit, and something I've been thinking about for a while, inspired by a blog I read by [Udi Dahan][udi] a while back (not sure how a blog post from 09 prompted me to think about this just now...). To wit, the idea that "code reuse" is the goal of many recent architectural styles, software methodologies, and "#bestPractices". That if we can just "reuse" code, that we save on the "cost" of developing software, and thus can get to delivery faster. 

In fact, that's nonsense.

And Udi Dahan does a great job of [explaining the differences between "use" and "reuse"][udi-reuse] in his blog post from a while back. His point is that code "use" is that of the generic kind: frameworks, common utility libraries, etc. That "reuse" is much more domain specific: business logic. Furthermore, the true cost of delivering software lies in things other than writing code. He says

>There’s the time it takes us to understand what the system should do.
>Multiply that by the time it takes the users to understand what the system should do :-)
>Then there’s the integrating that code with all the other code, databases, configuration, web services, etc.
>Debugging. Deploying. Debugging. Rebugging. Meetings. Etc.

Yep. And he starts to get toward how dependencies on the "reuse" type of code is expensive:

>It’s to be expected. If you wrote the code all in one place, there are no dependencies. By reusing code, you’ve created a dependency. The more you reuse, the more dependencies you have. The more dependencies, the more rebugging.
    
Yep. Code use, sure that's okay. Code "reuse", that should raise eyebrows and there should be some pushback. And let me take this one step further.   


Once we step into the world of microservices where each service should own its purpose, code, logic, entities, etc (think, autonomous components,  [bounded context][bc]), we have to think "how do we reduce our dependencies" not, "how do we share all this crap code that I wrote".

One thing I've seen is people trying to make their business logic more "generic". Oh, then using/reusing is all good, right? This is __hugely__ wrong!! Don't do this! Business logic is supposed to model a business process in very _specific_ way. If you try to "generecize" everything, you've now got ambiguity, a loss of expression/intent, and this ends up __dramatically increasing technical debt__!!! Not to mention, the reason for making things more generic is reuse... So now you've spread this crap throughout your code/services/components/architecture. And now your cost of change has gone up. And one thing we're trying to do is _reduce the cost of change_ with our antics!

Not to mention, writing generic code is actually quite difficult. If you're starting a new project by writing a framework or some generic code, you're doing it wrong and you need to just __stop__. 







[udi]: http://www.udidahan.com
[udi-reuse]: http://www.udidahan.com/2009/06/07/the-fallacy-of-reuse/
[bc]: http://martinfowler.com/bliki/BoundedContext.html