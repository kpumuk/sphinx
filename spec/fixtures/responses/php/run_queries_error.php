<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->AddQuery('wifi', 'fakeindex');
$cl->RunQueries();

?>
