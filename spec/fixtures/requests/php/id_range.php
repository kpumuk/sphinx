<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->SetIDRange(10, 20);
$cl->Query('query');

?>