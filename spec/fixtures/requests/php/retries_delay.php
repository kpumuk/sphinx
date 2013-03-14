<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->SetRetries(10, 20);
$cl->Query('query');

?>