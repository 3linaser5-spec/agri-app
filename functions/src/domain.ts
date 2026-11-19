export const SQUARE_METERS_PER_FEDDAN = 4_200;
export const DEFAULT_MAX_AREA_FEDDAN = 100;

export interface AreaAccount {
  maxAreaFeddan: number;
  usedAreaFeddan: number;
}

export interface AreaDecision {
  requestedAreaFeddan: number;
  nextUsedAreaFeddan: number;
}

export function areaFeddanFromSquareMeters(areaM2: number): number {
  if (!Number.isFinite(areaM2) || areaM2 < 0) throw new Error('Invalid field area.');
  return areaM2 / SQUARE_METERS_PER_FEDDAN;
}

export function readAreaAccount(data: Record<string, unknown>): AreaAccount {
  const max = typeof data['max_area_feddan'] === 'number' && Number.isFinite(data['max_area_feddan'])
    ? data['max_area_feddan'] : DEFAULT_MAX_AREA_FEDDAN;
  const used = typeof data['used_area_feddan'] === 'number' && Number.isFinite(data['used_area_feddan'])
    ? data['used_area_feddan'] : 0;
  if (max <= 0 || used < 0) throw new Error('Invalid area account.');
  return { maxAreaFeddan: max, usedAreaFeddan: used };
}

export function reserveArea(account: AreaAccount, requestedAreaFeddan: number): AreaDecision {
  if (!Number.isFinite(requestedAreaFeddan) || requestedAreaFeddan <= 0) {
    throw new Error('Field area must be positive.');
  }
  const next = account.usedAreaFeddan + requestedAreaFeddan;
  if (next > account.maxAreaFeddan + 1e-9) {
    throw new Error('AREA_LIMIT_EXCEEDED');
  }
  return { requestedAreaFeddan, nextUsedAreaFeddan: next };
}

export function releaseArea(account: AreaAccount, areaFeddan: number): number {
  if (!Number.isFinite(areaFeddan) || areaFeddan < 0) throw new Error('Invalid released area.');
  return Math.max(0, account.usedAreaFeddan - areaFeddan);
}

export interface PublicSourceRef {
  key: 'hls' | 'sentinel2';
  resolutionM: number;
}

export interface InternalProvenance {
  provider: string;
  product: string;
  resolutionM: number;
}

export function publicSourceRefs(hasHls: boolean, hasSentinel2: boolean): PublicSourceRef[] {
  return [
    ...(hasHls ? [{ key: 'hls' as const, resolutionM: 30 }] : []),
    ...(hasSentinel2 ? [{ key: 'sentinel2' as const, resolutionM: 10 }] : []),
  ];
}

export function internalProvenance(hasHls: boolean, hasSentinel2: boolean): InternalProvenance[] {
  return [
    ...(hasHls ? [{ provider: 'NASA Earthdata AppEEARS', product: 'HLSL30/HLSS30', resolutionM: 30 }] : []),
    ...(hasSentinel2 ? [{ provider: 'Copernicus Data Space Ecosystem', product: 'Sentinel-2 L2A', resolutionM: 10 }] : []),
  ];
}

export function auditEntry(action: string, uid: string, subjectId: string, details: Record<string, unknown> = {}) {
  return { action, uid, subjectId, details, createdAt: 'server_timestamp' as const };
}
