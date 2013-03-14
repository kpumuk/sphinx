<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->BuildKeywords('wifi gprs', 'test1', true);

?>
