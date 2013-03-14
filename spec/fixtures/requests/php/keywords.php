<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->BuildKeywords('test', 'index', true);

?>