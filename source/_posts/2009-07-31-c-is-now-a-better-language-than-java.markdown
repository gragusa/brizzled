---
layout: post
comments: true
title: "C# is now a better language than Java"
date: 2009-07-31 00:00
categories: [java, c#, scala, programming]
---

I'm currently teaching myself [C#][] (with [.NET][] to follow); my client
is building a new data warehouse, and the support tools will be
Windows-based. As a newly minted consultant, it also can't hurt to have
.NET/C# experience under my belt, even if I generally prefer to do my
development anywhere but Windows. As a consultant, I need to maximize the
possibility of getting future contracts; if that means doing Windows, I'll
do Windows (and program where I'd *prefer* to program at home).

As pretty much anyone who knows me knows, I am not a huge fan of
[Microsoft][]. I've spent a large part of my career programming on
Unix-like systems. From 1999 to 2008, I worked for an
[independent software vendor][], as a core member of their development
team; the product was written almost entirely in [Java][].

I like the Java VM. It's mature, it's fast, it's highly portable, and there
are loads of languages running on it. When I was developing full-time in
Java, I was the only member of the team whose desktop ran Linux; everyone
else used Windows. With Java, it didn't matter. In fact, it was an
advantage. Several of our clients ran our software on Unix-like systems;
having at least one developer who used and tested our product on Linux was
a win. Our nightly build system was a cheap Linux server, as well; since
Java runs anywhere there's a Java VM, anyone on our team (as well as any of
our customers) could run executables produced on that Linux box.

But Java, the language, depresses me lately. It's being left in the dust by
other languages. [Scala][], my current favorite language on the Java VM,
incorporates many newer (and some not so new) ideas that have yet to find
their way into Java.

<!-- more -->

Worse, though, for Java enthusiasts: Java has fallen behind C#. I'm boning
up on C# using O'Reilly's *C# in a Nutshell* book. (See
<http://oreilly.com/catalog/9780596001810/>. As an aside, the "Nutshell"
books are an excellent way to learn a new language, if you already know *n*
other languages.) I'm only partway through the book, but it's already clear
to me that, overall, C# (the language) now has more goodness in it than
Java does. I have to give Microsoft credit (much as it may pain me to do
so). Here are some things C# now has that Java does not:

- Lambdas, which are way better than anonymous inner classes. (C# has
  anonymous inner classes, too.)

- Delegates. You can kind of do this in Java, but it's not as clean.

- Operator overloading. This feature can be abused all to hell, but it is
  still occasionally useful, especially in libraries and in [DSLs][].

- Properties. No need to write getters and setters. Everything looks like a
  direct field access, even if it isn't. This is Python's idiom, and
  Scala's, too, and once you start using it, you never want to expose
  explicit getters and setters, ever again. `foo.x += 1` is *so* much more
  readable than `foo.setX(foo.getX() + 1)`.

- A `yield` coroutine capability. Though I prefer Python's syntax (and
  Scala's) to C#'s, this is a powerful and highly useful capability. If
  you've ever used it to build lazy iterators (in Python, Scala, C#,
  whatever), you know what I mean.

- Extension methods. These are the C# equivalent of the Scala
  [implicit type conversion][] feature, and they're damned useful. They
  permit you to "extend" existing classes, even if they're final, without
  actually extending them. Like the Scala version, there's a mechanism for
  bringing the implicit conversions in scope; they don't happen
  automatically. (Think of them as a kind of scope-controlled
  [monkeypatching][].)

  (**Note**: As Tony Morris points out, in the comments to this article,
  extension methods are not *really* the equivalent of Scala's implicit
  type conversions; Scala's implicits are much more powerful. Still, it's
  clear that C# has borrowed one useful aspect of this notion, and it's
  equally clear that Java does not have a feature that's even remotely
  close to either Scala's implicits or C#'s extension methods.)

- A [null coalescing operator][] that provides a simple syntax for
  dereferencing a reference and supplying a default if the reference is
  null.


In addition, C# has many of the same features as Java, including:

-   interfaces
-   generics
-   autoboxing and auto-unboxing
-   annotations (though C# calls them "attributes")

I *still* prefer the JVM to [CLR][]. The JVM is robust, mature, fast, and
(above all) portable. But Java, the language, has fallen behind, and it now
lacks a lot of the useful features C# has. One of the reasons I'm all over
[Scala][] these days is that it corrects those flaws in Java, providing
many up-to-date features while still permitting me to use the power and
convenience of the JVM. Either via libraries or built-ins, Scala provides
the same features as C#, with a few more thrown in for good measure. (I
also happen to think Scala is a better language than C#, but I'll save
that tangent for another time.) But, in the .NET world, C#, not Scala, is
the *lingua franca*. And C#, and .NET, are the biggest hearts-and-minds
competitor Java has.

Sun and the Java community have allowed Java, the language, to stagnate to
the point where, compared to C# and Scala, it is almost painful to use. As
a long-time Java programmer, I have to say, that makes me a little sad.

**Offsite Comments on this Article**

-   [Reddit][]
-   [Hacker News][]

[C#]: http://msdn.microsoft.com/en-us/vcsharp/aa336809.aspx
[.NET]: http://www.microsoft.com/NET/
[Microsoft]: http://www.microsoft.com/
[independent software vendor]: http://www.ardentex.com/resumes/bmc/resume.html#FullTilt
[Java]: http://java.sun.com/
[Scala]: http://www.scala-lang.org/
[http://oreilly.com/catalog/9780596001810/]: http://oreilly.com/catalog/9780596001810/
[DSLs]: http://en.wikipedia.org/wiki/Domain-specific_language
[implicit type conversion]: http://scalada.blogspot.com/2008/03/implicit-conversions-magical-and.html
[monkeypatching]: http://en.wikipedia.org/wiki/Monkey_patch
[null coalescing operator]: http://msdn.microsoft.com/en-us/library/ms173224.aspx
[CLR]: http://scalada.blogspot.com/2008/03/implicit-conversions-magical-and.html
[Scala]: http://www.scala-lang.org/
[Reddit]: http://www.reddit.com/r/programming/comments/96836/c_is_now_a_better_language_than_java/
[Hacker News]: http://news.ycombinator.com/item?id=734487
