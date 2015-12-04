---
layout: post
title: "Using Spring-data With Apache Camel"
modified:
categories: 
comments: true
tags: [spring, spring-data, camel, apache, integration, examples]
image:
  feature:
date: 2015-12-02T19:05:21-07:00
---

[Spring Data][spring-data] saves you a lot of time by creating smart DAOs that you can basically get for free without writing any code. It basically follows the [Repository Pattern][repo-pattern] from [Eric Evans' DDD book][ddd-book] and treats entities as collections. It has a great convention that allows you to specify criteria for complex queries, and even leverage the [JPA Criteria API][jpa-criteria] or the [QueryDSL fluent APIs][query-dsl] for even more complex queries/specifications. The best part is the abstraction works not just for JPA, but [many other providers][many-others]. There are [some great examples][examples] using spring-data within the spring ecosystem like [Spring Boot][boot] but some times you want to use it outside the magical, enchanted world of Spring Boot. 

And if you're doing any serious system integration, you're probably also using [Apache Camel][camel], so in the following quick blog (promise) I'll show you the salient parts you'll need when using with Camel... however, there's nothing too special here. We basically deconstruct some of the magic that Spring Boot otherwise takes care of for you and allows you to understand the constituent pieces that will be necessary to have in place (and this is true if running Tomcat, Dropwizard, Wildfly, or any container). 

The sample code for this is [located here at my github for some code we were working on][code].


First step, you'll want the JPA and spring-data dependencies!

{% highlight xml %}

<!-- spring data + JPA -->
<dependency>
  <groupId>org.springframework.data</groupId>
  <artifactId>spring-data-jpa</artifactId>
</dependency>

<dependency>
  <groupId>org.springframework.data</groupId>
  <artifactId>spring-data-commons</artifactId>
</dependency>
<dependency>
  <groupId>org.hibernate.javax.persistence</groupId>
  <artifactId>hibernate-jpa-2.1-api</artifactId>
  <version>1.0.0.Final</version>
</dependency>
<dependency>
  <groupId>org.hibernate</groupId>
  <artifactId>hibernate-entitymanager</artifactId>
  <version>${hibernate.version}</version>
</dependency>
<dependency>
  <groupId>org.hibernate</groupId>
  <artifactId>hibernate-core</artifactId>
  <version>${hibernate.version}</version>
</dependency>

{% endhighlight %}


This will prep the classpath for us, which should include a JPA API and the entity managers for the provider we'll use.

Next, we should add the following to the spring-context/bean-factory:

{% highlight xml %}

<bean id="dataSource" class="org.apache.commons.dbcp.BasicDataSource" destroy-method="close">
  <property name="driverClassName" value="org.apache.derby.jdbc.EmbeddedDriver"/>
  <property name="url" value="jdbc:derby:memory:orders;create=true"/>
  <property name="username" value=""/>
  <property name="password" value=""/>
</bean>

<bean id="sessionFactory" class="org.springframework.orm.hibernate4.LocalSessionFactoryBean">
  <property name="dataSource" ref="dataSource"/>
</bean>

<bean id="entityManagerFactory" class="org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean">
  <property name="dataSource" ref="dataSource"/>
  <property name="persistenceXmlLocation" value="classpath:/META-INF/persistence.xml"/>
  <property name="persistenceUnitName" value="sample"/>
  <!-- spring based scanning for entity classes>-->
  <property name="packagesToScan" value="org.jboss.fuse.examples.rest"/>
</bean>

<bean id="transactionManager"
      class="org.springframework.orm.hibernate4.HibernateTransactionManager">
  <property name="sessionFactory" ref="sessionFactory"/>
  <property name="dataSource" ref="dataSource"/>
</bean>

{% endhighlight %}

This is all [run of the mill Spring ORM stuff][spring-orm]; nothing too fancy here, but is the boilerplate stuff that spring-data will need.

To use JPA, we'll also want an `persistence.xml` file. If you want to use Mongo or something else, refer to that specific spring-data mdoule for how to do that.

{% highlight xml %}

<persistence xmlns="http://java.sun.com/xml/ns/persistence"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://java.sun.com/xml/ns/persistence http://java.sun.com/xml/ns/persistence/persistence_2_0.xsd"
             version="2.0">
  <persistence-unit name="sample">
    <provider>org.hibernate.ejb.HibernatePersistence</provider>
    <properties>
      <property name="hibernate.dialect" value="org.hibernate.dialect.DerbyTenSevenDialect"/>
    </properties>
  </persistence-unit>
</persistence>

{% endhighlight %}


This should give us the foundation for using spring-data! Now, let's do some fun stuff. We'll add a Repository that will allow us to do CRUD operations (and more!) against the database:

{% highlight java %}

package org.jboss.fuse.examples.repositories;

import org.jboss.fuse.examples.rest.Organization;
import org.springframework.data.repository.PagingAndSortingRepository;

/**
 * Created by ceposta 
 * <a href="http://christianposta.com/blog>http://christianposta.com/blog</a>.
 */
public interface OrganizationRepository extends PagingAndSortingRepository<Organization, Integer> {

}

{% endhighlight %}

We have our repository but we need to tell spring how to find it and apply some magic. So let's add it to the spring context like this (and have spring scan a package to discover the repository)

{% highlight xml %}

<jpa:repositories base-package="org.jboss.fuse.examples.repositories"/>

{% endhighlight %}

Note, this will require the appropriate namespaces (assumption is we're using the spring XML config; java config is also supported but not shown here):


{% highlight xml %}

<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xmlns:jpa="http://www.springframework.org/schema/data/jpa"
       xsi:schemaLocation="
          http://camel.apache.org/schema/spring http://camel.apache.org/schema/spring/camel-spring.xsd
          http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd
  		  http://www.springframework.org/schema/data/jpa http://www.springframework.org/schema/data/jpa/spring-jpa.xsd">
  		  
{% endhighlight %}

Now let's inject our repository into our own POJO class from which we can use it! Woah, woah... "we haven't actually written any code to implement this repository" you say... yes that's true! [Spring-data][spring-data] does that for us!

Let's inject:

{% highlight xml %}

<bean id="orgCollection" class="org.jboss.fuse.examples.rest.OrganizationCollection">
  <property name="repository" ref="organizationRepository"/>
</bean>

{% endhighlight %}

Note the name of the repository `organizationRepository` is created by convention by spring when it scans the package for repositories, but we can still get a hold of it and use it like any other spring bean in the bean factory. Now, let's use this wrapper class (`OrganizationCollection` in this case) in our Camel routes:

{% highlight xml %}
<route id="findAll">
  <from uri="direct:findAll"/>
  <bean ref="orgCollection" method="findAll"/>
</route>


<route id="orgById">
  <from uri="direct:orgById"/>
  <bean ref="orgCollection" method="findById"/>
</route>

<route id="paginate">
  <from uri="direct:paginate"/>
  <bean ref="orgCollection" method="findOrganizationWithPagination"/>
</route>
{% endhighlight %}

Cool! We have 3 separate routes that use our orgCollection pojo (which in turn uses the organizationRepository that leverages spring-data). Let's take a look at that POJO:

{% highlight java %}

package org.jboss.fuse.examples.rest;

import org.apache.camel.Header;
import org.apache.camel.language.Simple;
import org.jboss.fuse.examples.repositories.OrganizationRepository;
import org.springframework.data.domain.PageRequest;


public class OrganizationCollection {

    private OrganizationRepository repository;


    public Organization insertNewOrganization(@Simple("body.org_id") Integer id, @Simple("body.org_name") String name) {
        Organization org = new Organization(id, name);
        return repository.save(org);
    }

    public Iterable<Organization> findAll(){
        return repository.findAll();
    }

    public Iterable<Organization> findOrganizationWithPagination(@Header("pageNumber")int pageNum, @Header("pageSize")int size){
        return repository.findAll(new PageRequest(pageNum, size));
    }

    public Organization findById(@Header("id")int id) {
        return repository.findOne(id);
    }

    public OrganizationRepository getRepository() {
        return repository;
    }


    public void setRepository(OrganizationRepository repository) {
        this.repository = repository;
    }
}

{% endhighlight %}

We inject the `OrganizationRepository` and use it here to query the data store. Notice the parameters have [Apache Camel][camel] annotations that extract values from the headers and body to use as parameters.




[spring-data]: http://projects.spring.io/spring-data/
[many-others]: http://projects.spring.io/spring-data/
[examples]: https://github.com/spring-projects/spring-data-examples
[ddd-book]: http://www.amazon.com/Domain-Driven-Design-Tackling-Complexity-Software/dp/0321125215
[code]: https://github.com/christian-posta/apiprovider-poc/tree/spring-data
[spring-orm]: http://docs.spring.io/spring/docs/current/spring-framework-reference/html/orm.html
[repo-pattern]: https://lostechies.com/jimmybogard/2009/09/03/ddd-repository-implementation-patterns/
[jpa-criteria]: http://docs.oracle.com/javaee/6/tutorial/doc/gjitv.html
[query-dsl]: http://www.querydsl.com
[boot]: http://projects.spring.io/spring-boot/
[camel]: http://camel.apache.org