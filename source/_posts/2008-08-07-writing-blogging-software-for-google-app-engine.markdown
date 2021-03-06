---
layout: post
comments: true
title: "Writing Blogging Software for Google App Engine"
date: 2008-08-07 00:00
categories: [python, App Engine, blogging, programming]
toc: true
---

# Introduction

As noted previously, I recently [rehosted this blog][] on Google's
[App Engine][] (GAE). Writing a small, but functional, blog engine is a
useful exercise in learning a web framework. I wrote blog software to learn
more about [Django][], and I ported it to App Engine to learn more about
App Engine.

In this article, I recreate the steps necessary to build a blogging
engine that runs under GAE.

<!-- more -->

# Acknowledgments

I'm grateful to the following people for reviewing and commenting
on this article before I published it.

* [J.J. Geewax][]
* [Toby DiPasquale][]
* [Mark Chadwick][]
* [Rob Keiser][]

In addition, the following people sent me some valuable insights
and corrections after the article was published:

* [Bill Katz][], for clarifying the querying of list properties.
* [Fernando Correia][], for reminding me that unique keys do have
  associated unique IDs, forcing me to re-read that part of the GAE docs
  again.
* [Alexander Kojevnikov][], for clarifying that the GAE user API works with
  Google accounts, not GMail accounts. (The difference is that a registered
  Google user need not be a GMail user.) Alexander also pointed out that
  `Query.fetch(1)` can be more simply expressed as `Query.get()`.
* [Mark Lissaman][], for pointing out a semantic error in the `picoblog`
  code.

# Similar Articles and Software

* [Experimenting with Google App Engine][], by Bret Taylor. Also describes
  building a blogging engine on GAE.
* [Bloog][], Bill Katz's RESTful GAE blogging engine.
* [cpedialog][], another GAE-based blogging engine.

# Caveats

Before I jump into the tutorial, there are a few caveats:

* The point of this article is to build an App Engine application, to get
  to know some GAE internals. If you just want to host a blog on GAE, and
  you're not interested in understanding the software involved, you might
  consider installing [cpedialog][], a blogging engine that will run on
  GAE.
* I am *certain* there are things about GAE that I could do better. I
  welcome corrections and suggestions; just drop me an email.

## What this Blog Engine Supports

The blog engine outlined in this article is fully functional; this
blog runs on similar software. However, it lacks a few features
some people might want, such as:

* Image uploading. I just haven't put that in yet. When I do, I'll update
  this article. In the meantime, I'm able to live without it by uploading
  the images via GAE's `appcfg.py update` capability.
* Comments. It's easy enough to drop [Disqus][] into your templates, if you
  want.
* Integration into blog aggregators like [Technorati][]. (There's a
  follow-up article on this topic.)

It *does* have the following features, though:

* Tag handling, including support for generating a tag cloud.
* Support for RSS and Atom feeds.
* Displaying articles by month or tag.
* Template-driven theme customization.
* Unpublished drafts.
* Secured administration screens.
* [reStructuredText][] markup (instead of HTML) for the articles.

In short, it's a serviceable blog engine, with simple, straightforward code
you can customize as you see fit.

# The Code

