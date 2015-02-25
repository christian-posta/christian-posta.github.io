---
layout: page
title: Index
excerpt: "An archive of posts sorted by tag."
search_omit: true
---

<ul class="tag-box inline">
  {% for tag in site.tags %}
    <li><a href="#{{ tag[0] }}">{{ tag[0] }}</a> <span> ({{ tag[1].size }})</span></li>
  {% endfor %}
</ul>


{% for tag in site.tags %}
  <h2 id="{{ tag[0] }}">{{ tag[0] }}</h2>
  <ul class="post-list">
  
  {% for post in tag[1] %}
    {% if post.title != null %}
      <li><a href="{{ site.url }}{{ post.url }}">{{ post.title }}<span class="entry-date"><time datetime="{{ post.date | date_to_xmlschema }}">{{ post.date | date: "%B %d, %Y" }}</time></span></a></li>
    {% endif %}
  {% endfor %}
  </ul>
{% endfor %}


