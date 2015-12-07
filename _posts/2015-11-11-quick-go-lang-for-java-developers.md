---
layout: post
title: "Quick Go-lang for Java Developers"
modified:
categories: programming
comments: true
tags: [java, golang, learning]
image:
  feature:
date: 2015-11-11T17:40:23-07:00
---

[Golang][golang] seems to be getting quite popular as its the programming language of choice for some cool new
technology like [Docker][docker], [Kubernetes][k8s], and [OpenShift][os3]. Luckily enough, they're all opensource
too which means we can all contribute to these communities and get involved. One particularly awesome benefit of
opensource that turns out to be extremely valuable and helpful in many circumstances is the obvious one: open _source_.
I cannot tell you how often I've had to jump into the source of a project, regardless of the programming language
used to implement it, to really understand what it's doing or even more important: why it's not doing something
the docs say it should (or when there are no docs). Code is _read_ far more often than it's written, so it helps to
understand how to read it. 

I've learned quite a few programming langues in my day (C,C++,C#,Java,Python, Scala, Groovy, Assembly, JavaScript,etc)
and now it's Go. I've spent a few weeks learning to read Golang and reading source files from the Kubernetes, Fabric8,
and OpenShift Origin code bases to be able to understand them a little deeper, and I think it would be helpful for 
developers familiar with another programming language to quickly map certain concepts from -- say Java -- to Golang
for the simple purpose of being able to get over the fear of jumping in to help these communities or more selfishly
to be able to read and understand how some of the new technology written in Golang actually works.

Here are a few of the key pieces that stood out for me at first. Feel free to Tweet (@christianposta) me others 
you feel could be added here, or leave a comment. This article is certainly not meant to be an introduction to Go nor
is it a complete Java->Go mapping. The purpose of the article is to quickly help Java developers understand a handful
of common Go idioms in terms of how that maps to Java. 


## Project structure

It appears that a common convention for Golang projects is to have all cli binary source files, or those in a "main" package, 
placed in the `cmd` folder which is at the root of the source tree. Packages that implement a lot of the functionality and
represent organizing cohesive sets of Types, constants, variables and functions, can usually be found in the `pkg`
folder in the root of the source directory.


## Packages
Golang organizes its code into packages, similarly to Java. You declare which package a source file is in (and all of
its constants, types, functions, etc) by typing `package <package_name>` at the top of the source file; however, 
unlike Java, you don't put the full path (directory location), just the name. Example:

{% highlight java %}
package api
{% endhighlight %}

So if you have a package "api/endpoints" you'd have that directory structure on the filesystem (eg ./pkg/api/endpoints)
but the `endpoints` package would be declared in source files under the `endpoints` directory, but they'd look like this:

{% highlight java %}
package endpoints
{% endhighlight %}

## Importing packages

We can import packages, just like we do in Java with the following:

{% highlight java %}
import (
	stderrs "errors"
	"time"

	"golang.org/x/net/context"
	"k8s.io/kubernetes/pkg/auth/user"
)
{% endhighlight %}


We can use packages within the source code based on the last package name in the package path. For example, in the
above example, we import `k8s.io/kubernetes/pkg/auth/user` and from with the code we can refer to the elements
inside that package with `user.Foo()`. If we want to rename the package within our source file so it doesn't
collide with other names, we can do what we did above:

{% highlight java %}
import (
	stderrs "errors"
)
{% endhighlight %}

And refer to the `errors` package within our source code as `stderrs.Foo()`

## Main package

The `main` package is where golang looks to find the entrypoint of the application. The `main` package must have
a `main()` function that takes no arguments and provides no return values:

{% highlight java %}
func main() { … }
{% endhighlight %}


As aforementioned, this package is usually found in the `cmd` folder in the root directory.


## Scope/visibility of types, constants, functions

In golang, to provide visibility scope to a struct/type/function/variable, to be exposed outside of a package, 
the first character in the symbol is significant. For example, within a package `foo`, if you have a function named
`func Bar()`, then because "Bar" has an upper-case first letter, it will be usable outside of the package. If you import
`foo` package, you'll be able to access `foo.Bar()`. If "bar" was lowercase, it would be hidden -- that is, the case
of the first letter determines visibility
 
 

## Methods can return multiple values

A function or method in golang (there is a distinction) can return a "tuple" or multi-value return. For example,
calling a function that returns multiple values looks like this:

{% highlight java %}
internalCtx, ok := foo.bar(context.Context)
{% endhighlight %}


## Classes, structs, methods