The source code for this blog engine is available on GitHub. See the
Picoblog web page, at [http://software.clapper.org/picoblog/][]

# Get Going with App Engine

## Register and Download

First, of course, you have to register with [GAE][] and download the
development kit. This article assumes you've already done that.

## Create your Application

Next, from your GAE account, create a new application. You'll have to
create a unique identifier for the application. In this article, I use the
application ID "picoblog". You'll want to use something else.

This article is not a tutorial on how to use the App Engine tools and web
site; it's an article about building a blog application. So, I'm not to go
into details about how to create your application on the [GAE][] site.
Google's wizard is easy enough to follow.

## Open the App Engine Docs

You'll want to have the online [App Engine documentation][] available as
you develop your App Engine application. It wouldn't hurt to review the
*Getting Starting* section before jumping in.

## Create your Local Application Directory

Create a directory called `picoblog` in which to do your work. In
that directory, create a file called `app.yaml`:

{% codeblock lang:yaml %}
application: picoblog
version: 1
runtime: python
api_version: 1

handlers:
- url: /static
  static_dir: static

- url: /favicon.ico
  static_files: static/favicon.ico
  upload: static/favicon.ico

- url: /admin
  script: admin.py
  login: admin

- url: /admin/.*
  script: admin.py
  login: admin

- url: /.*
  script: blog.py
{% endcodeblock %}

This file configures your application. You can treat most of the
top of the file as magic. For now, the parts we care about are:

:`application`: The application's registered ID is "picoblog".

:`handlers`: Each `url` entry is a regular expression GAE will match
  against incoming URL requests; on a match, it'll run the
  associated script. In this case, we're saying:

* Any path starting with `/static` is resolved via the built-in static
  file handler. This is where we'll put our images. So go ahead and
  create a `static` directory under `picoblog`.

* Since browsers always look for `/favicon.ico`, and I get tired
  of seeing all the "not found" messages in the logs, there's an
  entry for an icon. It's stored in the `static` directory.

* The administrative screens (for creating and editing blog
  articles) live under '/admin' and are secured: Only a Google
  account with administrative privileges on the project is allowed to
  get to them. They're handled by the `admin.py` script. We'll be
  creating that script in the `picoblog` directory.

* Finally, the published blog itself matches everything else, and
  it's handled by the `blog.py` script. That script, too, will end up
  in the `picoblog` directory.

Once you've created `app.yaml`, you can pretty much forget about it
for awhile.

# Create the Data Model

The next step is to decide what data we're storing in the database. For
this blog engine, there's a single object type in the database, called an
`Article`. It has the following properties (which would be columns in a SQL
database):

* `title`: The 1-line title of the article
* `body`: The body of the article, which is reStructuredText markup.
* `draft`: Whether or not the article is a draft (i.e., not published)
   or not. Drafts are only visible in the administration screen.
* `published_when`: The time the entry was published. In this context,
  "published" means "goes from being a draft to not being a draft". This
  time stamp is initialized to the time the article is created, and it's
  updated when the article is saved as a non-draft. (Toggling the "draft"
  flag multiple times will continue to update this time; you're obviously
  free to change that behavior by hacking the code.)
* `tags`: a list of tags (strings) assigned to the articles. May be empty.
* `id`: a unique ID assigned to the article.

A note about the unique ID: GAE does not provide support for an
automatically incremented integer ID field the same way that Django does.
An item in the datastore *does* have a unique key, accessible via the
`key()` method. Further, that key can be converted to a corresponding
unique name or number (depending on how the key was assigned) by calling
`key().id()`. For instance:

{% codeblock lang:python %}
article = Article(title='Test title')
article.put()
print article.key().id()
{% endcodeblock %}

However, you cannot use this ID in a query. Quoting from the
[Keys and Entity Groups][] section of the GAE documentation:

{% blockquote %}
Key names and IDs cannot be used like property values in queries.
However, you can use a named key, then store the name as a
property. You could do something similar with numeric IDs by
storing the object to assign the ID, getting the ID value using
obj.key().id(), setting the property with the ID, then storing the
object again.
{% endblockquote %}

So, that's what we're going to do.

The data model for our `Article` class looks like this:

{% codeblock lang:python %}
import datetime
import sys

from google.appengine.ext import db

class Article(db.Model):
    title = db.StringProperty(required=True)
    body = db.TextProperty()
    published_when = db.DateTimeProperty(auto_now_add=True)
    tags = db.ListProperty(db.Category)
    id = db.StringProperty()
    draft = db.BooleanProperty(required=True, default=False)
{% endcodeblock %}

If you're familiar with Django, you'll notice that it's similar to
Django's data models, but not exactly the same.

Next, since I like to hide as much of the database API semantics inside the
model, I'm going to add a `get_all()` method that returns all articles, a
`get()` method that returns a single article by ID, and a `published()`
method that returns all non-draft articles. (The `published()` method will
be separated into two methods, so the query itself can be shared. More on
that later.)

{% codeblock lang:python %}
@classmethod
def get_all(cls):
    q = db.Query(Article)
    q.order('-published_when')
    return q.fetch(FETCH_THEM_ALL)
{% endcodeblock %}

{% codeblock lang:python %}
@classmethod
def get(cls, id):
    q = db.Query(Article)
    q.filter('id = ', id)
    return q.get()
{% endcodeblock %}

{% codeblock lang:python %}
@classmethod
def published_query(cls):
    q = db.Query(Article)
    q.filter('draft = ', False)
    return q
{% endcodeblock %}

{% codeblock lang:python %}
@classmethod
def published(cls):
    return Article.published_query().order('-published_when').fetch(FETCH_THEM_ALL)
{% endcodeblock %}

`FETCH_THEM_ALL` is an integer constant with a large value, defined
at the top of the module.

**NOTE**: In the original version of the code, and in the zip files posted
to the [web site][], `FETCH_THEM_ALL` is defined as follows:

{% codeblock lang:python %}
FETCH_THEM_ALL = sys.maxint - 1
{% endcodeblock %}

On a 64-bit local machine, `sys.maxint` will evaluate to a 64-bit number.
But GAE is a 32-bit environment, so the code may fail on certain machines.
The code in the [GitHub repository][] has been corrected.

For a more complete understanding of the GAE query interface, see the
[documentation for the Query class][] and the [GAE Query Filter][]
documentation.

Finally, let's add a `save()` method that does two important things:

* Copies the GAE-assigned unique ID into our `id` field, so we can use it
  in queries.
* Updates the time stamp if the article being saved is going from draft to
  published status.

{% codeblock lang:python %}
def save(self):
    previous_version = Article.get(self.id)
    try:
        draft = previous_version.draft
    except AttributeError:
        draft = False

    if draft and (not self.draft):
        # Going from draft to published. Update the timestamp.
        self.published_when = datetime.datetime.now()

    try:
        obj_id = self.key().id()
        resave = False
    except db.NotSavedError:
        # No key, hence no ID yet. This one hasn't been saved.
        # We'll save it once without the ID field; this first
        # save will cause GAE to assign it a key. Then, we can
        # extract the ID, put it in our ID field, and resave
        # the object.
        resave = True

    self.put()
    if resave:
        self.id = self.key().id()
        self.put()
{% endcodeblock %}

Okay, that's the model. (See the source code for the complete file.)

# Create the Administration Screens

Now let's create the administration screens, so we can edit and
create articles. We'll create two screens.

The main administration screen contains three things:

* A button to create a new article. Pressing this button creates
  an empty article and launches the Edit Article screen to edit it.
* A button to go back to blog itself.
* A list of the existing articles. The articles will be sorted in
  reverse chronological order, and each article's date and title will
  be displayed. The article's date and title will also be a hyperlink
  to the edit screen for the article. Further, drafts will be shown
  in red, to distinguish them from published articles.

The Edit Article screen contains

* A text box for the the title
* A text area for the body of the article, which is assumed to be
  reStructuredText
* A text box for the list of tags (comma-separated)
* A check box to indicate whether or not the item is a draft

To create these screens requires five files:

* `defs.py` will hold some constants that we share between all the blog
  scripts.
* `request.py` will hold a base class request handler, which is basically a
  place to hang logic that we need in every script.
* `admin.py` contains the Python code for the admin screens--the equivalent
  of a Django `views.py` file for the admin screns.
* `admin-main.html` is the template for the main administration screen.
* `admin-edit.html` is the template for the Edit Article screen.

To keep things organized, we'll store the templates in a `templates`
subdirectory.

## The Templates

Let's start with the templates.

GAE's default template engine is Django's template engine. If you don't
know Django's template language, read the first few sections of the
[Django template language][] document. Describing Django templates is
beyond the scope of this article.

### Main Administration Screen Template

You can see the
[full template for the main administration screen here][].

It consists of a link to the style sheet, some Javascript, some
standard HTML layout, and this block of template logic:

{% codeblock Admin Template Logic lang:html %}
{% raw %}
<ul>
{% for article in articles %}
  {% if article.draft %}
  <li class="admin-draft">
  {% else %}
  <li class="admin-published">
  {% endif %}
  {{ article.published_when|date:"j F, Y" }}
  <a href="/admin/article/edit/?id={{ article.id }}">{{ article.title \}}</a>
{% endfor %}
</ul>
{% endraw %}
{% endcodeblock %}

This template code assumes that the variables passed to the template will
include a Python list called `articles`, each element of which is an
`Article` object. We'll see how that's populated in the next section.

The style sheet link looks like this:

{% codeblock lang:html %}
{% raw %}
<link href="/static/style.css" rel="stylesheet" type="text/css"/>
{% endraw %}
{% endcodeblock %}

Rather than use a template `{% include "style.css" %}` directive to
pull the style sheet file inline at rendering time, we're telling
the browser to go get it. We'll be using the same style sheet for
all pages; using an external style sheet allows the browser to
cache it.

### The Style Sheet

To see the style sheet, [follow this link][]. The style sheet is stored in
the `static` subdirectory, where it'll be served by the GAE static file
handler.

### The Edit Screen Template

The
[template for the edit screen is available here][].
The edit screen is slightly more complicated, since it has some
Javascript to handle the various buttons. But overall, it's still
pretty simple as web screens go.

## The View Code

The view code for the administration screens is in `admin.py`. It,
too, is relatively simple. But first, let's look at the two other
files we're using to consolidate common logic.

### `defs.py`

`defs.py` just contains some common constants:

{% codeblock lang:python %}
BLOG_NAME = 'PicoBlog'
BLOG_OWNER = 'Joe Example'

TEMPLATE_SUBDIR = 'templates'

TAG_URL_PATH = 'tag'
DATE_URL_PATH = 'date'
ARTICLE_URL_PATH = 'id'
MEDIA_URL_PATH = 'static'
ATOM_URL_PATH = 'atom'
RSS2_URL_PATH = 'rss2'
ARCHIVE_URL_PATH = 'archive'

MAX_ARTICLES_PER_PAGE = 5
TOTAL_RECENT = 10
{% endcodeblock %}

We'll see how they're used as we get further into this tutorial.

### `request.py`

`request.py` contains our base request handler class:

{% codeblock lang:python %}
import os

from google.appengine.ext import webapp
from google.appengine.ext.webapp import template

import defs

class BlogRequestHandler(webapp.RequestHandler):
    """
    Base class for all request handlers in this application. This class
    serves primarily to isolate common logic.
    """

    def get_template(self, template_name):
        """
        Return the full path of the template.

        :Parameters:
            template_name : str
                Simple name of the template

        :rtype: str
        :return: the full path to the template. Does *not* ensure that the
                 template exists.
        """
        return os.path.join(os.path.dirname(__file__),
                            defs.TEMPLATE_SUBDIR,
                            template_name)

    def render_template(self, template_name, template_vars):
        """
        Render a template and write the output to ``self.response.out``.

        :Parameters:
            template_name : str
                Simple name of the template

            template_vars : dict
                Dictionary of variables to make available to the template.
                Can be empty.
        """
        template_path = self.get_template(template_name)
        template.render(template_path, template_vars)
{% endcodeblock %}

As you can see, it just contains some methods to make rendering templates a
little simpler.

### `admin.py`

*Now* we're ready to look at the administration view code. First,
we have some imports:

{% codeblock lang:python %}
import cgi

from google.appengine.api import users
from google.appengine.ext import webapp
from google.appengine.ext.webapp import util

from models import *
import request
{% endcodeblock %}

These are followed by the request handler classes:

{% codeblock lang:python %}
class ShowArticlesHandler(request.BlogRequestHandler):
    def get(self):
        articles = Article.get_all()
        template_vars = {'articles' : articles}
        self.response.out.write(self.render_template('admin-main.html', 
                                                     template_vars))

class NewArticleHandler(request.BlogRequestHandler):
    def get(self):
        article = Article(title='New article',
                          body='Content goes here',
                          draft=True)
        template_vars = {'article' : article}
        self.response.out.write(self.render_template('admin-edit.html',
                                                     template_vars))

class SaveArticleHandler(request.BlogRequestHandler):
    def post(self):
        title = cgi.escape(self.request.get('title'))
        body = cgi.escape(self.request.get('content'))
        id = int(cgi.escape(self.request.get('id')))
        tags = cgi.escape(self.request.get('tags'))
        published_when = cgi.escape(self.request.get('published_when'))
        draft = cgi.escape(self.request.get('draft'))
        if tags:
            tags = [t.strip() for t in tags.split(',')]
        else:
            tags = []
        tags = Article.convert_string_tags(tags)

        if not draft:
            draft = False
        else:
            draft = (draft.lower() == 'on')

        article = Article.get(id)
        if article:
            # It's an edit of an existing item.
            article.title = title
            article.body = body
            article.tags = tags

            article.draft = draft
        else:
            # It's new.
            article = Article(title=title,
                              body=body,
                              tags=tags,
                              id=id,
                              draft=draft)

        article.save()

        edit_again = cgi.escape(self.request.get('edit_again'))
        edit_again = edit_again and (edit_again.lower() == 'true')

        if edit_again:
            self.redirect('/admin/article/edit/?id=%s' % id)
        else:
            self.redirect('/admin/')

class EditArticleHandler(request.BlogRequestHandler):
    def get(self):
        id = int(self.request.get('id'))
        article = Article.get(id)
        if not article:
            raise ValueError, 'Article with ID %d does not exist.' % id

        article.tag_string = ', '.join(article.tags)
        template_vars = {'article'  : article}
        self.response.out.write(self.render_template('admin-edit.html',
                                template_vars))

class DeleteArticleHandler(request.BlogRequestHandler):
    def get(self):
        id = int(self.request.get('id'))
        article = Article.get(id)
        if article:
            article.delete()

        self.redirect('/admin/')
{% endcodeblock %}

The file ends with some initialization logic and the main program:

{% codeblock lang:python %}
application = webapp.WSGIApplication(
    [('/admin/?', ShowArticlesHandler),
     ('/admin/article/new/?', NewArticleHandler),
     ('/admin/article/delete/?', DeleteArticleHandler),
     ('/admin/article/save/?', SaveArticleHandler),
     ('/admin/article/edit/?', EditArticleHandler),
     ],

    debug=True)

def main():
    util.run_wsgi_app(application)

if __name__ == "__main__":
    main()
{% endcodeblock %}

Let's break this down a bit. First, the initialization logic at the bottom
(that is, the creation of the `webapp.WSGIApplication` object) defines what
classes (*handlers*) will handle which URLs within the `/admin/` URL space.
Recall that the [app.yaml][] file points all `/admin` URLs to this file.
The `application` variable further breaks those URLs down, so that certain
URLs map to certain handlers. The list passed to the `WSGIApplication`
constructor contains tuples; each tuple defines a URL mapping.

* The first element of the tuple is a regular expression. Note that the
  regular expressions we're using end with `/?`, allowing the trailing
  slash to be omitted in the URL.
* The name of the class that will handle requests to URLs that match the
  regular expression.

Next, let's look at some of the handlers. There are basically two
kinds of handlers here:

* Handlers that just display a page (i.e., retrieve data from the
  database and stuff it into a template).
* Handlers that process form submissions.

#### Handlers that Only Display a Page

`ShowArticlesHandler`, `NewArticlesHandler` and `EditArticlesHandler` are
example of handlers that simply display a page. Here's the
`ShowArticlesHandler` class again:

{% codeblock lang:python %}
class ShowArticlesHandler(request.BlogRequestHandler):
    def get(self):
        articles = Article.get_all()
        template_vars = {'articles' : articles}
        self.render_template('admin-main.html', template_vars)
{% endcodeblock %}

First, because it defines only the `get()` method, it supports just the
HTTP GET semantics. (POST is not supported for the associated URL.)

The actual handler is simple: It retrieves all articles, whether draft or
published, puts the resulting list in a dictionary, and uses that
dictionary to render the template. That's it; that's the *entire* handler.
The `NewArticleHandler` is similarly simple.

The `EditArticleHandler` is a little more complicated, only because it has
to handle a few additional things:

{% codeblock lang:python %}
class EditArticleHandler(request.BlogRequestHandler):
    def get(self):
        id = int(self.request.get('id'))
        article = Article.get(id)
        if not article:
            raise ValueError, 'Article with ID %d does not exist.' % id

        article.tag_string = ', '.join(article.tags)
        template_vars = {'article'  : article}
        self.render_template('admin-edit.html', template_vars)
{% endcodeblock %}

First, it determines whether the article being edited is in the database or
not; if not, it throws an exception, because it should never be invoked on
a non-existent article. (If it is, we have a bug.)

Next, it creates a comma-separated string from the list of tags, so the
template can simply stuff that string into the tags edit box.

#### Handlers that Process Forms

The most complicated handler is the `SaveArticleHandler` class.
Let's look at that one again:

{% codeblock lang:python %}
class SaveArticleHandler(request.BlogRequestHandler):
    def post(self):
        title = cgi.escape(self.request.get('title'))
        body = cgi.escape(self.request.get('content'))
        id = int(cgi.escape(self.request.get('id')))
        tags = cgi.escape(self.request.get('tags'))
        timestamp = cgi.escape(self.request.get('timestamp'))
        draft = cgi.escape(self.request.get('draft'))
        if tags:
            tags = [t.strip() for t in tags.split(',')]
        else:
            tags = []
        tags = Article.convert_string_tags(tags)

        if not draft:
            draft = False
        else:
            draft = (draft.lower() == 'on')

        article = Article.get(id)
        if article:
            # It's an edit of an existing item.
            article.title = title
            article.body = body
            article.tags = tags
            article.draft = draft
        else:
            # It's new.
            article = Article(title=title,
                              body=body,
                              tags=tags,
                              id=id,
                              draft=draft)

        article.save()

        edit_again = cgi.escape(self.request.get('edit_again'))
        edit_again = edit_again and (edit_again.lower() == 'true')
        if edit_again:
            self.redirect('/admin/article/edit/?id=%s' % id)
        else:
            self.redirect('/admin/')
{% endcodeblock %}

That one's a little longer, but what it does is simple enough:

* First, it retrieves all the form variables.
* Next, if there are any tags in the form, it splits the tag string to make
  it into a list.
* The tags are actually stored as GAE `db.Category` objects, not strings,
  so the code calls a special `Article` class method to convert the strings
  from the form into `Category` objects. (Consult the code for that
  conversion method; it's trivial, and it's not included here.)
* It processes the Draft checkbox.
* It attempts to load the referenced article. If the article exists, the
  handler updates its contents. Otherwise, it creates a new Article object
  with the specified ID.
* Then, it saves the article.
* If the `edit_again` request variable is set, then the handler redisplays
  the edit screen; otherwise, it displays the main administration screen
  again.

That's it. We've finished our admin screens. Let's take a look at them. To
do that, fire up a terminal window, change your working directory to the
`picoblog` directory, and run the following command. (You must have put the
root of the unpacked GAE toolkit in your path.)

    dev_appserver.py .

You'll see output something like this:

    INFO     2008-08-06 02:51:26,336 appcfg.py] Server: appengine.google.com
    INFO     2008-08-06 02:51:26,342 appcfg.py] Checking for updates to the SDK.
    INFO     2008-08-06 02:51:26,444 appcfg.py] The SDK is up to date.
    INFO     2008-08-06 02:51:26,534 dev_appserver_main.py] Running application
    pico on port 8080: http://localhost:8080

