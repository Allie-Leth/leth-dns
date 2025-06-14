#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

# helper to check container status
check_up() {
  local name="$1"
  run docker inspect --format='{{.State.Running}}' "$name"
}

@test "Pi-hole container is running" {
  check_up pihole
  assert_output 'true'
}

@test "Unbound container is running" {
  check_up unbound
  assert_output 'true'
}

@test "Exporter container is running" {
  check_up pihole-exporter
  assert_output 'true'
}
