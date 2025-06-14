#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

@test "docker-compose config parses cleanly" {
  run docker compose config
  assert_success
}

@test ".env file exists and has required keys" {
  [ -f .env ]
  # shellcheck disable=SC1090
  source .env
  for key in TZ PIHOLE_IMAGE PIHOLE_TAG PIHOLE_HOSTNAME PIHOLE_WEBPASSWORD; do
    [ -n "${!key}" ]
  done
}
