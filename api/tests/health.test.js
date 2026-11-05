const request = require('supertest');
const app = require('../src/app');

describe('GET /api/v1/health', () => {
  it('responde 200 y status ok', async () => {
    const res = await request(app).get('/api/v1/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});