In Java we have Classes, but in Go we have structs. Structs can have methods on them, so they are kinda like classes.

For example:

{% highlight java %}
type Rectangle struct {
    width int
    height int
}
{% endhighlight %}

This is a data structure named "Rectangle" that has two fields: `width` and `height`. We can create a new `Rectangle` like this:

{% highlight java %}
r := new(Rectangle)
{% endhighlight %}

and we can refer to its fields like this:

{% highlight java %}
r.width = 10
r.height = 5
{% endhighlight %}

We can write methods on a Struct that operates on the fields of the struct like this:

{% highlight java %}
func (r *Rectangle) area() int {
    return r.width * r.height
}
{% endhighlight %}

So if you see idioms like this in golang code, think "Java classes"

## Type inheritance

Golang purposefully doesn't have a "extends" type like Java does. Inheritance is done via composition (kinda like we
should do that in Java as a "best practice" anyway :) ) However, it does look a lot like the "extends" keyword in Java
in terms of how it's visible to the programmer. For example:

{% highlight java %}

type Rectangle struct {
	Shape
    width int
    height int
}

{% endhighlight %}

In this example, Rectangle has an anonymous field of type `Shape`. Whatever fields and methods `Shape` have will be
visible on `Rectangle` objects. 

One thing to note, however, is that just because `Rectangle` "is-a" `Shape`, this is not like in Java where we could
pass in a `Rectangle` to a function that takes a `Shape` as a parameter. This would fail in Go. To get that type
of "type" polymorphism, you should use Go interfaces (next section)

## Polymorphism, interfaces, and duck typing

In Java, we have specific interface types which specify behavior based on the methods that must be implemented by
classes that claim to be that type. In Go, we do have intefaces that do the same thing, but classes don't actually 
declare that they're going to implement them specifically: they just implement the methods and then they fit that
Interface. 

For example this interface declares a Shape type that has Print() method:
 
{% highlight java %}
type Shape interface {
    Print()
}
{% endhighlight %}

However, when we create our Structs, we don't have to declare this at all with "implements" like we do in Java: we just
implement the methods and they can be passed to functions and treated as that type:

{% highlight java %}
type Rectangle struct {
    width int
    height int
}

func (r *Rectangle) Print() {
    fmt.println("Rectangle!");
}
{% endhighlight %}


In this case, the Rectangle object could be passed to functions that expect a `Shape` type because it implements
all of the methods for that type.

 

## For loops

An example for-loop with go:

{% highlight java %}
for i := 1; i <= 10; i++ {
  fmt.Println(i)
}
{% endhighlight %}

However, when iterating of an array (or something that looks like an array eg, string, map, slice, etc), you can
use the range operator like this (assume `foo` is a list):

{% highlight java %}

for _, v := range foo {
  fmt.Println("value="+ strvonv.Itoa(v));
}

{% endhighlight %}


If you need to know the index of the list as you iterate through it, looks like this:

{% highlight java %}
for i, v := range foo {
  fmt.println("index " + i + "has value="+v);
}
{% endhighlight %}

## While loops

Go does not have while loops, or do-while, or foreach, etc. You just use the for loop again like this:

{% highlight java %}
sum := 1
for sum < 1000 {
	sum += sum
}
fmt.Println(sum)
{% endhighlight %}

Or can do an infinite while loop:

{% highlight java %}
	
for {
	something...
}
	
{% endhighlight %}


## Pointers and reference
Golang uses pointers and references explicitly whereas Java mostly hides that. For example, in Java we could do

`Shape shape = new Shape()` and then `shape.foo()` but in Go, we have to take care of the pointers directly:

{% highlight java %}
	
type Rectangle struct {
    width int
    height int
}

func updateRectangle(r *Rectangle){
    
    r.width = 5;
    r.height = 10;
}

func main() {
    r := Rectangle{20,30}
    updateRectangle(&r)
}
	
{% endhighlight %}

When the main function ends, the rectangle `r` would have the value width=5 and height=10 as you would expect.
Take note, we have to make explicit references to the pointers.

## Garbage collection

Golang is a garbage collected language; no need to explicitly release memory yourself (I know what you were thining
whe you saw the pointers and references section above :)).


If you're a Java developer and would like to add more to this please feel free to let me know (@christianposta)! Or
if you're a go-lang developer and I've misstated something here, please correct me! Hope this is helpful... 

[golang]: https://golang.org
[docker]: https://github.com/docker/docker
[k8s]: https://github.com/kubernetes/kubernetes
[os3]: https://github.com/openshift/origin/