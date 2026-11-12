// k6 load test through the full edge (nginx TLS -> VIP -> HAProxy -> apps).
// Thresholds make the run fail if latency or errors go above target.
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  insecureSkipTLSVerify: true,   // lab CA; the test-edge.sh script verifies the chain
  scenarios: {
    ramp: {
      executor: 'ramping-arrival-rate',
      startRate: 10,
      timeUnit: '1s',
      preAllocatedVUs: 20,
      maxVUs: 100,
      stages: [
        { target: 40, duration: '15s' },
        { target: 40, duration: '15s' },
        { target: 0, duration: '5s' },
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<300'],
  },
};

const BASE = __ENV.BASE_URL || 'https://app.local.test:8443';

export default function () {
  const res = http.get(`${BASE}/`);
  check(res, { 'status is 200': (r) => r.status === 200 });
}
