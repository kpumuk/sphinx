<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->SetOuterSelect('attr', 10, 100);
$cl->Query('query');

?>