You can now surf to `http://localhost:8080/admin/` using your browser.

Here's a screen shot of the main screen, showing several articles. The
top-most article is a draft; the rest are published.

{% img /images/2008-08-07-writing-blogging-software-for-google-app-engine/admin-main-small.png Main admin screen %}

The [full-size main page image is here](/images/2008-08-07-writing-blogging-software-for-google-app-engine/admin-main.png)

And here's the edit screen for the draft article:

{% img /images/2008-08-07-writing-blogging-software-for-google-app-engine/admin-edit-small.png Edit Screen %}

The [full-size edit page image is here](/images/2008-08-07-writing-blogging-software-for-google-app-engine/admin-edit.png).

From a stylistic viewpoint, these screens are really simple. However,
making them look fancier and slicker is simply a matter of fiddling with
the templates and the stylesheet. The Python code doesn't change.

# The Markup Language

Rather than force the blogger (i.e., you or me) to enter HTML, I've chosen
to use the [reStructuredText][] (RST) markup language. Of course, this
means the blog has to translate the RST text into HTML when someone wants
to view the blog. We can either do that conversion when we save the
article, or convert on the fly when someone visits the blog.

Converting the markup when we save the article is more efficient,
but it means we have to store the generated HTML and reconvert all
previously saved articles whenever we change the templates or the
style sheet. It's simpler to convert on the fly. If this strategy
ends up causing a performance problem, we can always go back later
and add page caching.

