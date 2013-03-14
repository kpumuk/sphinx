<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->SetFilterRange('attr', 10, 20);
$cl->Query('query');

?>