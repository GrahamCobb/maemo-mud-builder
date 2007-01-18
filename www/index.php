<? include("_header.php") ?>
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
<li>User wants (say) <a href="http://insecure.org/nmap/">nmap</a> on his 770,
    but notes no-one has yet ported it to the 770 or armel. Even if there was
    an armel deb available, chances are it wouldn't be in a Maemo repo or the
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

<h2>Documentation</h2>
<a name="gettingstarted"></a><a name="creating"></a>
<p>Documentation now has its <a href="docs/index.php">own pages</a>.</p>

<? include("_footer.php") ?>
