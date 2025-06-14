#!/usr/bin/env bats

load 'test_helper/bats-assert/load'

@test "Pi-hole container is running" {
  run docker inspect -f '{{.State.Running}}' pihole
  assert_output 'true'
}

@test "Unbound container is running" {
  run docker inspect -f '{{.State.Running}}' unbound
  assert_output 'true'
}

@test "Exporter container is running" {
  run docker inspect -f '{{.State.Running}}' exporter
  assert_output 'true'
}
