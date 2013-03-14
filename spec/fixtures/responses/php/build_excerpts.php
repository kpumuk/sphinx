<?php

require ("spec/fixtures/sphinxapi.php");

$cl = new SphinxClient();
$cl->BuildExcerpts(array('what the world', 'London is the capital of Great Britain'), 'test1', 'the');

?>
