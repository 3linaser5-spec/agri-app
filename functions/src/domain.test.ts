import assert from 'node:assert/strict';
import test from 'node:test';
import { areaFeddanFromSquareMeters, internalProvenance, publicSourceRefs, readAreaAccount, releaseArea, reserveArea } from './domain';

test('uses legacy-compatible defaults and enforces the feddan quota', () => {
  const account = readAreaAccount({});
  assert.equal(account.maxAreaFeddan, 100);
  assert.equal(areaFeddanFromSquareMeters(4200), 1);
  assert.equal(reserveArea(account, 2).nextUsedAreaFeddan, 2);
  assert.throws(() => reserveArea({ maxAreaFeddan: 1, usedAreaFeddan: .5 }, .51), /AREA_LIMIT_EXCEEDED/);
  assert.equal(releaseArea({ maxAreaFeddan: 1, usedAreaFeddan: .5 }, .2), .3);
});

test('keeps public source references opaque and provenance detailed for admins', () => {
  assert.deepEqual(publicSourceRefs(true, true).map((source) => source.key), ['hls', 'sentinel2']);
  assert.match(internalProvenance(true, true)[0]!.provider, /NASA/);
});
