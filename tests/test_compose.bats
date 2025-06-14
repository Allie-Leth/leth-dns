#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

@test "docker-compose config parses cleanly" {
  run docker-compose config
  assert_success
}

@test ".env file exists and has required keys" {
  refute [ ! -f .env ]
  # Check for at least one required var
  run grep -E '^TZ=' .env
  assert_success
  run grep -E '^PIHOLE_WEBPASSWORD=' .env
  assert_success
}
