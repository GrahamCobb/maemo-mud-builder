<? $title = 'Documentation';
   include("../_header.php") ?>

<?php

$id    = preg_replace('/[^a-z0-9]+/i', '', $_GET[id]);
$curId = '';
$prev  = array( );
$next  = array( );
$label = array( );

if ($id == '') { ?>
    <div id="branding" class="docs"></div>
    <p>This documentation is woefully lacking at the moment, for that I
    apologise. However, it does attempt to cover enough to get you up and
    running and a small package compiled. In the meantime, please ask any
    questions you've got on the <a
    href="https://garage.maemo.org/mailman/listinfo/mud-builder-users">mailing
    list</a>.</p>

    <p>You may also find the <a href="http://www.debian.org/doc/maint-guide/">Debian New Maintainers' Guide</a> a useful reference.</p>
<? } ?>

<?php

echo "<ol id=\"index\"";
if ($id != '') echo " class=\"nav\"";
echo ">\n";

if (!($fp = @fopen("./structure.xml", "r"))) die("Couldn't open XML.");
if (!($xml_parser = xml_parser_create())) die("Couldn't create parser.");

function startElement($parser, $name, $attrib) {
    global $id, $curId, $prev, $next;
    switch ($name) {
        case $name == "SECTION" : {
            echo "<li><span class=\"section\">$attrib[TITLE]</span><ol>\n";
            break;
        }

        case $name == "DOC" : {
            echo "<li";
            $curId = $attrib[FILE];
            if ($curId == $id) {
                echo " class=\"selected\"";
                $prev[done] = 1;
            } else if (!$prev[done]) {
                $prev[id]   = $curId;
            } else if ($prev[done] && !$next[id]) {
                $next[id]   = $curId;
            }
            echo "><a href=\"index.php?id=$curId\">";
            break;
        }
    }
}

function endElement($parser, $name) {
    switch ($name) {
        case $name == "SECTION" : {
            echo "</ol></li>\n";
            break;
        }

        case $name == "DOC" : {
            echo "</a></li>\n";
            breka;
        }
    }
}

function characterData($parser, $data) {
    global $id, $curId, $label;
    echo $data;

    $label[$curId] .= $data;
}

xml_set_element_handler($xml_parser, "startElement", "endElement");
xml_set_character_data_handler($xml_parser, "characterData");

while( $data = fread($fp, 4096)) {
    if(!xml_parse($xml_parser, $data, feof($fp))) reak;
}
xml_parser_free($xml_parser); 
?>
</ol>

<? 
if ($id != '') {
    echo "<h2 id=\"$id\">$label[$id]</h2>";
    include("./$id.html");

    echo '<p class="link">';
    if ($curId = $prev[id])
        echo "<a class=\"prev\" href=\"index.php?id=$curId\">&lt;&lt; $label[$curId]</a>";
    if ($curId = $next[id])
        echo "<a class=\"next\" href=\"index.php?id=$curId\">$label[$curId] &gt;&gt;</a>";
    echo '</p>';
}
?>

<? include("../_footer.php") ?>
