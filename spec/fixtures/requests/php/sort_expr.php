<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->SetSortMode(SPH_SORT_EXPR, 'sortby');
$cl->Query('query');

?>