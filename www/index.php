<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/x
html1/DTD/xhtml1-strict.dtd">
<html>
<head>
  <title>mud-builder</title>
  <link rel="stylesheet" href="style.css" type="text/css" />
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
</head>
<body>
<h1>mud-builder</h1>
<h2 class="subtitle">Maemo Unofficial Debs</h2>

<p>MUD is "Maemo Unofficial Debs". It's an autobuilder to make it bring together
simple source ports, and to ensure they're available in a single repository.</p>

<p>It was inspired by conversations on <a href="http://maemo.org/pipermail/maemo-developers/2006-July/004527.html">maemo-developers</a>
and at <a href="http://www.internettablettalk.com/forums/showthread.php?t=2340">Internet Tablet Talk</a>.
</p>

<p>For example, <code>privoxy</code>, <code>netcat</code>, <code>vim</code>,
<code>rsync</code> etc. are all candidates for MUD. The
idea is that small scripts/configuration files will describe how to build
Maemo-specific ARMEL debs which are run on developer's machines. This will
result in one or many debs which can then be deployed on
<a href="http://maemo.org/maemowiki/ExtrasRepository">repository.maemo.org/extras</a>. This means that each individual developer
scratching an itch for a port will not have to find a repo to host it, and
projects with little or no changes for Maemo from the upstream source will not
have to apply for a Garage project: a patch will be provided to MUD and the
resulting deb deployed to the contrib repository during the next run.</p>

<p>The source code to the autobuilder is under the Artistic Licence, but the
resulting debs will be under the licence of the original project.</p>

<h2 id="workflow">Example workflow</h2>
<ol>
<li>User wants (say) <a href="">nmap</a> on his 770, but notes no-one has yet
   ported it to the 770 or armel. Even if there was an armel deb
   available, chances are it wouldn't be in a Maemo repo or the
   deb configured for the Application Manager.</li>

<li>User downloads/installs mud to his scratchbox and adds the
   necessary configuration to build <code>nmap</code>. Ideally, this would take
   no more than a single file containing a single line, but obviously
   more options are available.</li>

<li>User runs <code>mud build nmap</code> (or similar) and gets an Application
   Manager-compatible, armel deb ready for uploading to the extras
   repo. User notices, however, that he doesn't have a Garage account
   and doesn't think it worthwhile to create one for this one deb.</li>

<li>User submits patch to the mud project, where the patch is reviewed
   and, potentially included. Next time the mud admins run
   <code>mud -a build</code>, an additional nmap deb is produced. This is
   then uploaded to the contrib repo by the mud admins.</li>

<li>Other users refresh their packages and now see that nmap is
   ported.</li>

<li>As the upstream nmap is updated, so too is the mud package
   available through the contrib repo.</li>
</ol>

<h2 id="gettingstarted">Getting started</h2>
<p>In lieu of proper documentation (which is forthcoming), here's a quick start guide:</p>

<ol>
<li>Check out <a
href="https://garage.maemo.org/scm/?group_id=63">mud-builder/trunk</a> from
Subversion into a directory under your Scratchbox home. <span class="note">This
can be done from within Scratchbox, which might be easiest, or externally if
necessary.</span></li>

<li>In Scratchbox, change to the mud-builder directory and type:

<pre><code>alias mud=$(pwd)/mud</code></pre>

<span class="note">This allows you to type <code>mud</code> to invoke the system, without having to add it to your path.</span></li>

<li>Switch to your SDK_ARMEL target:

<pre><code>sbox-config -st SDK_ARMEL</code></pre>

<span class="note">Your device architecture target may be named differently. Substitute the correct name for <code>SDK_ARMEL</code> in this case.</span></li>

<li>Build the existing <code>netcat</code> package:

<pre><code>mud build netcat</code></pre></li>

<li>Copy the resulting <code>upload/netcat-&#8230;.deb</code> to your Maemo
device and install with the Application Manager.</li>
</ol>

<h2 id="creating">Creating a new package</h2>
<p>Currently best supported are simple command line utilities without many
build dependencies. For the sake of this example we'll duplicate the existing
<code>cal</code> package, but additionally patch it to provide some
Maemo-specific behaviour.. It is assumed that the previous tutorial has been
folowed and that mud is installed and the alias set.</p>

<ol>
<li>Switch to the SDK_PC target.</li>

<li>Create a file, <code>packages/mycal.xml</code>:

<pre><code>&lt;package&gt;
    &lt;fetch type=&quot;debian&quot;&gt;
        &lt;name&gt;cal&lt;/name&gt;
    &lt;/fetch&gt;
&lt;/package&gt;</code></pre>
</li>

<li>Extract the source to <code>build/mycal/.build</code>:

<pre><code>mud get mycal</code></pre>

<span class="note"><code>.build</code> is a symlink to whatever source directory is unpacked, in this case <code>cal-3.5</code>.</span></li>

<li>Change to the build directory:

<pre><code>cd build/mycal/.build</code></pre>
</li>

<li>We want to brand the calendar for Maemo, so we'll modify a source file, change <code>source/cal.c</code>, line 574 from:

<pre><code>fputs(&quot;\t\t\t\t &quot;, stdout);</code></pre>

&#8230;to&#8230;

<pre><code>fputs(&quot;\t\t\t\tMaemo in &quot;, stdout);</code></pre>
</li>

<li>Check your modifications build and install:

<pre><code>mud compile mycal
&#8230;
fakeroot dpkg -i ../../../upload/ccal*.deb
&#8230;
ccal 2007</code></pre>
</li>

<li>If happy with your Maemo port, we now need to generate the patch for it to
be submitted to the <em>mud-builder</em> project so that it is always applied
in future. Check that the local Subversion repository contains only the changes you want:

<pre><code>svn status</code></pre>

Note that the <code>source/cal.c</code> line is prefixed with &quot;M&quot; for
<em>modified</em>. This is what we want, note also the auto-changes to <code>debian/control</code>. We don't want to store this as it can be easily regenerated by <code>mud-builder</code> so revert that file and then savethe patch into your local copy of <em>mud-builder</em>:

<pre><code>svn diff debian/control
svn revert debian/control
mud diff mycal</code></pre>

<span class="note">Files marked with a &quot;?&quot; are unknown to Subversion and are usually ignorable side effects of the build. If you add a new file, use <code>svn add &lt;path&gt;</code> to include it in the diff.</span>
</li>

<li>Send <code>packages/mycal.xml</code> and
<code>packages/patch/mycal.xml</code> to the <a
href="https://garage.maemo.org/mailman/listinfo/mud-builder-users">mud-builder-users</a>
mailing list.</li>

<li>Tidy up:

<pre><code>mud clean mycal</code></pre>

<span class="note">Because our changes were saved in
<code>packages/patch/mycal.xml</code>, the next time that <code>mud get
mycal</code> is run the patch will be re-applied after the source is
unpacked.</span>
</li>
</ol>

<p class="meta">
<a id="valid" href="http://validator.w3.org/check?uri=referer"><img src="http://www.w3.org/Icons/valid-xhtml10" alt="[XHTML 1.0 Valid]" /></a>

<a href="https://garage.maemo.org/projects/mud-builder/">Garage project page</a>
 | &copy; Andrew Flegg 2007. Released under the Artistic Licence.
</p>
</body>
</html>
