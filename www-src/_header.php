<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<?
  $script_root = $_SERVER['PHP_SELF'];
  $script_root = dirname($script_root);

  for ($i = 0; $i < 5 && $script_root != '/' && !is_file("$_SERVER[DOCUMENT_ROOT]/$script_root/style.css"); $i++) {
      $script_root = dirname($script_root);
   }
   if ($script_root == '/') $script_root = '';
?>
<html>
<head>
  <title>mud-builder<? if ($title != '') echo ": $title"?></title>
  <link rel="stylesheet" href="<?= $script_root ?>/style.css" type="text/css" />
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
</head>
<body>
<h1>mud-builder</h1>
<? if ($title != '') echo "<h2 class=\"subtitle\">$title</h2>" ?>

