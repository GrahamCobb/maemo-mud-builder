<? include("_header.php") ?>
<h2 class="subtitle">Maemo Unofficial Debs</h2>

<div id="branding" class="package"></div>

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

<h2>Getting started</h2>
<p>The <a href="docs/index.php">documentation</a> section is burgeoning, and
will guide you through installation and creating simple - and more complex -
packages.</p>

<p>At the moment, it's a little sparse, but feel free to ask questions on the
<a href="https://garage.maemo.org/mailman/listinfo/mud-builder-users">mailing
list</a> and people would be happy to help. Alternatively, there are often
people who use and develop MUD hanging out in the <a
href="http://maemo.org/pipermail/maemo-developers/2005-May/000018.html">#maemo</a>
IRC channel.</p>

<p>The <a href="docs/index.php?id=workflow">workflow</a> is designed around
<em>contributions</em> of packages which people would like to see on their
Maemo device, without the hassle of continually building, uploading and
signing the packages. Therefore, getting involved is crucial to the survival
of the project in meeting its aims. Patch trackers, access to the Subversion
version control system and other statistics can be found on the <a
href="https://garage.maemo.org/projects/mud-builder/">Garage page</a>.</p>

<? include("_footer.php") ?>
