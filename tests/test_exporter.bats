#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

EXPORTER_PORT=9617
@test "Exporter metrics endpoint is reachable" {
  run curl -sSf http://127.0.0.1:${EXPORTER_PORT}/metrics | head -n1
  assert_output --partial "pihole_queries_total"
}
