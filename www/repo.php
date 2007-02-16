<?php
  $base = 'http://bleb.org/software/maemo/repo/';
  $file = $_SERVER["REQUEST_URI"];
  $file = preg_replace('/.*\//', '', $file);
  header("Location: $base$file");

  exit;
?>
