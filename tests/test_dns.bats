#!/usr/bin/env bats

load 'test_helper/bats-assert/load'

PORT="${TEST_PIHOLE_PORT:-53}"

@test "Resolve a known domain via Pi-hole" {
  run dig +short @"127.0.0.1#${PORT}" example.com A
  assert_success
  assert_output --regexp '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
}

@test "Resolve a lab.local record" {
  run dig +short @"127.0.0.1#${PORT}" router.lab.local A
  assert_success
}
