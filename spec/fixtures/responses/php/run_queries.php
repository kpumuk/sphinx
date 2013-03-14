<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->AddQuery('wifi', 'test1');
$cl->AddQuery('gprs', 'test1');
$cl->RunQueries();

?>
