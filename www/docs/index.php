<? $title = 'Documentation';
   include("../_header.php") ?>

<ol id="index">
<?php

if (!($fp = @fopen("./structure.xml", "r"))) die("Couldn't open XML.");
if (!($xml_parser = xml_parser_create())) die("Couldn't create parser.");

function startElement($parser, $name, $attrib) {
    switch ($name) {
        case $name == "SECTION" : {
            echo "<li><span class=\"section\">$attrib[TITLE]</span><ol>\n";
            break;
        }

        case $name == "DOC" : {
            echo "<li><a href=\"?id=$attrib[FILE]\">";
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
    echo $data;
}

xml_set_element_handler($xml_parser, "startElement", "endElement");
xml_set_character_data_handler($xml_parser, "characterData");

while( $data = fread($fp, 4096)){
if(!xml_parse($xml_parser, $data, feof($fp))) {
break;}}
xml_parser_free($xml_parser); 
?>
</ol>

<?
if ($_GET[id] != '') {
    $id = preg_replace('/[^a-z0-9]+/i', '', $_GET[id]);
    include("./$id.html");
}
?>
    

<? include("../_footer.php") ?>
