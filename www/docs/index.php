<? $title = 'Documentation';
   include("../_header.php") ?>

<?php

$id    = preg_replace('/[^a-z0-9]+/i', '', $_GET[id]);
$curId = '';
$head  = '';

if ($id == '') echo '<div id="branding" class="docs"></div>';
?>

<?php

echo "<ol id=\"index\"";
if ($id != '') echo " class=\"nav\"";
echo ">\n";

if (!($fp = @fopen("./structure.xml", "r"))) die("Couldn't open XML.");
if (!($xml_parser = xml_parser_create())) die("Couldn't create parser.");

function startElement($parser, $name, $attrib) {
    global $id;
    global $curId;
    switch ($name) {
        case $name == "SECTION" : {
            echo "<li><span class=\"section\">$attrib[TITLE]</span><ol>\n";
            break;
        }

        case $name == "DOC" : {
            echo "<li";
            $curId = $attrib[FILE];
            if ($curId == $id) echo " class=\"selected\"";
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
    global $id, $curId, $head;
    echo $data;

    if ($id == $curId) $head .= $data;
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
    echo "<h2 id=\"$id\">$head</h2>";
    include("./$id.html");
}
?>

<? include("../_footer.php") ?>
