#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

# Adjust as needed if your test host differs
PIHOLE_HOST="127.0.0.1"

@test "Resolve a known domain via Pi-hole" {
  run dig +short @${PIHOLE_HOST} example.com
  assert_success
  assert [ "${#output}" -gt 0 ]
}

@test "Resolve a lab.local record" {
  run dig +short @${PIHOLE_HOST} grafana.lab.local
  assert_success
  # should return your k3s node IP
  assert [ "${output}" = "192.168.1.119" ]
}