## Docutils

To support RST, the first thing we have to do is make the [Docutils][]
package available to our running code. The easiest way to do that is to
visit the [Docutils][] web site, download the source code, unpack it, and
move the `docutils` subdirectory (and all its contents) into our blog
directory. When we later upload the application to GAE, the Docutils code
will get uploaded, too.

Docutils also looks for a `roman.py` file, which isn't present in
the GAE Python environment. There's one in the Google App Engine
source directory (which you downloaded); copy the `roman.py` file
from there into the top directory of the blog.

## Translation code

The code that actually translates RST to HTML is rather simple:

{% codeblock lang:python %}
import os

from docutils.core import publish_parts

def rst2html(s):
    settings = {'config' : None}

    # Necessary, because otherwise docutils attempts to read a config file
    # via the codecs module, which doesn't work with AppEngine.
    os.environ['DOCUTILSCONFIG'] = ""
    parts = publish_parts(source=s,
                          writer_name='html4css1',
                          settings_overrides=settings)
    return parts['fragment']
{% endcodeblock %}

The only wrinkle is the setting of the `DOCUTILSCONFIG` environment
variable. I determined empirically that if you don't set that variable to
an empty string, the Docutils package attempts to read a startup file via
the `codecs` module, and the way it calls the `codecs.open()` method
conflicts with how that method is defined in the GAE Python library. (GAE
has replaced Python's file handling routines with routines of its own, and
they're not always 100% compatible.)

Store this code in file `rst.py`. We'll then import it in our display code.

# Create the Display Screens

Now we're ready to create the display screens. There are six views
to support:

* **Main** shows the top *n* articles (where *n* is the value of
  `MAX_ARTICLES_PER_PAGE` in the `defs.py` file). This screen is the main
  blog screen--the one a visitor sees first.
* **Show One Article** shows a single article. It's used when someone
  clicks on the link for a single article.
* **Show Articles by Tag** shows all articles with a specific tag.
* **Show Articles by Month** shows all articles in a specified month.
* **Show Archive** lists the titles and dates of all articles in the blog.
* **Not Found** is a simple screen to display when an article or page isn't
  found.

We'll also add some query methods to the `Article` class as we go along.

## Base Template

The simplest way to build these screens is to use Django template
inheritance, which has the additional benefit of ensuring a consistent
look. Most of the HTML goes into a [base template][]. That template defines
the basic look and feel of the display pages, with various template
substitutions like `{{blog_name}}` and `{{blog_owner}}`.

However, the base template also contains template code like the
following:

{% codeblock %}
{% raw %}
<div id="articles_container">
{% for article in articles %}

  {% block main %}
  {% endblock %}
{% endfor %}
</div>
{% endraw %}
{% endcodeblock %}

and this:

{% codeblock %}
{% raw %}
<div id="right-margin">
  {% block recent_list %}
  {% endblock %}
  {% block date_list %}
  {% endblock %}
</div>
{% endraw %}
{% endcodeblock %}

The blocks can be filled in by other templates that inherit from
this one.

## `blog.py`

The handlers go in `blog.py`, which is similar to `admin.py`. There's an
initialization section at the bottom that sets up the URL-to-handler
mappings. Let look at that first:

{% codeblock lang:python %}
application = webapp.WSGIApplication([('/', FrontPageHandler),
                                      ('/tag/([^/]+)/*$', ArticlesByTagHandler),
                                      ('/date/(\d\d\d\d)-(\d\d)/?$', ArticlesForMonthHandler),
                                      ('/id/(\d+)/?$', SingleArticleHandler),
                                      ('/archive/?$', ArchivePageHandler),
                                      ('/rss2/?$', RSSFeedHandler),
                                      ('/atom/?$', AtomFeedHandler),
                                      ('/.*$', NotFoundPageHandler),
                                     ],

                                     debug=True)
{% endcodeblock %}

## `AbstractPageHandler`

At the top of the file, there's a base class that consolidates a lot of the
common logic. The most important method it contains is `render_articles()`:

{% codeblock lang:python %}
class AbstractPageHandler(request.BlogRequestHandler):

    def render_articles(self,
                        articles,
                        request,
                        recent,
                        template_name='show-articles.html'):
        url_prefix = 'http://' + request.environ['SERVER_NAME']
        port = request.environ['SERVER_PORT']
        if port:
            url_prefix += ':%s' % port

        self.augment_articles(articles, url_prefix)
        self.augment_articles(recent, url_prefix)

        last_updated = datetime.datetime.now()
        if articles:
            last_updated = articles[0].published_when

        self.adjust_timestamps(articles)
        last_updated = self.adjust_timestamp(last_updated)

        blog_url = url_prefix
        tag_path = '/' + defs.TAG_URL_PATH
        tag_url = url_prefix + tag_path
        date_path = '/' + defs.DATE_URL_PATH
        date_url = url_prefix + date_path
        media_path = '/' + defs.MEDIA_URL_PATH
        media_url = url_prefix + media_path

        template_variables = {'blog_name'    : defs.BLOG_NAME,
                              'blog_owner'   : defs.BLOG_OWNER,
                              'articles'     : articles,
                              'tag_list'     : self.get_tag_counts(),
                              'date_list'    : self.get_month_counts(),
                              'version'      : '0.3',
                              'last_updated' : last_updated,
                              'blog_path'    : '/',
                              'blog_url'     : blog_url,
                              'archive_path' : '/' + defs.ARCHIVE_URL_PATH,
                              'tag_path'     : tag_path,
                              'tag_url'      : tag_url,
                              'date_path'    : date_path,
                              'date_url'     : date_url,
                              'atom_path'    : '/' + defs.ATOM_URL_PATH,
                              'rss2_path'    : '/' + defs.RSS2_URL_PATH,
                              'media_path'   : media_path,
                              'media_url'    : media_url,
                              'recent'       : recent}

        return self.render_template(template_name, template_variables)
{% endcodeblock %}

This method takes:

* a list of `Article` objects to be displayed
* the original incoming HTTP request
* a list of recent articles to display (which can be empty)
* the template name to use, which defaults to the `show-articles.html` template

`render_articles()` then puts together the list of template variables,
renders the specified template, and returns the result.

All the display handlers will use this method, which is why it resides in
the base class.

Another method we should examine is `augment_articles()`, also in the
`AbstractPageHandler` class:

{% codeblock lang:python %}
def augment_articles(self, articles, url_prefix, html=True):
    for article in articles:
        if html:
            try:
                article.html = rst2html(article.body)
            except AttributeError:
                article.html = ''
        article.path = '/' + defs.ARTICLE_URL_PATH + '/%s' % article.id
        article.url = url_prefix + article.path
{% endcodeblock %}

This method renders the HTML for each article to be displayed (if
requested), and computes the article's path and URL.

The base class also contains a few other methods used by
`render_template()`:

* `get_tag_counts()` assembles the list of unique tags, associating an
  article count with each one. It also determines which CSS class to
  associate with each tag, based on the tag's relative frequency, for use
  when rendering the tag cloud; this information is returned in a list of
  `TagCount` objects. (`TagCount` is defined in `blog.py`. It's not shown
  here.)
* `get_month_counts()` returns a list of `DateCount` objects that the
  number of articles in each unique month/year.
* `get_recent()` gets the most recent articles, making sure the list
  doesn't exceed the maximum specified in `defs.TOTAL_RECENT`.

(See the complete file in the source code for details.)

## Not Found Page

Next, let's get the *Not Found* page out of the way. The template
is very simple:

{% codeblock %}
{% raw %}
{% extends "base.html" %}

{% block main %}
  <p class="article_title">Not Found</p>
  <p>Sorry, but there's no such page here.</p>
{% endblock %}
{% endraw %}
{% endcodeblock %}

It extends the base template and fills in the `main` block with a
simple static message. We'll use this template in a couple places.

The `NotFoundHandler` class is also simple:

{% codeblock lang:python %}
class NotFoundPageHandler(AbstractPageHandler):
    def get(self):
        self.response.out.write(self.render_articles([],
                                                     self.request,
                                                     [],
                                                     'not-found.html'))
{% endcodeblock %}

Recall that this handler is the last, catch-all handler in the list of URLs
in `blog.py`, so it's automatically invoked if the incoming request doesn't
match any of the preceding URLs.

That's all we have to do to install a custom "not found" handler.

## Main Page

The main screen requires a template and a handler. With the base template
and the `AbstractPageHandler` class in place, both are pretty simple.
Here's the template, which resides in `show-articles.html`:

{% codeblock lang:django %}
{% raw %}
{% extends "base.html" %}

{% block main %}
  {% for article in articles %}
    {% include "article.html" %}
    </td></tr></table>
  {% endfor %}
{% endblock %}

{% block recent_list %}
  {% if recent %}
    <b>Recent:</b>
    <ul>
    {% for article in recent %}
      <li><a href="{{ article.path }}">{{ article.title }}</a>
    {% endfor %}
    </ul>
  {% endif %}
{% endblock %}

{% block date_list %}
  {% if date_list %}
    <b>By month:</b>
    <ul>
    {% for date_count in date_list %}
      <li><a href="{{ date_path }}/{{ date_count.date|date:"Y-m" }}/">
          {{ date_count.date|date:"F, Y" }}</a> ({{ date_count.count }})
    {% endfor %}
    </ul>
  {% endif %}
{% endblock %}

{% block tag_list %}
  {% if tag_list %}
    <div id="tag-cloud">
    {% for tag_count in tag_list %}
      <a class="{{ tag_count.css_class }}"
         href="{{ tag_path }}/{{ tag_count.tag }}/">
         {{ tag_count.tag }}({{ tag_count.count }})</a>
         {% if not forloop.last %},{% endif %}
    {% endfor %}
    </div>
  {% endif %}
{% endblock %}
{% endraw}
{% endcodeblock %}

The template extends the base template, and then just fills in the
HTML for each block that's defined in the base template. Note, in
particular, this block:

{% codeblock %}
{% raw %}
{% for article in articles %}
  {% include "article.html" %}
{% endfor %}
{% endraw %}
{% endcodeblock %}

The actual template that displays an article resides in yet another
file, so it can be re-used in different templates.
`show-articles.html` includes it, repeatedly, in a loop that
traverses the list of articles to be displayed.

The `article.html` template looks like this:

{% codeblock article.html %}
{% raw %}
<table width="100%" border="0" cellspacing="0" cellpadding="0">
  <tr class="article_title_line">
    <td class="article_title">{{ article.title }}</td>
    <td class="timestamp">
       {{ article.published_when|date:"j F, Y \a\t g:i A" }}
    </td>
  </tr>
  <tr>
    {% if article.draft %}
    <td colspan="2" class="article-body-draft">
    {% else %}
    <td colspan="2" class="article-body">
    {% endif %}
    {{ article.html }}
    </td>
  </tr>
  <tr>
    <td colspan="2" class="article-footer">
      <a href="{{ article.path }}" class="reference">Permalink</a>|
      Tags: {{ article.tags|join:", " }}</td>
  </tr>
</table>
{% endraw %}
{% endcodeblock %}

It's relatively easy to understand: It assumes the existence of a
variable called `article` that contains the article to be
displayed.

The handler for the main page is even simpler:

{% codeblock lang:python %}
class FrontPageHandler(AbstractPageHandler):
    def get(self):
        articles = Article.published()
        if len(articles) > defs.MAX_ARTICLES_PER_PAGE:
            articles = articles[:defs.MAX_ARTICLES_PER_PAGE]

        self.response.out.write(self.render_articles(articles,
                                                     self.request,
                                                     self.get_recent()))
{% endcodeblock %}

It gets the list of published articles, trims it down to the
maximum number of articles on the main page, renders the articles
to HTML, and dumps the result to the App Engine HTTP response
object.

If you did not leave the `dev_appserver` running, bring it up
again. Then, connect to `http://localhost:8080/`, and check out
your main page. It should look something like this:

{% img /images/2008-08-07-writing-blogging-software-for-google-app-engine/main-small.png 'Main screen' %}

The [full main page image is here](/images/2008-08-07-writing-blogging-software-for-google-app-engine/main.png).

## Show One Article

This screen shows a single article. It's invoked when a reader
selects a single post (e.g., `http://www.example.org/blog/id/5`).

It re-uses the same `show-articles.html` template, but with just
one article in the list. The handler looks like this:

{% codeblock lang:python %}
class SingleArticleHandler(AbstractPageHandler):

    def get(self, id):
        article = Article.get(int(id))
        if article:
            template = 'show-articles.html'
            articles = [article]
            more = None
        else:
            template = 'not-found.html'
            articles = []

        self.response.out.write(self.render_articles(articles=articles,
                                                     request=self.request,
                                                     recent=self.get_recent(),
                                                     template_name=template))
{% endcodeblock %}

It attempts to retrieve the article with the specified ID. If the
article exists in the database, then the code puts it in a
single-element list and tells `render_articles()` to use the
`show_articles.html` to display it.

If the article does not exist, the code uses the `not-found.html`
template we defined earlier to display the generic "not found"
screen.

Note that this version of the `get()` method accepts an `id`
parameter. Where does that come from? Recall the configuration for
this handler in the `WSGIApplication` object at the bottom of the
script:

{% codeblock lang:python %}
application = webapp.WSGIApplication(
    [ ...

     ('/id/(\d+)/?$', SingleArticleHandler),

     ...
     ],
{% endcodeblock %}

Note that the regular expression, `'/id/(\d+)/?$` contains a group,
`(\d+)`. Like Django, GAE maps each group into a parameter to the `get()`
or `post()` method. In this case, the string that matches the regular
expression group (the article's numeric ID, in this case) is passed as the
first parameter to the `get()` method.

## Show Articles By Tag

The `ArticlesByTagHandler` class again re-uses the `show-articles.html`
template:

{% codeblock lang:python %}
class ArticlesByTagHandler(AbstractPageHandler):
    def get(self, tag):
        articles = Article.all_for_tag(tag)
        self.response.out.write(self.render_articles(articles,
                                                     self.request,
                                                     self.get_recent()))
{% endcodeblock %}

Note, however, that it's calling a class method called
`all_for_tag()` in the `Article` class. We have to extend `Article`
to support this query method. That method turns out to be trivial:

{% codeblock lang:python %}
@classmethod
def all_for_tag(cls, tag):
    return Article.published_query()\
                  .filter('tags = ', tag)\
                  .order('-published_when')\
                  .fetch(FETCH_THEM_ALL)
{% endcodeblock %}

My original version of this method loaded all published articles and
manually searched through their tags. However, in an
[email to the Google App Engine mailing list, Bill Katz][] pointed me to
[something I missed in the GAE docs][]:

> In a query, comparing a list property to a value performs the test
> against the list members: `list_property = value` tests if the value
> appears anywhere in the list.

This is convenient and more efficient than my original solution.

## Show Articles By Month

By now, you should be getting the hang of this.

Next, we have to write a handler that'll produce a page of posts for a
given month. As with the tag handler, the month handler is trivial:

{% codeblock lang:python %}
class ArticlesForMonthHandler(AbstractPageHandler):
    def get(self, year, month):
        articles = Article.all_for_month(int(year), int(month))
        self.response.out.write(self.render_articles(articles,
                                                     self.request,
                                                     self.get_recent()))
{% endcodeblock %}

Again, though, it calls an `Article` class method we have yet to write:

{% codeblock lang:python %}
@classmethod
def all_for_month(cls, year, month):
    start_date = datetime.date(year, month, 1)
    if start_date.month == 12:
        next_year = start_date.year + 1
        next_month = 1
    else:
        next_year = start_date.year
        next_month = start_date.month + 1
    end_date = datetime.date(next_year, next_month, 1)
    query = Article.published_query()\\
                   .filter('published_when >=', start_date)\\
                   .filter('published_when <', end_date)\\
                   .order('-published_when')
    return query.fetch(FETCH_THEM_ALL)
{% endcodeblock %}

This method chains query filters to the query returned by
`Article.published_query()`. The filters ensure that the returned articles
are the ones published within the specified year and month.

## Show Archive

This page shows the titles of all published articles, in reverse
chronological order. I chose to make this page even simpler than the other
pages: It lacks the tag cloud, recent posts, and posts-by-month sections in
the margin. The template is trivial:

{% codeblock lang:django %}
{% raw %}
{% extends "base.html" %}

{% block main %}
  <span class="heading">Complete Archive:</span>
  {% if articles %}
    <ul>
    {% for article in articles %}
      <li><a href="{{ article.path }}">{{ article.title }}</a>
          ({{ article.timestamp|date:"j F, Y" }})
    {% endfor %}
    </ul>
  {% else %}
  <p>This blog is empty. (Someone want to fix that?)
  {% endif %}
{% endblock %}
{% endraw %}
{% endcodeblock %}

And the handler is, once again, trivial:

{% codeblock lang:python %}
class ArchivePageHandler(AbstractPageHandler):
    def get(self):
        articles = Article.published()
        self.response.out.write(self.render_articles(articles,
                                                     self.request,
                                                     [],
                                                     'archive.html'))
{% endcodeblock %}

Note that `ArchivePageHandler` passes an empty list for the "recent" posts
(since it won't be used) and the archive template.

Here's what the archive page looks like with our two articles in
the archive:

{% img /images/2008-08-07-writing-blogging-software-for-google-app-engine/archive-small.png 'Archive screen' %}

The [full archive page image is here](/images/2008-08-07-writing-blogging-software-for-google-app-engine/archive.png).

## RSS Feed

Any decent blog supplies an RSS feed, so we should do that, too. Of
course, that's simply a matter of writing a template and a small
handler. By now, the handler should look pretty familiar:

{% codeblock lang:python %}
class RSSFeedHandler(AbstractPageHandler):
    def get(self):
        articles = Article.published()
        self.response.headers['Content-Type'] = 'text/xml'
        self.response.out.write(self.render_articles(articles,
                                                     self.request,
                                                     [],
                                                     'rss2.xml'))
{% endcodeblock %}

The template is simple, too:

{% codeblock lang:xml %}
{% raw %}
<?xml version="1.0" encoding="utf-8" ?>
<rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>{{ blog_name }}</title>
    <link>{{ blog_url }}</link>
    <description>{{ blog_name }}</description>
    <pubDate>{{ last_updated|date:"D, d M Y H:i:s T" }}</pubDate>
    {% for article in articles %}
    <item>
      <title>{{ article.title }}</title>
      <link>{{ article.url }}</link>
      <guid>{{ article.url }}</guid>
      <pubDate>{{ article.timestamp|date:"D, d M Y H:i:s T" }}</pubDate>
      <description>
        {{ article.html|escape }}
      </description>
      <author>{{ blog_author }}</author>
    </item>
    {% endfor %}
  </channel>
</rss>
{% endraw %}
{% endcodeblock %}

# Deploy the Application

Test the application using `dev_appserver`; when you think it's
ready, it's time to deploy it. From within the blog's top-level
source directory, run this command:

    appcfg.py update .

That'll upload your application to your Google App Engine account.
If the application name is `picoblog`, then your live application
will appear at `http://picoblog.appspot.com/`.

# Handling Static Files such as Images

Of course, a blog should be able to display images. Since our new
blog software doesn't support image upload, how can we use images?
The answer is simple, if slightly clunky: Put any images you want
to use in your `picoblog/static` directory. Then, use `appcfg.py`
to update the live application; `appcfg.py` will copy those images
up to the Google App Engine server, where you can use them.

For instance, assume you have a picture call `foo.png` that you
want to use in a blog article. Here's how you might deploy it:

{% codeblock lang:bash %}
$ cd picoblog
$ cp ~/foo.png static
$ appcfg.py update .
{% endcodeblock %}

Then, you can use the reStructuredText `.. image` directive to pull
it into an article:

    .. image:: /static/foo.pn
       :width: 180
       :height: 150

# Previewing a Draft

There's one last feature to add: The ability to preview a draft
article without publishing it.

With this software in place, you can already do that by using a
separate browser window or frame. For instance, suppose you're
editing a new article, and its ID happens to be 53. In another
window, you can surf to that ID directly, using the URL
`http://picoblog.appspot.com/id/53/`.

But it might also be nice to preview the article in the same window
where you're doing your editing. That turns out to be trivial to
implement: Merely go back to \`The Edit Screen Template\`\_, and
add these lines right after the end of the form:

{% codeblock lang:html %}
{% raw %}
<h1 class="admin-page-title">Preview:</h1>
<div style="border-top: 1px solid black">
<iframe src="/id/{{ article.id }}" width="97%" scrolling="auto" height="750" frameborder="0">
</iframe>
{% endraw %}
{% endcodeblock %}

Now, you'll always have a preview frame underneath the edit
controls.

# Enhancements

Now that you have the basic blog in place, you can start to add
other enhancements, such as:

* Support for [Pygments][] syntax coloring.
* Support for [Google Analytics][], which is useful for analyzing logs and
  traffic.
* Image uploading.
* A more individual theme.
* etc.

# In Closing

In this (long) tutorial, we built a simple blog using Python and Google's
App Engine. The code represented in this article is very similar to the
code that runs this very blog; it's certainly effective, even if it lacks
certain bells and whistles right now. With any luck, you now have a better
understanding of what it means to build an application on App Engine.

# Feedback

I welcome feedback. Feel free to submit a comment, below, or drop me an
email with comments or corrections. I'll update this article with any good
stuff I receive.

# Related Software

**_Update: 28 November, 2010_**

A friend notes that [David Jonathan Nelson][] has created an
[App Engine Blog][AEB] (AEB) project by forking *picoblog*. AEB "seeks to
provide a near WordPress quality blog engine that runs on Google App
Engine."

[David Jonathan Nelson]: http://code.google.com/u/david.jonathan.nelson/
[AEB]: http://code.google.com/p/appengineblogsoftware/

# Related Brizzled Articles

* [Adding Page caching to a GAE application][]
* [Making XML-RPC calls from a Google App Engine application][]

# Additional Reading

* [Experimenting with Google App Engine][], by Bret Taylor.
* [Building Scalable Web Applications with Google App Engine][]
  (presentation), by Google's Brett Slatkin.
* [Google App Engine documentation][]

[rehosted this blog]: /id/76/
[App Engine]: http://appengine.google.com/
[Django]: http://www.djangoproject.com/
[J.J. Geewax]: http://blog.geewax.org/
[Toby DiPasquale]: http://blog.cbcg.net/
[Mark Chadwick]: http://hipstersinc.com/
[Rob Keiser]: http://www.row-5.com/
[Bill Katz]: http://ww.billkatz.com/
[Fernando Correia]: http://fernandoacorreia.wordpress.com/
[Alexander Kojevnikov]: http://versia.com/
[Mark Lissaman]: mailto:mark/at/lissaman.com
[Experimenting with Google App Engine]: http://bret.appspot.com/entry/experimenting-google-app-engine
[Bloog]: http://bloog.billkatz.com/
[cpedialog]: http://code.google.com/p/cpedialog/
[cpedialog]: http://code.google.com/p/cpedialog/
[Disqus]: http://www.disqus.com/
[Technorati]: http://www.technorati.com/
[reStructuredText]: http://docutils.sourceforge.net/rst.html
[http://software.clapper.org/picoblog/]: http://software.clapper.org/picoblog/
[GAE]: http://appengine.google.com/
[GAE]: http://appengine.google.com/
[App Engine documentation]: http://code.google.com/appengine/docs/
[Keys and Entity Groups]: http://code.google.com/appengine/docs/datastore/keysandentitygroups.html
[web site]: http://software.clapper.org/picoblog/
[GitHub repository]: http://github.com/bmc/picoblog
[documentation for the Query class]: http://code.google.com/appengine/docs/datastore/queryclass.html
[GAE Query Filter]: http://code.google.com/appengine/docs/datastore/queryclass.html#Query_filter
[Django template language]: http://www.djangoproject.com/documentation/0.96/templates/
[full template for the main administration screen here]: admin-main.txt
[follow this link]: /static/gae/style.css
[template for the edit screen is available here]: admin-edit.txt
[app.yaml]: app_yaml_
[reStructuredText]: http://docutils.sourceforge.net/rst.html
[Docutils]: http://docutils.sourceforge.net/
[Docutils]: http://docutils.sourceforge.net/
[base template]: /static/gae/base.txt
[email to the Google App Engine mailing list, Bill Katz]: http://groups.google.com/group/google-appengine/msg/a5fcf38345c54623
[something I missed in the GAE docs]: http://code.google.com/appengine/docs/datastore/typesandpropertyclasses.html#ListProperty

[full archive page image is here]: archive.png
[Pygments]: http://pygments.org/
[Google Analytics]: http://www.google.com/analytics/
[Adding Page caching to a GAE application]: /id/78/
[Making XML-RPC calls from a Google App Engine application]: /id/80
[Experimenting with Google App Engine]: http://bret.appspot.com/entry/experimenting-google-app-engine
[Building Scalable Web Applications with Google App Engine]: http://sites.google.com/site/io/building-scalable-web-applications-with-google-app-engine
[Google App Engine documentation]: http://code.google.com/appengine/docs/
