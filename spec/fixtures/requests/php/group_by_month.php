<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->SetGroupBy('attr', SPH_GROUPBY_MONTH);
$cl->Query('query');

?>