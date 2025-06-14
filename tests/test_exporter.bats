#!/usr/bin/env bats

load 'test_helper/bats-assert/load'

@test "Exporter metrics endpoint is reachable" {
  run curl -s http://127.0.0.1:9617/metrics
  assert_success
  assert_output --partial "pihole_queries_total"
}
