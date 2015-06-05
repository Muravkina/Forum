require "pg"

$db = PG.connect({
  dbname: 'forum'
})
